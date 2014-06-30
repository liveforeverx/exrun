defmodule Exrun do
  use Application

  @doc false
  def start(_type, []) do
    Tracer.Supervisor.start_link
  end
end
