defmodule Tracer.Collector do
  alias Tracer.Formatter
  import Tracer.Utils

  def ensure_started(node) do
    case rpc(node, :erlang, :whereis, [__MODULE__]) do
      pid when is_pid(pid) -> pid
      :undefined -> start(node)
    end
  end

  def start(node \\ node()) do
    local? = node == node()
    pid = :erlang.spawn(node, __MODULE__, :init, [{self(), local?}])
    {rpc(node, :erlang, :register, [__MODULE__, pid]), node}
  end

  def enable(node, io, limit, processes, trace_options, formatter) do
    call!({__MODULE__, node}, {:enable, io, limit, processes, trace_options, formatter})
  end

  def trace_pattern(node, pattern) do
    call!({__MODULE__, node}, {:set, pattern})
  end

  def stop(node), do: call({__MODULE__, node}, :stop)

  def init({parent, local?}) do
    :erlang.monitor(:process, parent)

    loop(%{
      parent: parent,
      local?: local?,
      formatter: nil,
      io: nil,
      collect_state: %{},
      limit: %{time: nil, rate: nil, overall: nil},
      window: :os.timestamp(),
      count: 0,
      all_count: 0
    })
  end

  def loop(state = %{parent: parent}) do
    receive do
      {{pid, ref} = _from, msg} ->
        {action, answer, new_state} = handle_call(msg, state)
        send(pid, {ref, answer})

        case action do
          :stop -> stop(:stop, state)
          :reply -> loop(new_state)
        end

      {:DOWN, _, _, ^parent, _} ->
        stop(:stop, state)

      msg ->
        handle_trace(msg, state) |> loop()
    end
  end

  def handle_call({:enable, io, new_limit, processes, trace_options, formatter_opts}, state) do
    %{formatter: formatter, limit: limit} = state
    :erlang.trace(processes, true, [{:tracer, self()} | trace_options])

    {:reply, :ok,
     %{
       state
       | formatter: start_formatter(formatter, io, formatter_opts),
         io: io,
         limit: :maps.merge(limit, new_limit)
     }}
  end

  def handle_call({:set, pattern}, state) do
    {{module, _, _} = pattern, match_options, global_options} = pattern
    module.module_info()
    result = :erlang.trace_pattern(pattern, match_options, global_options)
    {:reply, result, state}
  end

  def handle_call(:stop, state) do
    {:stop, :ok, state}
  end

  def stop(reason, %{local?: local?, formatter: formatter}) do
    :erlang.trace(:all, false, [:all])
    :erlang.trace_pattern({:_, :_, :_}, false, [:local, :meta, :call_count, :call_time])
    :erlang.trace_pattern({:_, :_, :_}, false, [])
    send(formatter, {:flush, self()})

    receive do
      :flushed ->
        if reason == :limit and local?, do: IO.puts("Tracer collector reached limit.")
        exit({:shutdown, reason})
    after
      5000 -> exit({:shutdown, reason})
    end
  end

  def handle_trace(trace, state) when elem(trace, 0) == :trace_ts do
    %{
      limit: limit,
      formatter: formatter,
      window: window,
      count: count,
      all_count: all,
      collect_state: collect_state
    } = state

    {add, trace, collect_state} = collect(trace, collect_state)
    send(formatter, trace)
    %{time: time, rate: rate, overall: overall} = limit
    now = :os.timestamp()
    delay = :timer.now_diff(now, window) |> div(1000)

    cond do
      all >= overall ->
        stop(:limit, state)

      delay > time ->
        %{state | collect_state: collect_state, window: now, count: 0, all_count: all + add}

      rate <= count ->
        stop(:limit, state)

      rate > count ->
        %{state | collect_state: collect_state, count: count + 1, all_count: all + add}
    end
  end

  defp collect({:trace_ts, pid, :call, mfa, timestamp} = trace, collect_state) do
    {1, trace, remember_call(collect_state, pid, mfa, timestamp)}
  end

  defp collect({:trace_ts, pid, :call, mfa, _dump, timestamp} = trace, collect_state) do
    {1, trace, remember_call(collect_state, pid, mfa, timestamp)}
  end

  defp collect({:trace_ts, pid, type, mfa, _return, timestamp} = trace, collect_state)
       when type in [:exception_from, :return_from] do
    [start_ts | calls_on_stack] = :maps.get({pid, mfa}, collect_state)

    collect_state =
      case calls_on_stack do
        [] -> :maps.remove({pid, mfa}, collect_state)
        _ -> %{collect_state | {pid, mfa} => calls_on_stack}
      end

    time_used = with {_, _, _} <- start_ts, do: :timer.now_diff(timestamp, start_ts)
    {0, put_elem(trace, 5, time_used), collect_state}
  end

  defp collect(trace, collect_state) do
    {1, trace, collect_state}
  end

  defp remember_call(collect_state, pid, {mod, fun, args}, timestamp) do
    key = {pid, {mod, fun, length(args)}}
    :maps.update_with(key, &[timestamp | &1], [timestamp], collect_state)
  end

  defp start_formatter(nil, io, options) do
    if options[:formatter_local] do
      node = :erlang.node(io)
      :erlang.spawn_link(node, Formatter, :init, [io, options[:formatter]])
    else
      Formatter.start_link(io, options[:formatter])
    end
  end

  defp start_formatter(formatter, _io, options) do
    if new_formatter = options[:formatter], do: send(formatter, {:formatter, new_formatter})
    formatter
  end
end
