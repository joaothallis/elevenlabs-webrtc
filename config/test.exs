import Config

config :medsim_ai, MedsimAiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_at_least_64_bytes_long_for_phoenix_framework_test_mode",
  server: false

config :logger, level: :warning
