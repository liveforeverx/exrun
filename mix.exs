defmodule Exrun.Mixfile do
  use Mix.Project

  def project do
    [app: :exrun,
     version: "0.1.0",
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
    []
  end

  defp description do
    "Elixir - save and easy to use, tracing tools for running elixir and erlang applications"
  end

  defp package do
    [contributors: ["Dmitry Russ(Aleksandrov)"],
     links: %{"Github" => "https://github.com/liveforeverx/exrun"}]
  end
end
