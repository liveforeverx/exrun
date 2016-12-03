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
      Limit options are merged with actually setted. It is possible to specify it
      per configuration as env `:limit` for application `:exrun`.

      The following limit options are available:

      * `:time` - specifies the time in milliseconds, where should the rate be
      applied. Default specified by environments. (Default: 1000)
      * `:rate` - specifies the limit of trace messages per time, if trace messages
      will be over this limit, the collectable process will stop and clear all traces.
      Default specified by environments. (Default: 100)
      * `:overall` - set the absolute limit for messages. After reaching this limit, the
      collactable process will clear all traces and stops. Default specified by environments.
      (Default: nil)

    * `:formatter_local` - flag for setting, where formatter process should be started.
    If set to `false`, then the formatter process will be started on remote node, if set
    to `true`, on a local machine. Defaults set to `false`. Tracer can trace on nodes,
    where elixir is not installed. If formatter_local set to true, there will be only 2
    modules loaded on remote erlang node (Tracer.Utils and Tracer.Collector), which forward
    messages to the connected node. If formatter_local set to false, than formatter started
    on remote node and it load all modules from elixir application, because for formatting
    traces there should be loaded at least all Inspect modules.

    * `:formatter` - own formatter function, example because you try to trace different
    inspect function. Formatter is either a fun or tuple `{module, function}`.

    * `:stack` - stacktrace for the process call should be printed

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
    node  = options[:node] || node()
    limit = options[:limit] || (Application.get_env(:exrun, :limit, %{rate: 100, time: 1000}) |> Enum.into(%{}) )

    formatter_options = options |> Keyword.put_new(:formatter_local, false)
    unless Process.get(:__tracer__) do
      Process.put(:__tracer__, %{})
    end
    check_node(node, formatter_options)
    Collector.ensure_started(node)
    {:group_leader, group_leader} = Process.info(self(), :group_leader)
    Collector.enable(node, group_leader, limit, :all, [:call, :timestamp], formatter_options)
    Collector.trace_pattern(node, compiled_pattern)
  end

  defp bootstrap(node, formatter_options) do
    applications = :rpc.call(node, :application, :loaded_applications, [])
    Utils.load_modules(node, [Utils, Collector])
    unless formatter_options[:formatter_local] do
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

  defp check_node(node, formatter_options) do
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
        bootstrap(node, formatter_options)
        Process.put(:__tracer__, :maps.put(node, %{node_conf | loaded: true}, tracer_conf))
      end
    end
  end

  def get_config(key), do: Process.get(:__tracer__) |> get_in([key])

  @doc """
  Stop tracing
  """
  def trace_off(options \\ []) do
    Collector.stop(options[:node] || node())
  end

  @doc """
  Scheduler usage based on scheduler wall time.
  """
  def scheduler_usage(interval \\ 1000) when is_integer(interval) do
    original_flag = :erlang.system_flag(:scheduler_wall_time, true)
    start_slice = :erlang.statistics(:scheduler_wall_time)
    :timer.sleep(interval)
    end_slice = :erlang.statistics(:scheduler_wall_time)
    original_flag || :erlang.system_flag(:scheduler_wall_time, original_flag)
    scheduler_usage(Enum.sort(start_slice), Enum.sort(end_slice))
  end

  ## In this case we can ignore tail-call
  defp scheduler_usage([], []),
    do: []
  defp scheduler_usage([{i, _, t} | next1], [{i, _, t} | next2]),
    do: [{i, 0.0} | scheduler_usage(next1, next2)]
  defp scheduler_usage([{i, a_start, t_start} | next1], [{i, a_end, t_end} | next2]),
    do: [{i, (a_start - a_end) / (t_start - t_end)} | scheduler_usage(next1, next2)]
end
