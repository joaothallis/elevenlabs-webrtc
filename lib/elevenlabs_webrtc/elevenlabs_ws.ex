defmodule ElevenlabsWebrtc.ElevenlabsWs do
  @moduledoc """
  WebSocket client for ElevenLabs Conversational AI.

  Connects to ElevenLabs via their WebSocket API and bridges audio
  between the server-side ex_webrtc PeerConnection and the ElevenLabs AI agent.

  Protocol:
  - Sends: `{"user_audio_chunk": "<base64 audio>"}` for user audio
  - Receives: audio events, agent responses, user transcripts, interruptions
  """
  use WebSockex
  require Logger

  alias ElevenlabsWebrtc.AudioCodec

  defstruct [:peer_server_pid, :live_view_pid]

  def start_link(opts) do
    url = opts[:ws_url]

    state = %__MODULE__{
      peer_server_pid: opts[:peer_server_pid],
      live_view_pid: opts[:live_view_pid]
    }

    WebSockex.start_link(url, __MODULE__, state)
  end

  @doc """
  Send an audio chunk to ElevenLabs.
  The audio should be base64-encoded PCM 16-bit 16kHz mono.
  """
  def send_audio(pid, audio_data) when is_binary(audio_data) do
    # Convert from Opus to PCM for ElevenLabs
    pcm_data = AudioCodec.opus_to_pcm(audio_data)
    encoded = Base.encode64(pcm_data)
    msg = Jason.encode!(%{"user_audio_chunk" => encoded})
    WebSockex.send_frame(pid, {:text, msg})
  end

  # --- WebSockex Callbacks ---

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("Connected to ElevenLabs WebSocket")
    send(state.live_view_pid, {:elevenlabs_event, :connected})
    {:ok, state}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, parsed} ->
        handle_elevenlabs_message(parsed, state)

      {:error, _} ->
        Logger.warning("Failed to parse ElevenLabs message: #{inspect(msg)}")
    end

    {:ok, state}
  end

  @impl true
  def handle_frame({:binary, _data}, state) do
    {:ok, state}
  end

  @impl true
  def handle_disconnect(%{reason: reason}, state) do
    Logger.info("ElevenLabs WebSocket disconnected: #{inspect(reason)}")
    send(state.live_view_pid, {:elevenlabs_event, :disconnected})
    {:ok, state}
  end

  @impl true
  def handle_info({:audio_from_browser, opus_data}, state) do
    # Forward browser audio to ElevenLabs
    pcm_data = AudioCodec.opus_to_pcm(opus_data)
    encoded = Base.encode64(pcm_data)
    msg = Jason.encode!(%{"user_audio_chunk" => encoded})
    {:reply, {:text, msg}, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:ok, state}
  end

  # --- ElevenLabs Message Handlers ---

  defp handle_elevenlabs_message(
         %{"type" => "conversation_initiation_metadata"} = msg,
         state
       ) do
    conversation_id = get_in(msg, ["conversation_initiation_metadata_event", "conversation_id"])
    Logger.info("ElevenLabs conversation initiated: #{conversation_id}")
    send(state.live_view_pid, {:elevenlabs_event, {:initiated, conversation_id}})
  end

  defp handle_elevenlabs_message(%{"type" => "audio", "audio_event" => event}, state) do
    case Base.decode64(event["audio_base_64"] || "") do
      {:ok, pcm_data} ->
        # Convert PCM from ElevenLabs to Opus for WebRTC
        opus_data = AudioCodec.pcm_to_opus(pcm_data)
        ElevenlabsWebrtc.PeerServer.send_audio_to_browser(state.peer_server_pid, opus_data)

      :error ->
        Logger.warning("Failed to decode audio from ElevenLabs")
    end
  end

  defp handle_elevenlabs_message(
         %{"type" => "agent_response", "agent_response_event" => event},
         state
       ) do
    text = event["agent_response"] || ""
    send(state.live_view_pid, {:elevenlabs_event, {:agent_response, text}})
  end

  defp handle_elevenlabs_message(
         %{"type" => "user_transcript", "user_transcription_event" => event},
         state
       ) do
    text = event["user_transcript"] || ""
    send(state.live_view_pid, {:elevenlabs_event, {:user_transcript, text}})
  end

  defp handle_elevenlabs_message(%{"type" => "interruption"}, state) do
    send(state.live_view_pid, {:elevenlabs_event, :interruption})
  end

  defp handle_elevenlabs_message(%{"type" => "ping", "ping_event" => event}, _state) do
    # Respond with pong - will be sent in next frame
    _event_id = event["event_id"]
    Logger.debug("ElevenLabs ping received")
  end

  defp handle_elevenlabs_message(%{"type" => type}, _state) do
    Logger.debug("Unhandled ElevenLabs message type: #{type}")
  end

  defp handle_elevenlabs_message(msg, _state) do
    Logger.debug("Unknown ElevenLabs message: #{inspect(msg)}")
  end
end
