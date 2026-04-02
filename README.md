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
| `lib/elevenlabs_webrtc/elevenlabs_client.ex` | ElevenLabs API client (agents, voices, WebRTC tokens) |
| `lib/elevenlabs_webrtc/workflow.ex` | Workflow builder for adaptive patient pivots |
| `lib/elevenlabs_webrtc_web/` | Phoenix web layer |
| `lib/elevenlabs_webrtc_web/live/patient_live.ex` | Main LiveView with all UI logic |
| `lib/elevenlabs_webrtc_web/controllers/api_controller.ex` | JSON API endpoints (token proxy, agents, voices) |
| `assets/js/hooks/conversation.js` | LiveView JS hook for WebRTC conversation |
| `assets/js/hooks/voice_preview.js` | LiveView JS hook for voice audio preview |
| `assets/css/app.css` | Application styles |
| `config/runtime.exs` | Runtime configuration (env vars) |

## Architecture

The application follows the standard Phoenix LiveView pattern:

1. **LiveView** handles all UI state and user interactions server-side
2. **JS Hooks** manage browser-side WebRTC audio (microphone capture, playback)
3. **API Controller** proxies ElevenLabs API calls to keep the API key server-side
4. **ElevenlabsClient** module encapsulates all HTTP communication with ElevenLabs

The WebRTC conversation flow:
1. User selects an agent and clicks "Start Conversation"
2. LiveView JS hook fetches a WebRTC token from `/api/webrtc-token`
3. The ElevenLabs client SDK establishes a WebRTC connection
4. Audio streams bidirectionally between browser and ElevenLabs agent
5. Conversation events are pushed back to LiveView for logging

## Notes

- All sensitive values (API keys) stay on the server
- Only short-lived JWT tokens are sent to the browser
- The ElevenLabs client SDK is loaded from CDN in the browser for WebRTC management
