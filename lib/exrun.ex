defmodule Exrun do
  @moduledoc """
  Generall functions for introspection of running elixir/erlang system
  """
  use Application

  @doc false
  def start(_type, []) do
    Tracer.Supervisor.start_link
  end
end
