defmodule Tracer do
  @moduledoc """
  Main interface for tracing functionallity.

  Usage:

      use Tracer
      trace Map.new()

  Options:

    * `:node` - specified the node, on which trace should be started.

    * `:limit` - specifies the limit, that should be used on collectable process.
      Limit options are merged with actually setted. It is possible to specify it
      per configuration as env `:limit` for application `:exrun`.

      The following limit options are available:

      * `:time` - specifies the time in milliseconds, where should the rate be
      applied. Default specified by environments. (Default: 1000)
      * `:rate` - specifies the limit of trace messages per time, if trace messages
      will be over this limit, the collectable process will stop and clear all traces.
      Default specified by environments. (Default: 250)
      * `:overall` - set the absolute limit for messages. After reaching this limit, the
      collactable process will clear all traces and stops. Default specified by environments.
      (Default: nil)

      Additionally limit can be specified as `limit: 5`, than it equivalent to `limit: %{overall: 5}`

    * `:formatter_local` - flag for setting, where formatter process should be started.
    If set to `false`, then the formatter process will be started on remote node, if set
    to `true`, on a local machine. Defaults set to `false`. Tracer can trace on nodes,
    where elixir is not installed. If formatter_local set to true, there will be only 2
    modules loaded on remote erlang node (Tracer.Utils and Tracer.Collector), which forward
    messages to the connected node. If formatter_local set to false, than formatter started
    on remote node and it load all modules from elixir application, because for formatting
    traces there should be loaded at least all Inspect modules.

    * `:formatter` - own formatter function, example because you try to trace different
    inspect function. Formatter is either a fun or tuple `{module, function, opts}`.

    * `:format_opts` - any format options, which will be passed to `inspect/2`. Per default structs
    are disabled.

    * `:io` - specify io process, which should handle io from a tracer or a tuple `{init_fun, handle_fun}`, which
    handles initialization and io process. `init_fun` has zero arguments and should return `io`, which will be
    passed to `handle_fun` together with a message.

    * `:unlink` - tracer won't be stoped once a process started it terminates. (should be used for tracing into files
    or using network)

    * `:file` - specifies a file, where traces should be saved. Option `[file: "/tmp/trace.log"]` is a shortcut for
    `[unlink: true, io: {{File, :open!, ["/tmp/trace.log", [:append]]}, {IO, :puts, []}}]`
  """

  alias Tracer.Pattern
  alias Tracer.Collector
  alias Tracer.Utils

  defmacro __using__(options) do
    quote do
      import Tracer
      ensure_tracer(unquote(options))
    end
  end

  @doc """
  Ensure tracer started
  """
  def ensure_tracer(options) do
    node = options[:node] || node()

    formatter_options = Keyword.put_new(options, :formatter_local, false)
    unless Process.get(:__tracer__), do: Process.put(:__tracer__, %{node: node})

    check_node(node, formatter_options)

    options = options |> expand_file_opts() |> expand_io_opts()

    {status, _pid} = Collector.ensure_started(node, options[:unlink] || false)

    {:ok, _} = Collector.configure(node, options[:io], limit_opts(options), formatter_options)
    {:ok, status}
  end

  defp limit_opts(options) do
    case options[:limit] do
      nil -> default_limit()
      limit when is_integer(limit) -> Map.merge(default_limit(), %{overall: limit})
      limit when is_map(limit) -> limit
    end
  end

  defp default_limit() do
    Application.get_env(:exrun, :limit, %{rate: 250, time: 1000}) |> Enum.into(%{})
  end

  defp expand_file_opts(options) do
    case Keyword.fetch(options, :file) do
      {:ok, path} ->
        io_spec = {{File, :open!, [path, [:append]]}, {IO, :puts, []}}
        Keyword.merge(options, unlink: true, io: io_spec)

      :error ->
        options
    end
  end

  defp expand_io_opts(options) do
    case Keyword.fetch(options, :io) do
      {:ok, {_, _}} ->
        options

      {:ok, io_pid} when is_pid(io_pid) ->
        Keyword.put(options, :io, {io_pid, {IO, :puts, []}})

      :error ->
        {:group_leader, group_leader} = Process.info(self(), :group_leader)
        Keyword.put(options, :io, {group_leader, {IO, :puts, []}})
    end
  end

  @doc """
  ## Options

  The following options are available:

    * `:stack` - stacktrace for the process call should be printed

    * `:exported` - only exported functions should be printed

    * `:no_return` - no returns should be printed for a calls

    * `:pid` - specify pid, you want to trace, otherwise all processes are traced

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
    options = List.wrap(options)
    pattern = Pattern.compile(to_trace, options) |> Macro.escape(unquote: true)

    quote do
      Tracer.trace_run(unquote(pattern), unquote(options))
    end
  end

  def trace_run(compiled_pattern, options \\ []) do
    node = Process.get(:__tracer__, %{node: node()})[:node]

    process_spec = options[:pid] || :all
    trace_opts = [:call, :timestamp]
    Collector.trace_and_set(node, process_spec, trace_opts, compiled_pattern)
  end

  defp check_node(node, formatter_options) do
    if node() == node do
      :ok
    else
      tracer_conf = Process.get(:__tracer__)

      node_conf =
        case :maps.get(node, tracer_conf, nil) do
          nil -> %{loaded: false}
          node_conf -> node_conf
        end

      unless node_conf.loaded do
        ensure_bootstraped(node, formatter_options)
        Process.put(:__tracer__, :maps.put(node, %{node_conf | loaded: true}, tracer_conf))
      end
    end
  end

  defp ensure_bootstraped(node, formatter_options) do
    applications = :rpc.call(node, :application, :loaded_applications, [])

    case :lists.keyfind(:exrun, 1, applications) do
      {:exrun, _, _} -> :ok
      _ -> bootstrap(node, applications, formatter_options)
    end
  end

  defp bootstrap(node, applications, formatter_options) do
    Utils.load_modules(node, [Utils, Collector])

    unless formatter_options[:formatter_local] do
      modules =
        case :lists.keyfind(:elixir, 1, applications) do
          {:elixir, _, _} ->
            []

          _ ->
            {:ok, modules} = :application.get_key(:elixir, :modules)
            modules
        end

      Utils.load_modules(node, [Tracer.Formatter | modules])
    end
  end

  def get_config(key), do: Process.get(:__tracer__) |> get_in([key])

  @doc """
  Get status of tracer.
  """
  def status(options \\ []) do
    node = options[:node] || node()

    case Collector.status(node) do
      {:ok, %{parent: parent}} -> {:ok, %{enabled: true, parent: parent == self()}}
      {:error, :noproc} -> {:ok, %{enabled: false}}
    end
  end

  @doc """
  Stop tracing
  """
  def trace_off(options \\ []) do
    Collector.stop(options[:node] || node())
  end
end
