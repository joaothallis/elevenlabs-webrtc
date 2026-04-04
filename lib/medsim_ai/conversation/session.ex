defmodule MedsimAi.Conversation.Session do
  @moduledoc """
  GenServer that bridges audio between ex_webrtc and ElevenLabs WebSocket API.

  Receives RTP audio packets from ex_webrtc, converts to PCM, base64-encodes,
  and sends to ElevenLabs. Receives audio from ElevenLabs, decodes, and sends
  back as RTP packets.
  """
  use GenServer

  require Logger

  defstruct [
    :signed_url,
    :caller,
    :ws_pid,
    :conversation_id,
    :last_interrupt_id,
    :audio_format,
    seq_num: 0,
    timestamp: 0
  ]

  # Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def send_audio(pid, rtp_packet) do
    GenServer.cast(pid, {:send_audio, rtp_packet})
  end

  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # GenServer Callbacks

  @impl true
  def init(%{signed_url: signed_url, caller: caller}) do
    state = %__MODULE__{
      signed_url: signed_url,
      caller: caller
    }

    # Connect to ElevenLabs WebSocket
    case WebSockex.start_link(signed_url, __MODULE__.WSClient, %{session: self()}) do
      {:ok, ws_pid} ->
        {:ok, %{state | ws_pid: ws_pid}}

      {:error, reason} ->
        send(caller, {:conversation_error, reason})
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:send_audio, rtp_packet}, state) do
    # Extract audio payload from RTP packet
    # RTP packets from the browser contain Opus-encoded audio
    # ElevenLabs expects PCM 16kHz 16-bit mono base64
    # For now, we send the raw audio data - in production you'd transcode Opus->PCM
    audio_payload = extract_rtp_payload(rtp_packet)

    if state.ws_pid && byte_size(audio_payload) > 0 do
      # Base64 encode and send as user_audio_chunk
      encoded = Base.encode64(audio_payload)
      msg = Jason.encode!(%{"user_audio_chunk" => encoded})

      WebSockex.send_frame(state.ws_pid, {:text, msg})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:ws_message, message}, state) do
    state = handle_ws_message(message, state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:ws_closed, _reason}, state) do
    send(state.caller, {:conversation_closed})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.ws_pid do
      try do
        WebSockex.send_frame(state.ws_pid, :close)
      catch
        _, _ -> :ok
      end
    end

    :ok
  end

  # Private helpers

  defp handle_ws_message(raw_message, state) do
    case Jason.decode(raw_message) do
      {:ok, %{"type" => "conversation_initiation_metadata"} = msg} ->
        conv_id =
          get_in(msg, ["conversation_initiation_metadata_event", "conversation_id"]) || "unknown"

        send(state.caller, {:conversation_event, "conversation_initiation_metadata", conv_id})
        %{state | conversation_id: conv_id}

      {:ok, %{"type" => "audio", "audio_event" => event}} ->
        event_id = event["event_id"]

        # Skip audio from before the last interruption
        if state.last_interrupt_id == nil || event_id > state.last_interrupt_id do
          audio_base64 = event["audio_base_64"]

          case Base.decode64(audio_base64) do
            {:ok, pcm_data} ->
              # Build an RTP-like packet to send via ex_webrtc
              # In a production system, you'd encode PCM->Opus and build proper RTP
              rtp_packet = build_rtp_packet(pcm_data, state)
              send(state.caller, {:conversation_audio, rtp_packet})

              %{state |
                seq_num: rem(state.seq_num + 1, 65536),
                timestamp: state.timestamp + 960
              }

            :error ->
              Logger.warning("Failed to decode audio base64")
              state
          end
        else
          state
        end

      {:ok, %{"type" => "user_transcript", "user_transcription_event" => event}} ->
        send(state.caller, {:conversation_event, "user_transcript", event["user_transcript"]})
        state

      {:ok, %{"type" => "agent_response", "agent_response_event" => event}} ->
        send(state.caller, {:conversation_event, "agent_response", event["agent_response"]})
        state

      {:ok, %{"type" => "interruption"}} ->
        send(state.caller, {:conversation_event, "interruption", ""})
        %{state | last_interrupt_id: state.seq_num}

      {:ok, %{"type" => type}} ->
        Logger.debug("ElevenLabs WS event: #{type}")
        state

      {:error, _} ->
        Logger.warning("Failed to parse WS message")
        state
    end
  end

  defp extract_rtp_payload(packet) when is_binary(packet) do
    # Simple RTP payload extraction
    # RTP header is at least 12 bytes
    case packet do
      <<_version::2, _padding::1, _extension::1, cc::4, _marker::1, _pt::7,
        _seq::16, _ts::32, _ssrc::32, rest::binary>> ->
        # Skip CSRC entries (4 bytes each)
        csrc_size = cc * 4
        case rest do
          <<_csrc::binary-size(csrc_size), payload::binary>> -> payload
          _ -> <<>>
        end

      _ ->
        packet
    end
  end

  defp build_rtp_packet(pcm_data, state) do
    # Build a simple RTP packet with PCM payload
    # Version 2, no padding, no extension, 0 CSRC
    # Payload type 96 (dynamic), marker 0
    <<2::2, 0::1, 0::1, 0::4, 0::1, 96::7,
      state.seq_num::16, state.timestamp::32, 1::32,
      pcm_data::binary>>
  end
end

defmodule MedsimAi.Conversation.Session.WSClient do
  @moduledoc """
  WebSockex client for ElevenLabs conversation WebSocket.
  """
  use WebSockex

  require Logger

  @impl true
  def handle_frame({:text, msg}, state) do
    send(state.session, {:ws_message, msg})
    {:ok, state}
  end

  @impl true
  def handle_frame({:binary, _msg}, state) do
    # ElevenLabs sends JSON text frames, not binary
    {:ok, state}
  end

  @impl true
  def handle_disconnect(%{reason: reason}, state) do
    send(state.session, {:ws_closed, reason})
    {:ok, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:ok, state}
  end
end
