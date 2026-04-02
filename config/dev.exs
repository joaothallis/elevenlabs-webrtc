import Config

config :elevenlabs_webrtc, ElevenlabsWebrtcWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_that_is_at_least_64_bytes_long_for_development_only_please_change",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:elevenlabs_webrtc, ~w(--sourcemap=inline --watch)]}
  ]

config :elevenlabs_webrtc, ElevenlabsWebrtcWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/elevenlabs_webrtc_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
