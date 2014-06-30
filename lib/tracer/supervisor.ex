defmodule Tracer.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(), do: start_link(:master)

  def start_link(role) do
    Supervisor.start_link(__MODULE__, role, [name: __MODULE__])
  end

  def init(role) do
    consumer = case role do
      :master -> [worker(Tracer.Consumer, [])]
      :slave -> []
    end
    children = [worker(Tracer.Collector, []) | consumer]
    supervise(children, strategy: :one_for_one)
  end

end
