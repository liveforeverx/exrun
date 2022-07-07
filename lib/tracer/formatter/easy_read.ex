defmodule Tracer.Formatter.EasyRead do
  @doc """
  Format trace message to a string.
  """

  alias Tracer.Formatter.Base

  def format_trace({:trace_ts, pid, :call, mfa, timestamp}, opts) do
    "#{inspect(pid)} [#{Base.format_time(timestamp)}] call #{call_mfa(mfa, opts)}"
  end

  def format_trace({:trace_ts, pid, :call, mfa, dump, timestamp}, opts) do
    traces = Base.format_dump(dump)
    "#{inspect(pid)} [#{Base.format_time(timestamp)}] call #{call_mfa(mfa, opts)}#{traces}"
  end

  def format_trace(trace, opts) do
    Base.format_trace(trace, opts)
  end

  defp call_mfa({module, function, arguments}, opts) do
    arguments_string = arguments |> Enum.with_index() |> Enum.map_join("\n", &to_argument(&1, opts))
    "#{inspect(module)}.#{function}/#{length(arguments)} with arguments:\n" <> arguments_string
  end

  defp to_argument({argument, index}, opts), do: " -> #{index}: #{inspect(argument, opts)}"
end
