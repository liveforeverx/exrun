defmodule Tracer do
  alias Tracer.Pattern
  alias Tracer.Collector
  alias Tracer.Utils

  @moduledoc """
  """

  @doc """

  ## Options

  The following options are available:

    * `:node` - specified the node, on which trace should be started.

    * `:limit` - specifies the limit, that should be used on collectable process.
      Limit options are merged with actually setted.

      The following limit options are available:

      * `:time` - specifies the time in miliseconds, where should the rate be
      applied.
      * `:rate` - specifies the limit of trace messages per time, if trace messages
      will be over this limit, the collectable process will stops and clear all traces.
      * `:overall` - set the absolut limit for messages. After reaching this limit, the
      collactable process will clear all traces ans stopes.

    * `:formatter_local` - flag for setting, where formatter process should be started.
    If set to `false`, then the formatter process will be started on remote node, if set
    to `true`, on a local machine. Defaults set to `false`. Tracer can trace on nodes,
    where elixir is not installed. If formatter_local set to true, there will be only 2
    modules loaded on remote erlang node (Tracer.Utils and Tracer.Collector), which forward
    messages to the connected node. If formatter_local set to false, than formatter started
    on remote node and it load all modules from elixir application, because for formating
    traces there should be loaded at least all Inspect modules.

    * `:stack` - stacktrace for the process call should bу printed

    * `:exported` - only exported functions should be printed.

    * `:no_return` - no returns should be printed for a calls

  ## Examples

      iex> import Tracer # should be to simplify using of trace
      nil

      iex> trace :lists.seq
      {:ok, 2}

      iex> trace :lists.seq/2
      {:ok, 1}

      iex> trace :lists.seq(1, 10)
      {:ok, 2}

      iex> trace :lists.seq(a, b) when a < 10 and b > 25
      {:ok, 2}

      iex> trace :maps.get(:undefined, _), [:stack]
      {:ok, 2}

      iex> trace :maps.get/2, [limit: %{overall: 100, rate: 50, time: 50}]
      {:ok, 2}
  """
  defmacro trace(to_trace, options \\ []) do
    pattern = Pattern.compile(to_trace, options) |> Macro.escape(unquote: true)
    quote do
      Tracer.trace_run(unquote(pattern), unquote(options))
    end
  end

  def trace_run(compiled_pattern, options \\ []) do
    node = Keyword.get(options, :node, node)
    limit = Keyword.get(options, :limit, %{})
    formatter_local = Keyword.get(options, :formatter_local, false)
    unless Process.get(:__tracer__) do
      Process.put(:__tracer__, %{})
    end
    check_node(node, formatter_local)
    Collector.ensure_started(node)
    {:group_leader, group_leader} = Process.info(self, :group_leader)
    Collector.enable(node, group_leader, limit, :all, [:call], formatter_local)
    Collector.trace_pattern(node, compiled_pattern)
  end

  defp bootstrap(node, formatter_local) do
    applications = :rpc.call(node, :application, :loaded_applications, [])
    Utils.load_modules(node, [Utils, Collector])
    unless formatter_local do
      modules = case :lists.keyfind(:elixir, 1, applications) do
        {:elixir, _, _} ->
          []
        _ ->
          {:ok, modules} = :application.get_key(:elixir, :modules)
          modules
      end
      Utils.load_modules(node, [Tracer.Formatter | modules])
    end
  end

  defp check_node(node, formatter_local) do
    if node() == node do
      :ok
    else
      tracer_conf = Process.get(:__tracer__)
      node_conf = %{loaded: loaded} = case :maps.get(node, tracer_conf, nil) do
        nil ->
          %{loaded: false}
        node_conf ->
          node_conf
      end
      unless loaded do
        bootstrap(node, formatter_local)
        Process.put(:__tracer__, :maps.put(node, %{node_conf | loaded: true}, tracer_conf))
      end
    end
  end

  def get_config(key), do: Process.get(:__tracer__) |> get_in([key])

  def trace_off(options \\ []) do
    node = Keyword.get(options, :node, node)
    Collector.stop(node)
  end

end
