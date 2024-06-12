defmodule Vecto.MixProject do
  use Mix.Project

  def project do
    [
      app: :vecto,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:ecto_psql_extras, "~> 0.8"},
      {:postgrex, ">= 0.0.0"},
      {:pgvector, "~> 0.2.1"}
    ]
  end
end
