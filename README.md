# MedSimAI Patient Builder

An Elixir/Phoenix LiveView application for creating interactive standardized patient simulations using ElevenLabs ConvAI and WebRTC. Medical students can have realistic conversations with AI-powered patients that respond adaptively based on the student's clinical approach.

Built with:
- **Elixir** + **Phoenix** + **LiveView** for the full-stack web application
- **ex_webrtc** for WebRTC infrastructure
- **ElevenLabs ConvAI API** for AI-powered conversational agents
- **Req** for HTTP client

## Prerequisites

- Elixir 1.14+ and Erlang/OTP 25+
- An ElevenLabs API key with ConvAI access

## Getting Started

1. Copy `.env.example` to `.env` and fill in your credentials:

   ```bash
   cp .env.example .env
   # Set ELEVEN_API_KEY and optionally ELEVEN_AGENT_ID
   ```

2. Install dependencies:

   ```bash
   mix setup
   ```

3. Start the Phoenix server:

   ```bash
   source .env && mix phx.server
   ```

4. Visit [http://localhost:4000](http://localhost:4000)

## Features

- **Simple Patient**: Quick agent creation with name, history, voice, and language
- **Adaptive Patient Designer**: Create patients with dynamic behavioral pivots that respond to student approach (empathy, clinical coldness, etc.)
- **Voice Library**: Browse and add voices from the ElevenLabs shared voice library
- **Real-time Conversation**: WebRTC-powered low-latency audio conversations with AI patients
- **Agent Management**: Create, edit, delete, and select agents for conversation

## Project Structure

| Path | Purpose |
| --- | --- |
| `lib/elevenlabs_webrtc/` | Core business logic |
| `lib/elevenlabs_webrtc/elevenlabs_client.ex` | ElevenLabs API client (agents, voices, tokens) |
| `lib/elevenlabs_webrtc/peer_server.ex` | GenServer wrapping ex_webrtc PeerConnection |
| `lib/elevenlabs_webrtc/elevenlabs_ws.ex` | WebSocket client for ElevenLabs conversation |
| `lib/elevenlabs_webrtc/audio_codec.ex` | Audio codec bridge (Opus <-> PCM conversion) |
| `lib/elevenlabs_webrtc/conversation_supervisor.ex` | DynamicSupervisor for conversation processes |
| `lib/elevenlabs_webrtc/workflow.ex` | Workflow builder for adaptive patient pivots |
| `lib/elevenlabs_webrtc_web/` | Phoenix web layer |
| `lib/elevenlabs_webrtc_web/live/patient_live.ex` | Main LiveView with UI + WebRTC signaling |
| `lib/elevenlabs_webrtc_web/controllers/api_controller.ex` | JSON API endpoints (agents, voices) |
| `assets/js/hooks/conversation.js` | LiveView JS hook for native WebRTC PeerConnection |
| `assets/js/hooks/voice_preview.js` | LiveView JS hook for voice audio preview |
| `assets/css/app.css` | Application styles |
| `config/runtime.exs` | Runtime configuration (env vars) |

## Architecture

```
Browser                    Phoenix Server                ElevenLabs
  |                            |                            |
  |  WebRTC (ex_webrtc)        |   WebSocket (websockex)    |
  |  SDP + ICE via LiveView    |                            |
  |<=========================>|<=========================>|
  |  Opus audio (RTP)          |  PCM audio (base64 JSON)   |
  |  Mic capture + playback    |  Audio codec conversion    |
  |                            |  PeerServer + ElevenlabsWs |
```

The WebRTC connection is managed entirely by **ex_webrtc** on the server:

1. **User clicks "Start Conversation"** - LiveView starts a `PeerServer` (ex_webrtc `PeerConnection`)
2. **SDP Signaling via LiveView** - Browser creates offer, sends via LiveView WebSocket to `PeerServer`, which creates answer using ex_webrtc
3. **ICE Candidate Exchange** - Candidates flow through LiveView between browser and ex_webrtc
4. **WebRTC Connected** - Browser sends microphone audio via RTP to Phoenix server
5. **Audio Bridge** - `PeerServer` extracts audio from RTP, `ElevenlabsWs` forwards to ElevenLabs via WebSocket
6. **Agent Response** - ElevenLabs sends audio back via WebSocket, `PeerServer` sends to browser via RTP
7. **Transcripts** - Text events (agent responses, user transcripts) flow through LiveView to the UI

### Audio Codec Conversion

The browser sends **Opus** audio over WebRTC, while ElevenLabs expects **PCM 16-bit 16kHz mono** over WebSocket. The `AudioCodec` module handles this conversion. For production, install [`xav`](https://github.com/elixir-webrtc/xav) (FFmpeg wrapper) for proper Opus encode/decode.

## Notes

- All sensitive values (API keys) stay on the server
- WebRTC connection terminates at Phoenix, not at ElevenLabs directly
- Audio is bridged server-side: Browser <-> ex_webrtc <-> ElevenLabs WebSocket
- No ElevenLabs SDK in the browser - uses native `RTCPeerConnection` API
