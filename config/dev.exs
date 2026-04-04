import Config

config :medsim_ai, MedsimAiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_that_is_at_least_64_bytes_long_for_phoenix_framework_dev_mode_only",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:medsim_ai, ~w(--sourcemap=inline --watch)]}
  ]

config :medsim_ai, MedsimAiWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/medsim_ai_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
