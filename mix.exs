defmodule Exlasticsearch.MixProject do
  use Mix.Project

  @source_url "https://github.com/Frameio/exlasticsearch"
  @version "2.2.1"

  def project do
    [
      app: :exlasticsearch,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:flow, "~> 1.0"},
      {:poison, "~> 3.1"},
      {:elastix, "~> 0.10.0"},
      {:ecto, ">= 2.1.0"},
      {:scrivener_ecto, "~> 2.0"},
      {:decorator, "~> 1.2"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs() do
    [
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end

  defp package() do
    [
      description: "Ecto-friendly Elasticsearch DSL",
      maintainers: ["Michael Guarino"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end
end
