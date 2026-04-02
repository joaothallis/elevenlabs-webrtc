import Config

config :elevenlabs_webrtc, ElevenlabsWebrtcWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :logger, level: :info
