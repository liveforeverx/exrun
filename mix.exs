defmodule Exrun.Mixfile do
  use Mix.Project

  def project do
    [app: :exrun,
     version: "0.1.2",
     source_url: "https://github.com/liveforeverx/exrun",
     name: "Exrun",
     deps: deps,
     description: description,
     package: package]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [{:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.10", only: :dev}]
  end

  defp description do
    "Elixir - save and easy to use standalone, tracing tools for running elixir and erlang applications"
  end

  defp package do
    [maintainers: ["Dmitry Russ(Aleksandrov)"],
     licenses: ["Apache 2.0"],
     links: %{"Github" => "https://github.com/liveforeverx/exrun"}]
  end
end
