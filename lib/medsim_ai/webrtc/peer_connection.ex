defmodule MedsimAi.WebRTC.PeerConnection do
  @moduledoc """
  Wrapper around ExWebRTC.PeerConnection.

  When ex_webrtc is available, delegates to ExWebRTC.PeerConnection.
  When not available, provides stub implementations for development.

  To enable full WebRTC support, add `{:ex_webrtc, "~> 0.16.0"}` to mix.exs
  and set `config :medsim_ai, webrtc_enabled: true` in config.
  """

  @webrtc_available Code.ensure_loaded?(ExWebRTC.PeerConnection)

  if @webrtc_available do
    defdelegate start_link(opts), to: ExWebRTC.PeerConnection
    defdelegate add_transceiver(pc, kind, opts \\ []), to: ExWebRTC.PeerConnection
    defdelegate create_offer(pc), to: ExWebRTC.PeerConnection
    defdelegate create_answer(pc), to: ExWebRTC.PeerConnection
    defdelegate set_local_description(pc, desc), to: ExWebRTC.PeerConnection
    defdelegate set_remote_description(pc, desc), to: ExWebRTC.PeerConnection
    defdelegate add_ice_candidate(pc, candidate), to: ExWebRTC.PeerConnection
    defdelegate send_rtp(pc, track_id, packet), to: ExWebRTC.PeerConnection
    defdelegate close(pc), to: ExWebRTC.PeerConnection
  else
    require Logger

    def start_link(_opts) do
      Logger.warning("ex_webrtc not available - WebRTC features disabled. Add {:ex_webrtc, \"~> 0.16.0\"} to mix.exs")
      {:error, :webrtc_not_available}
    end

    def add_transceiver(_, _, _ \\ []), do: {:error, :webrtc_not_available}
    def create_offer(_), do: {:error, :webrtc_not_available}
    def create_answer(_), do: {:error, :webrtc_not_available}
    def set_local_description(_, _), do: {:error, :webrtc_not_available}
    def set_remote_description(_, _), do: {:error, :webrtc_not_available}
    def add_ice_candidate(_, _), do: {:error, :webrtc_not_available}
    def send_rtp(_, _, _), do: {:error, :webrtc_not_available}
    def close(_), do: :ok
  end
end
