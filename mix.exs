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
      {:phoenix, git: "https://github.com/phoenixframework/phoenix.git", tag: "v1.7.14", override: true},
      {:phoenix_html, git: "https://github.com/phoenixframework/phoenix_html.git", tag: "v4.1.1", override: true},
      {:phoenix_live_view, git: "https://github.com/phoenixframework/phoenix_live_view.git", tag: "v0.20.17", override: true},
      {:phoenix_live_reload, git: "https://github.com/phoenixframework/phoenix_live_reload.git", tag: "v1.5.3", only: :dev, override: true},
      {:phoenix_pubsub, git: "https://github.com/phoenixframework/phoenix_pubsub.git", tag: "v2.1.3", override: true},
      {:phoenix_template, git: "https://github.com/phoenixframework/phoenix_template.git", tag: "v1.0.4", override: true},
      {:esbuild, git: "https://github.com/phoenixframework/esbuild.git", tag: "v0.8.2", runtime: Mix.env() == :dev, override: true},
      {:jason, git: "https://github.com/michalmuskala/jason.git", tag: "v1.4.4", override: true},
      {:bandit, git: "https://github.com/mtrudel/bandit.git", tag: "1.6.11", override: true},
      {:req, git: "https://github.com/wojtekmach/req.git", tag: "v0.5.8", override: true},
      # ex_webrtc requires Hex access for deep native deps (ex_dtls, ex_libsrtp, etc.)
      # Uncomment when Hex is available: {:ex_webrtc, "~> 0.16.0"},
      {:websockex, git: "https://github.com/Azolo/websockex.git", tag: "v0.4.3", override: true},
      # Transitive dependency overrides (git sources to bypass Hex)
      {:plug, git: "https://github.com/elixir-plug/plug.git", tag: "v1.16.1", override: true},
      {:plug_crypto, git: "https://github.com/elixir-plug/plug_crypto.git", tag: "v2.1.0", override: true},
      {:telemetry, git: "https://github.com/beam-telemetry/telemetry.git", tag: "v1.3.0", override: true},
      {:thousand_island, git: "https://github.com/mtrudel/thousand_island.git", tag: "1.3.6", override: true},
      {:hpax, git: "https://github.com/elixir-mint/hpax.git", tag: "v1.0.0", override: true},
      {:websock, git: "https://github.com/phoenixframework/websock.git", tag: "0.5.3", override: true},
      {:mime, git: "https://github.com/elixir-plug/mime.git", tag: "v2.0.6", override: true},
      {:castore, git: "https://github.com/elixir-mint/castore.git", tag: "v1.0.10", override: true},
      {:finch, git: "https://github.com/sneako/finch.git", tag: "v0.19.0", override: true},
      {:mint, git: "https://github.com/elixir-mint/mint.git", tag: "v1.6.2", override: true},
      {:nimble_options, git: "https://github.com/dashbitco/nimble_options.git", tag: "v1.1.1", override: true},
      {:nimble_pool, git: "https://github.com/dashbitco/nimble_pool.git", tag: "v1.1.0", override: true},
      {:telemetry_metrics, git: "https://github.com/beam-telemetry/telemetry_metrics.git", tag: "v1.0.0", override: true},
      {:file_system, git: "https://github.com/falood/file_system.git", tag: "v1.0.1", override: true},
      {:websock_adapter, git: "https://github.com/phoenixframework/websock_adapter.git", tag: "0.5.7", override: true}
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
