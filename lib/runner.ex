defmodule Runner do
  @moduledoc """
  Generall functions for introspection of running elixir/erlang system
  """

  @formats [
    {1_099_511_627_776, "TiB"},
    {1_073_741_824, "GiB"},
    {1_048_576, "MiB"},
    {1_024, "KiB"},
    {0, "B"}
  ]
  @doc """
  Helper function to transform bytes in appropriate format.
  """
  def format(bytes), do: format(@formats, bytes)

  defp format([{value, _type} | tail], bytes) when bytes <= value, do: format(tail, bytes)
  defp format([{value, type} | _], bytes), do: {div(bytes, value), type}

  @doc """
  Find n processes, which use the most memory.
  """
  def processes(n \\ 10) do
    pids =
      for pid <- :erlang.processes() do
        {pid, id, memory} = process_info(pid, :memory)
        {memory, {pid, id}}
      end

    for {memory, id} <- top(pids, n), do: {id, format(memory)}
  end

  defp top(list, n) do
    list
    |> Enum.sort()
    |> Enum.reverse()
    |> Enum.take(n)
  end

  @doc """
  Find tabs
  """
  def tabs(n \\ 10) do
    tabs = for tab <- :ets.all(), do: {tab_memory(tab), tab}

    for {memory, id} <- top(tabs, n), do: {id, format(memory)}
  end

  defp tab_memory(tab), do: :ets.info(tab, :memory) * :erlang.system_info(:wordsize)

  @doc """
  System memory
  """
  def sys_mem() do
    :erlang.memory() |> Enum.map(fn {key, value} -> {key, format(value)} end)
  end

  def sys_mem(memory) do
    memory |> Enum.map(fn {key, value} -> {key, format(value)} end)
  end

  @doc """
  Get allocator usage.
  """
  def memory(:types) do
    allocators = util_allocators()

    result =
      Enum.reduce(allocators, %{}, fn {{alloc, _}, props}, acc ->
        count = cont_size(props, :carriers_size)
        Map.update(acc, alloc, count, &(&1 + count))
      end)

    for {key, value} <- result, into: %{}, do: {key, format(value)}
  end

  @current 1

  defp cont_size(props, container) do
    cont_value(props, :sbcs, container) + cont_value(props, :mbcs, container)
  end

  defp cont_value(props, :mbcs = type, container)
       when container in [:blocks, :blocks_size, :carriers, :carriers_size] do
    in_props(props, :mbcs_pool, container) + in_props(props, type, container)
  end

  defp cont_value(props, type, container) when type in [:sbcs, :mbcs] do
    in_props(props, type, container)
  end

  defp in_props(props, type, container) do
    case Keyword.get(props, type) do
      nil ->
        0

      props ->
        found_cont = List.keyfind(props, container, 0)
        elem(found_cont, @current)
    end
  end

  @util_allocators [
    :temp_alloc,
    :eheap_alloc,
    :binary_alloc,
    :ets_alloc,
    :driver_alloc,
    :sl_alloc,
    :ll_alloc,
    :fix_alloc,
    :std_alloc
  ]

  @doc """
  Util allocators
  """
  def util_allocators() do
    for {{type, _}, _} = data <- allocators(), type in @util_allocators, do: data
  end

  @doc """
  Allocators
  """
  def allocators() do
    allocators = [:sys_alloc, :mseg_alloc | :erlang.system_info(:alloc_util_allocators)]

    for allocator <- allocators,
        allocs <- [:erlang.system_info({:allocator, allocator})],
        allocs != false,
        {_, n, props} <- allocs do
      props = List.keydelete(props, :versions, 0)
      {{allocator, n}, Enum.sort(props)}
    end
  end

  @doc """
  Check process for binary leak.
  """
  def binary_leak_pid(pid) do
    try do
      {_, id, bin_before} = process_info(pid, :binary)
      :erlang.garbage_collect(pid)
      {_, _, bin_after} = process_info(pid, :binary)
      {length(bin_before) - length(bin_after), {pid, id}}
    catch
      _, _ -> {0, {pid, []}}
    end
  end

  @doc """
  Check for binary memory leaks, using garbage collection.
  """
  def binary_leak(n) do
    pids = for pid <- :erlang.processes(), do: binary_leak_pid(pid)
    for {memory, {pid, id}} <- top(pids, n), do: {{pid, id}, memory}
  end

  @doc """
  Process info, which gives the identifier information back, like registered name, initial call and
  current function, which helps to identify process.
  """
  @proc_identifiers [:registered_name, :current_function, :initial_call]
  def process_info(pid, :binary_memory) do
    with [{_, binaries} | identifiers] <- Process.info(pid, [:binary | @proc_identifiers]) do
      {pid, format_id(identifiers), binary_memory(binaries)}
    end
  end

  def process_info(pid, attr) do
    with [{_, attr} | identifiers] <- Process.info(pid, [attr | @proc_identifiers]) do
      {pid, format_id(identifiers), attr}
    end
  end

  defp format_id([{:registered_name, name}, init, current]) do
    List.wrap(name) ++ [init, current]
  end

  defp binary_memory(binaries) do
    Enum.reduce(binaries, 0, fn {_, memory, _}, acc -> acc + memory end)
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
  defp scheduler_usage([], []), do: []

  defp scheduler_usage([{i, _, t} | next1], [{i, _, t} | next2]),
    do: [{i, 0.0} | scheduler_usage(next1, next2)]

  defp scheduler_usage([{i, a_start, t_start} | next1], [{i, a_end, t_end} | next2]),
    do: [{i, (a_start - a_end) / (t_start - t_end)} | scheduler_usage(next1, next2)]
end
