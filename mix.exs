defmodule Exlasticsearch.MixProject do
  use Mix.Project

  @version "2.2.4"
  @source_url "https://github.com/Frameio/exlasticsearch"

  def project do
    [
      app: :exlasticsearch,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:flow, "~> 1.0"},
      {:jason, "~> 1.4.0", optional: true},
      {:elastix, "~> 0.10.0"},
      {:ecto, "~> 3.0"},
      {:scrivener_ecto, "~> 3.0"},
      {:decorator, "~> 1.2"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:styler, "~> 1.2", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "LICENSE.md": [title: "License"]
      ],
      api_reference: false,
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html"]
    ]
  end

  defp description, do: "Ecto-friendly Elasticsearch DSL"

  defp package do
    [
      description: "Ecto-friendly Elasticsearch DSL",
      maintainers: ["Michael Guarino"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
