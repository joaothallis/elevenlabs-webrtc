import Config

config :medsim_ai, MedsimAiWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: MedsimAiWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: MedsimAi.PubSub,
  live_view: [signing_salt: "medsim_ai_salt"]

config :esbuild,
  version: "0.21.5",
  medsim_ai: [
    args: ~w(js/app.js --bundle --target=es2020 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
