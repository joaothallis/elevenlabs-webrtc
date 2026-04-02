defmodule ElevenlabsWebrtc.PeerServer do
  @moduledoc """
  GenServer wrapping an ExWebRTC.PeerConnection.

  Manages the server-side WebRTC peer connection with the browser:
  - Handles SDP offer/answer signaling
  - Exchanges ICE candidates
  - Receives audio RTP packets from the browser
  - Sends audio RTP packets back to the browser

  Audio received from the browser is forwarded to the ElevenlabsWs process,
  and audio received from ElevenLabs is sent back to the browser.
  """
  use GenServer
  require Logger

  alias ExWebRTC.{PeerConnection, SessionDescription, ICECandidate}

  defstruct [
    :pc,
    :live_view_pid,
    :bridge_pid,
    :incoming_track_id,
    :outgoing_track_id,
    rtp_seq: 0,
    rtp_ts: 0
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def receive_offer(pid, sdp) do
    GenServer.call(pid, {:receive_offer, sdp})
  end

  def add_ice_candidate(pid, candidate) do
    GenServer.cast(pid, {:add_ice_candidate, candidate})
  end

  def set_bridge(pid, bridge_pid) do
    GenServer.cast(pid, {:set_bridge, bridge_pid})
  end

  def send_audio_to_browser(pid, audio_data) do
    GenServer.cast(pid, {:send_audio, audio_data})
  end

  @impl true
  def init(opts) do
    {:ok, pc} =
      PeerConnection.start_link(
        ice_servers: [%{urls: "stun:stun.l.google.com:19302"}]
      )

    # Add bidirectional audio transceiver
    {:ok, _transceiver} = PeerConnection.add_transceiver(pc, :audio, direction: :sendrecv)

    state = %__MODULE__{
      pc: pc,
      live_view_pid: opts[:live_view_pid]
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:receive_offer, offer_sdp}, _from, state) do
    offer = %SessionDescription{type: :offer, sdp: offer_sdp}

    with :ok <- PeerConnection.set_remote_description(state.pc, offer),
         {:ok, answer} <- PeerConnection.create_answer(state.pc),
         :ok <- PeerConnection.set_local_description(state.pc, answer) do
      {:reply, {:ok, answer.sdp}, state}
    else
      error ->
        Logger.error("Failed to handle SDP offer: #{inspect(error)}")
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_cast({:add_ice_candidate, candidate_data}, state) do
    candidate = %ICECandidate{
      candidate: candidate_data["candidate"],
      sdp_mid: candidate_data["sdpMid"],
      sdp_m_line_index: candidate_data["sdpMLineIndex"]
    }

    case PeerConnection.add_ice_candidate(state.pc, candidate) do
      :ok -> :ok
      error -> Logger.warning("Failed to add ICE candidate: #{inspect(error)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_bridge, bridge_pid}, state) do
    {:noreply, %{state | bridge_pid: bridge_pid}}
  end

  @impl true
  def handle_cast({:send_audio, audio_data}, state) when is_binary(audio_data) do
    if state.outgoing_track_id do
      # Create an RTP packet with the audio payload.
      # For audio from ElevenLabs (PCM), this needs codec conversion to Opus
      # before sending. See ElevenlabsWebrtc.AudioCodec for the conversion pipeline.
      # ExWebRTC.PeerConnection.send_rtp/3 auto-sets payload_type, SSRC,
      # and RTP extensions, so we only need to provide the core fields.
      packet = %ExRTP.Packet{
        payload_type: 111,
        sequence_number: rem(state.rtp_seq, 65_536),
        timestamp: rem(state.rtp_ts, 4_294_967_296),
        ssrc: 0,
        payload: audio_data
      }

      PeerConnection.send_rtp(state.pc, state.outgoing_track_id, packet)

      # Opus at 48kHz with 20ms frames = 960 samples per frame
      {:noreply, %{state | rtp_seq: state.rtp_seq + 1, rtp_ts: state.rtp_ts + 960}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:send_audio, _}, state), do: {:noreply, state}

  # --- ex_webrtc messages ---

  @impl true
  def handle_info({:ex_webrtc, _pc, {:ice_candidate, candidate}}, state) do
    # Forward ICE candidate to browser via LiveView
    send(state.live_view_pid, {:ice_candidate, serialize_ice_candidate(candidate)})
    {:noreply, state}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, {:track, track}}, state) do
    Logger.info("WebRTC track added: #{track.kind} (id: #{track.id})")

    state =
      case track.kind do
        :audio -> %{state | incoming_track_id: track.id}
        _ -> state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, {:rtp, _track_id, nil, packet}}, state) do
    # Audio RTP from browser - extract Opus payload and forward to ElevenLabs bridge.
    # The packet.payload contains the Opus-encoded audio frame.
    # The bridge will handle conversion to PCM for the ElevenLabs WebSocket.
    if state.bridge_pid do
      send(state.bridge_pid, {:audio_from_browser, packet.payload})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, {:connection_state_change, new_state}}, state) do
    Logger.info("WebRTC connection state: #{new_state}")
    send(state.live_view_pid, {:webrtc_connection_state, new_state})
    {:noreply, state}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, {:signaling_state_change, new_state}}, state) do
    Logger.debug("WebRTC signaling state: #{new_state}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, {:ice_gathering_state_change, new_state}}, state) do
    Logger.debug("ICE gathering state: #{new_state}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, {:negotiation_needed}}, state) do
    Logger.debug("WebRTC negotiation needed")
    {:noreply, state}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, msg}, state) do
    Logger.debug("Unhandled ex_webrtc message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Resolve the outgoing track ID from transceivers once we have the answer set
  @impl true
  def handle_info(:resolve_tracks, state) do
    case PeerConnection.get_transceivers(state.pc) do
      transceivers when is_list(transceivers) ->
        audio_tr = Enum.find(transceivers, fn tr -> tr.kind == :audio end)

        outgoing_id =
          if audio_tr && audio_tr.sender && audio_tr.sender.track do
            audio_tr.sender.track.id
          end

        {:noreply, %{state | outgoing_track_id: outgoing_id}}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    if state.pc, do: PeerConnection.close(state.pc)
    :ok
  end

  defp serialize_ice_candidate(candidate) do
    %{
      "candidate" => candidate.candidate,
      "sdpMid" => candidate.sdp_mid,
      "sdpMLineIndex" => candidate.sdp_m_line_index
    }
  end
end
