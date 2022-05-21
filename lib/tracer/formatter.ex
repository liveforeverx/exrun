defmodule Tracer.Formatter do
  @moduledoc """
  Tracer format and io functions.
  """

  import Tracer.Utils

  def start_link(io, formatter) do
    spawn_link(__MODULE__, :init, [io, formatter])
  end

  def init({init_fun, handle_fun}, formatter) when is_function(init_fun) or is_tuple(init_fun) do
    io = apply_func(init_fun)
    loop({io, handle_fun}, formatter)
  end

  def init({io, handle_fun}, formatter) when is_pid(io) do
    loop({io, handle_fun}, formatter)
  end

  defp loop(io_spec, formatter) do
    receive do
      {:formatter, new_formatter} ->
        loop(io_spec, new_formatter)

      {:flush, pid} ->
        flush_messages(io_spec, formatter, pid)

      msg ->
        format_and_print(io_spec, formatter, msg)
        loop(io_spec, formatter)
    end
  end

  defp flush_messages(io_spec, formatter, pid) do
    receive do
      msg ->
        format_and_print(io_spec, formatter, msg)
        flush_messages(io_spec, formatter, pid)
    after
      0 ->
        send(pid, :flushed)
        loop(io_spec, formatter)
    end
  end

  defp format_and_print({io, handle_fun}, formatter, msg) do
    with formatted_string when is_binary(formatted_string) <- apply_func(formatter, msg) do
      apply_func(handle_fun, [io, formatted_string])
    end
  end
end
