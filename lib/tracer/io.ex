defmodule Tracer.IO do
  def print_trace(trace), do: trace |> Tracer.Formatter.format_trace |> IO.puts()
end
