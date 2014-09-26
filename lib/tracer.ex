defmodule Tracer do
  alias Tracer.Pattern
  alias Tracer.Server

  defmacro trace(to_trace, options \\ []) do
    pattern = Pattern.compile(to_trace, options) |> Macro.escape(unquote: true)
    quote do
      Tracer.ensure_server_is_running
      Pattern.set(unquote(pattern))
    end
  end

  def trace_off() do
    :erlang.trace(:all, :false, [])
    send(Tracer, :exit_tracer)
  end

  def ensure_server_is_running(pid \\ Process.whereis(Tracer))

  def ensure_server_is_running(nil) do
    pid = :proc_lib.spawn_link(Server, :loop, [])
    Process.register(pid, Tracer)
    ensure_server_is_running(pid)
  end

  def ensure_server_is_running(pid) when is_pid(pid) do
    :erlang.trace(:all, true, [{:tracer, pid}, :call])
  end

  defmodule Server do
    def loop() do
      receive do
        msg when elem(msg, 0) == :trace ->
          Tracer.IO.print_trace(msg)
          loop()
        :exit_tracer ->
          IO.puts("exit tracer")
      end
    end
  end

end
