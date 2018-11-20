defmodule Tracer.Utils do
  @moduledoc """
  Some utils functions and reimplemmenting some usefull functions, because if they traced, the
  calls, made from tracer shouldn't traced too.
  """

  defmacrop waiting(answer, process, mref, timeout) do
    quote do
      receive do
        unquote(answer) = reply ->
          Process.demonitor(unquote(mref), [:flush])
          {:ok, reply}

        {:DOWN, ^unquote(mref), _, _, :noconnection} ->
          {:error, {:nodedown, node(unquote(process))}}

        {:DOWN, ^unquote(mref), _, _, reason} ->
          {:error, reason}
      after
        unquote(timeout) ->
          Process.demonitor(unquote(mref), [:flush])
          {:error, :timeout}
      end
    end
  end

  def call!(identifier, request, timeout \\ 10000) do
    case call(identifier, request, timeout) do
      {:ok, reply} -> reply
      {:error, error} -> exit(error)
    end
  end

  def call(identifier, request, timeout \\ 10000) do
    pid = get_process(identifier)
    mref = Process.monitor(pid)

    try do
      Process.send(pid, {{self(), mref}, request}, [:noconnect])
    catch
      _, _ -> :ok
    end

    with {:ok, {_, reply}} <- waiting({^mref, _}, pid, mref, timeout), do: {:ok, reply}
  end

  defp get_process({name, node}), do: rpc(node, :erlang, :whereis, [name])
  defp get_process(pid) when is_pid(pid), do: pid
  defp get_process(name), do: :erlang.whereis(name)

  def load_modules(node, module_list \\ [Tracer.Utils]) do
    data = for m <- module_list, do: :code.get_object_code(m)

    for {m, object_code, filename} <- data do
      ## We need to use :rpc, because on remote node our code may be not loaded and not exists
      {:module, _} = :rpc.call(node, :code, :load_binary, [m, filename, object_code])
    end

    true
  end

  def rpc(node, module, function, args, timeout \\ 5000) do
    tag = make_ref()

    pid =
      if node() == node do
        spawn(Tracer.Utils, :rpc_local, [self(), tag, module, function, args])
      else
        :erlang.spawn(node, Tracer.Utils, :rpc_local, [self(), tag, module, function, args])
      end

    mref = Process.monitor(pid)

    case waiting({^tag, _}, pid, mref, timeout) do
      {:ok, {_, reply}} -> reply
      {:error, error} -> exit(error)
    end
  end

  def rpc_local(parent, tag, module, function, args) do
    result = apply(module, function, args)
    send(parent, {tag, result})
  end
end
