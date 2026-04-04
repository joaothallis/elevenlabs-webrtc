defmodule MedsimAi.MixProject do
  use Mix.Project

  def project do
    [
      app: :medsim_ai,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {MedsimAi.Application, []},
      extra_applications: [:logger, :runtime_tools, :ssl, :inets]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7.14"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 0.20.17"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:jason, "~> 1.4"},
      {:bandit, "~> 1.6"},
      {:req, "~> 0.5"},
      {:ex_webrtc, "~> 0.8"},
      {:websockex, "~> 0.4.3"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["esbuild medsim_ai"],
      "assets.deploy": ["esbuild medsim_ai --minify", "phx.digest"]
    ]
  end
end
