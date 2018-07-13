defmodule Exlasticsearch.MixProject do
  use Mix.Project

  def project do
    [
      app: :exlasticsearch,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env),
      deps: deps()
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
      {:ecto, "~> 2.1.0"},
      {:scrivener_ecto, "~> 1.0"},
    ]
  end
end
