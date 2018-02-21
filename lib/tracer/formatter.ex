defmodule Tracer.Formatter do
  @moduledoc """
  Tracer format and io functions.
  """
  def start_link(group_leader, formatter) do
    spawn_link(__MODULE__, :init, [group_leader, formatter])
  end

  def init(group_leader, formatter) do
    :erlang.group_leader(self(), group_leader)
    loop(formatter)
  end

  defp loop(formatter) do
    receive do
      {:formatter, new_formatter} ->
        loop(new_formatter)

      msg ->
        format(msg, formatter) |> IO.puts()
        loop(formatter)
    end
  end

  defp format(msg, nil), do: format_trace(msg)
  defp format(msg, {m, f}), do: apply(m, f, [msg])
  defp format(msg, fun) when is_function(fun, 1), do: fun.(msg)

  @doc """
  Format trace message to a string.
  """
  def format_trace({:trace_ts, pid, :call, mfa, _timestamp}) do
    "#{inspect(pid)} call #{call_mfa(mfa)}"
  end

  def format_trace({:trace_ts, pid, :call, mfa, dump, _timestamp}) do
    traces =
      String.split(dump, "\n")
      |> Enum.filter(&Regex.match?(~r/Return addr 0x|CP: 0x/, &1))
      |> fold_over
      |> Enum.reverse()

    "#{inspect(pid)} call #{call_mfa(mfa)}#{traces}"
  end

  def format_trace({:trace_ts, pid, :return_from, mfa, return, time}) do
    "#{inspect(pid)} [#{time_used(time)}] returned " <>
      "#{return_mfa(mfa)}#{inspect(return, structs: false)}"
  end

  def format_trace({:trace_ts, pid, :exception_from, mfa, {class, value}, time}) do
    "#{inspect(pid)} [#{time_used(time)}] exception " <>
      "#{return_mfa(mfa)}#{inspect(class)}:#{inspect(value)}"
  end

  def format_trace(msg) do
    "unknown message: #{inspect(msg)}"
  end

  defp time_used(time) when time < 1000, do: time
  defp time_used(time), do: "#{div(time, 1000)}ms"

  defp call_mfa({module, function, arguments}) do
    "#{inspect(module)}.#{function}(" <>
      Enum.map_join(arguments, ", ", &inspect(&1, limit: 5000, structs: false)) <> ")"
  end

  defp return_mfa({module, function, argument}) do
    "#{inspect(module)}.#{function}/#{argument} -> "
  end

  defp fold_over(list, acc \\ [])

  defp fold_over([_last], acc), do: acc

  defp fold_over([one | tail], acc) do
    fold_over(tail, [extract_function(one) | acc])
  end

  defp extract_function(line) do
    case Regex.run(~r"^.+\((.+):(.+)/(\d+).+\)$", line, capture: :all_but_first) do
      [m, f, a_length] ->
        "\n  #{format_module(m)}.#{format_function(f)}/#{a_length}"

      nil ->
        ""
    end
  end

  defp format_module(binatom) do
    case unatom(binatom) do
      "Elixir." <> binatom -> binatom
      binatom -> ":#{binatom}"
    end
  end

  defp format_function(binatom) do
    unatom(binatom)
  end

  defp unatom(binatom) do
    body_size = byte_size(binatom) - 2

    case binatom do
      <<"'", body::binary-size(body_size), "'">> -> body
      _ -> binatom
    end
  end
end
