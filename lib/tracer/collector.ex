defmodule Tracer.Collector do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, nil, [name: __MODULE__])
  end

  def enable(consumer, options, processes, trace_options) do
    GenServer.call(__MODULE__, {:enable, consumer, options, processes, trace_options})
  end

  def disable(), do: GenServer.call(__MODULE__, :disable)

  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, nil}
  end

  def handle_call({:enable, consumer, options, processes, trace_options}, _from, _state) do
    :erlang.trace(processes, true, [{:tracer, self} | trace_options])
    { :reply, :ok, consumer }
  end

  def handle_call(:disable, _from, _consumer) do
    :erlang.trace(:all, :false, [])
    { :reply, :ok, nil }
  end

  def handle_info(trace, consumer) when (elem(trace, 0) == :trace) and is_pid(consumer) do
    case self do
      ^consumer ->
        Tracer.IO.print_trace(trace)
      _ ->
        send consumer, trace
    end
  end
end
