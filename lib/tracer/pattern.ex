defmodule Tracer.Pattern do
  @moduledoc """
  Module for transformation of an Elixir AST to a pattern, that possible to use for tracing
  """

  @doc """
  Compile pattern from elixir AST and options
  """
  def compile(pattern, options \\ []) do
    exported_opt = Enum.member?(options, :exported)
    {mfa, [{args, conditions, trace_options}]} = compile_intern(pattern)

    {
      mfa,
      [{args, conditions, set_trace_options(options, trace_options)}],
      set_transform_opions(exported_opt)
    }
  end

  defp compile_intern({:when, _, [{{:., _, [module, function]}, _, args}, conditions]}) do
    {args, map} = transform_arguments(args)
    conditions = [transform_conditions(conditions, map)]
    {mfa(module, function), [match_spec(args, conditions)]}
  end

  defp compile_intern({:/, _, [{{:., _, [module, function]}, _, []}, arity]}) do
    {mfa(module, function, arity), [match_spec(:_)]}
  end

  defp compile_intern({{:., _, [module, function]}, _, args}) do
    {mfa(module, function), [match_spec(args |> transform_arguments |> elem(0))]}
  end

  defp compile_intern(module_name) when is_atom(module_name) or is_tuple(module_name) do
    {mfa(module_name), [match_spec()]}
  end

  defp compile_intern(pattern) when is_binary(pattern) do
    {:ok, pattern} = Code.string_to_quoted(pattern)
    compile_intern(pattern)
  end

  defp module_name(module_ast), do: Macro.expand(module_ast, __ENV__)

  defp mfa(module, function \\ :_, arity \\ :_), do: {module_name(module), function, arity}

  defp match_spec(args \\ :_, conditions \\ [])
  defp match_spec([], conditions), do: {:_, conditions, trace_options()}
  defp match_spec(args, conditions), do: {args, conditions, trace_options()}

  defp trace_options, do: [{:return_trace}, {:exception_trace}]

  defp set_transform_opions(true), do: []
  defp set_transform_opions(false), do: [:local]

  defp set_trace_options([], args), do: args

  defp set_trace_options([:stack | options], args) do
    set_trace_options(options, [{:message, {:process_dump}} | args])
  end

  defp set_trace_options([:no_return | options], args) do
    set_trace_options(options, args -- [{:exception_trace}, {:return_trace}])
  end

  defp set_trace_options([_ | options], args) do
    set_trace_options(options, args)
  end

  defp transform_arguments(args, map \\ %{count: 1}, action \\ :save)

  defp transform_arguments(args, map, action) when is_list(args) do
    {new_args, new_map} =
      Enum.reduce(args, {[], map}, fn arg, {acc, map} ->
        {arg, new_map} = transform_arguments(arg, map, action)
        {[arg | acc], new_map}
      end)

    {Enum.reverse(new_args), new_map}
  end

  defp transform_arguments({type, _, args}, map, action) when type in [:{}, :<<>>, :%{}] do
    {args, new_map} = transform_arguments(args, map, action)
    {transform_back_fun(type).(args), new_map}
  end

  defp transform_arguments({key, value}, map, action) do
    {[key, value], new_map} = transform_arguments([key, value], map, action)
    {{key, value}, new_map}
  end

  defp transform_arguments({:__aliases__, _, _} = alias_ast, map, _) do
    {Macro.expand(alias_ast, __ENV__), map}
  end

  defp transform_arguments({:_, _, _}, map, :save), do: {:_, map}

  defp transform_arguments({atom, _, _}, %{count: count} = map, :save) do
    {count, new_map} =
      case Map.fetch(map, atom) do
        {:ok, exists_id} ->
          {exists_id, map}

        :error ->
          {count, Enum.into([{:count, count + 1}, {atom, count}], map)}
      end

    {:"$#{count}", new_map}
  end

  defp transform_arguments({atom, _, _} = var, map, :restore) do
    value =
      case Map.fetch(map, atom) do
        {:ok, value} -> :"$#{value}"
        :error -> {:unquote, [], [quote(do: unquote(var))]}
      end

    {value, map}
  end

  defp transform_arguments(arg, map, _action)
       when is_atom(arg) or is_number(arg) or is_binary(arg) do
    {arg, map}
  end

  defp transform_back_fun(:{}), do: &List.to_tuple/1
  defp transform_back_fun(:<<>>), do: &List.to_string/1
  defp transform_back_fun(:%{}), do: &:maps.from_list/1

  @function [
    :is_atom,
    :is_float,
    :is_integer,
    :is_list,
    :is_number,
    :is_map,
    :is_pid,
    :is_port,
    :is_reference,
    :is_tuple,
    :is_binary,
    :is_boolean,
    :abs,
    :hd,
    :length,
    :round,
    :tl,
    :trunc,
    :not
  ]
  defp transform_conditions({name, _, [var]}, map) when name in @function do
    {name, transform_conditions(var, map)}
  end

  @operators [
    {:and, :andalso},
    {:or, :orelse},
    :xor,
    :>,
    :>=,
    :<,
    {:<=, :"=<"},
    :==,
    {:===, :"=:="},
    {:!=, :"/="},
    {:!==, :"=/="},
    :+,
    :-,
    :*,
    {:/, :div},
    :rem
  ]
  Enum.map(@operators, fn
    {elixir_op, erlang_op} ->
      defp transform_conditions({unquote(elixir_op), _, [left, right]}, map) do
        {unquote(erlang_op), transform_conditions(left, map), transform_conditions(right, map)}
      end

    op ->
      defp transform_conditions({unquote(op), _, [left, right]}, map) do
        {unquote(op), transform_conditions(left, map), transform_conditions(right, map)}
      end
  end)

  defp transform_conditions({:elem, _, [var, index]}, map) do
    {:element, index + 1, transform_conditions(var, map)}
  end

  @function [:node, :self]
  defp transform_conditions({name, _, []}, _) when name in @function do
    {name}
  end

  defp transform_conditions(data, map) do
    transform_arguments(data, map, :restore) |> elem(0)
  end

  # Not supported at the moment: is_record/{1,2}
end
