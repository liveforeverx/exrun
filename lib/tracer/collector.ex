defmodule Tracer.Collector do
  alias Tracer.Formatter
  alias Tracer.Pattern
  import Tracer.Utils

  def ensure_started(node) do
    case rpc(node, :erlang, :whereis, [__MODULE__]) do
      pid when is_pid(pid) -> pid
      :undefined -> start(node)
    end
  end

  def start(node \\ node) do
    pid = :erlang.spawn(node, __MODULE__, :init, [self])
    {rpc(node, :erlang, :register, [__MODULE__, pid]), node}
  end

  def enable(node, group_leader, limit, processes, trace_options, formatter) do
    call({__MODULE__, node}, {:enable, group_leader, limit, processes, trace_options, formatter})
  end

  def trace_pattern(node, pattern) do
    call({__MODULE__, node}, {:set, pattern})
  end

  def stop(node), do: call({__MODULE__, node}, :stop)

  def init(parent) do
    :erlang.monitor(:process, parent)
    loop(%{parent: parent, formatter: nil, group_leader: nil,
           limit: %{time: nil, rate: nil, overall: nil}, window: :os.timestamp(), count: 0, all_count: 0})
  end

  def loop(state = %{parent: parent}) do
    receive do
      {{pid, ref} = _from, msg} ->
        {action, answer, new_state} = handle_call(msg, state)
        send(pid, {ref, answer})
        case action do
          :stop  -> stop
          :reply -> loop(new_state)
        end
      {:DOWN, _, _, ^parent, _} ->
        stop
      msg ->
        handle_trace(msg, state) |> loop()
    end
  end

  def handle_call({:enable, group_leader, new_limit, processes, trace_options, formatter}, state = %{limit: limit}) do
    :erlang.trace(processes, true, [{:tracer, self} | trace_options])
    { :reply, :ok, %{state | formatter: start_formatter(group_leader, formatter),
                             group_leader: group_leader,
                             limit: :maps.merge(limit, new_limit)} }
  end

  def handle_call({:set, pattern}, state) do
    {pattern, match_options, global_options} = pattern
    result = :erlang.trace_pattern(pattern, match_options, global_options)
    {:reply, result, state}
  end

  def handle_call(:stop, state) do
    {:stop, :ok, state}
  end

  def stop() do
    :erlang.trace(:all, false, [:all])
    :erlang.trace_pattern({:_,:_,:_}, false, [:local, :meta, :call_count, :call_time])
    :erlang.trace_pattern({:_,:_,:_}, false, [])
    exit({:shutdown, :stop})
  end

  def handle_trace(trace, %{limit: limit, formatter: formatter, window: window, count: count, all_count: all} = state) when (elem(trace, 0) == :trace) do
    send(formatter, trace)
    %{time: time, rate: rate, overall: overall} = limit
    now = :os.timestamp()
    delay = :timer.now_diff(now, window) |> div(1000)
    cond do
      all > overall -> stop()
      delay > time  -> %{state | window: now, count: 0, all_count: all + 1}
      rate <= count -> stop()
      rate > count  -> %{state | count: count + 1, all_count: all + 1}
    end
  end

  defp start_formatter(group_leader, false) do
    Formatter.start_link(group_leader)
  end

  defp start_formatter(group_leader, true) do
    node = :erlang.node(group_leader)
    :erlang.spawn_link(node, Formatter, :init, [group_leader])
  end

end
