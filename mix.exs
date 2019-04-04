defmodule Exlasticsearch.MixProject do
  use Mix.Project

  @version "1.6.3"

  def project do
    [
      app: :exlasticsearch,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env),
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
      {:flow, "~> 0.13"},
      {:poison, "~> 3.1"},
      {:elastix, "~> 0.5.0"},
      {:ecto, ">= 2.1.0"},
      {:scrivener_ecto, "~> 2.0"},
      {:decorator, "~> 1.2"},
      {:ex_doc, "~> 0.19.1", only: :dev}
    ]
  end

  defp docs() do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: "https://github.com/Frameio/exlasticsearch"
    ]
  end

  defp description() do
    "Ecto-friendly Elasticsearch dsl"
  end

  defp package() do
    [
      maintainers: ["Michael Guarino"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Frameio/exlasticsearch"}
    ]
  end
end
