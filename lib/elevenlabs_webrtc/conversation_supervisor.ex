defmodule ElevenlabsWebrtc.ConversationSupervisor do
  @moduledoc """
  DynamicSupervisor for managing conversation processes.

  Each conversation consists of:
  - A PeerServer (ex_webrtc PeerConnection with the browser)
  - An ElevenlabsWs (WebSocket connection to ElevenLabs)
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_peer_server(opts) do
    DynamicSupervisor.start_child(__MODULE__, {ElevenlabsWebrtc.PeerServer, opts})
  end

  def start_elevenlabs_ws(opts) do
    DynamicSupervisor.start_child(__MODULE__, %{
      id: ElevenlabsWebrtc.ElevenlabsWs,
      start: {ElevenlabsWebrtc.ElevenlabsWs, :start_link, [opts]},
      restart: :temporary
    })
  end

  def stop_child(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end
end
