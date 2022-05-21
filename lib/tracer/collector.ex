defmodule Tracer.Collector do
  alias Tracer.Formatter
  import Tracer.Utils

  def ensure_started(node, unlink?) do
    case rpc(node, :erlang, :whereis, [__MODULE__]) do
      pid when is_pid(pid) -> {:already_started, pid}
      :undefined -> {:started, start(node, unlink?)}
    end
  end

  def start(node \\ node(), unlink?) do
    local? = node == node()
    pid = :erlang.spawn(node, __MODULE__, :init, [{self(), local?, unlink?}])
    {rpc(node, :erlang, :register, [__MODULE__, pid]), node}
  end

  def configure(node, io, limit, formatter) do
    call({__MODULE__, node}, {:configure, io, limit, formatter})
  end

  def trace(node, processes, trace_options) do
    call({__MODULE__, node}, {:trace, processes, trace_options})
  end

  def trace_pattern(node, pattern) do
    call({__MODULE__, node}, {:set, pattern})
  end

  def trace_and_set(node, processes, trace_options, pattern) do
    call({__MODULE__, node}, {:trace_and_set, processes, trace_options, pattern})
  end

  def status(node) do
    call({__MODULE__, node}, :status)
  end

  def stop(node), do: call({__MODULE__, node}, :stop)

  def init({parent, local?, unlink?}) do
    unless unlink?, do: :erlang.monitor(:process, parent)

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

  def handle_call({:configure, io, new_limit, formatter_opts}, %{formatter: formatter, limit: limit} = state) do
    new_limit = :maps.merge(limit, new_limit)
    {:reply, :ok, %{state | formatter: start_formatter(formatter, io, formatter_opts), io: io, limit: new_limit}}
  end

  def handle_call({:trace, processes, trace_options}, state) do
    :erlang.trace(processes, true, [{:tracer, self()} | trace_options])
    {:reply, :ok, state}
  end

  def handle_call({:set, pattern}, state) do
    {:reply, set_pattern(pattern), state}
  end

  def handle_call({:trace_and_set, processes, trace_options, pattern}, state) do
    :erlang.trace(processes, true, [{:tracer, self()} | trace_options])
    {:reply, set_pattern(pattern), state}
  end

  def handle_call(:status, state) do
    {:reply, state, state}
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

  defp set_pattern(pattern) do
    {{module, _, _} = pattern, match_options, global_options} = pattern

    case :code.ensure_loaded(module) do
      {:module, ^module} -> :erlang.trace_pattern(pattern, match_options, global_options)
      {:error, _} = error -> error
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
    formatter =
      with nil <- options[:formatter] do
        opts = Keyword.put_new(options[:format_opts] || [], :structs, false)
        {Formatter.Base, :format_trace, [opts]}
      end

    if options[:formatter_local] do
      node = :erlang.node(io)
      :erlang.spawn_link(node, Formatter, :init, [io, formatter])
    else
      Formatter.start_link(io, formatter)
    end
  end

  defp start_formatter(formatter, _io, options) do
    if new_formatter = options[:formatter], do: send(formatter, {:formatter, new_formatter})
    formatter
  end
end
