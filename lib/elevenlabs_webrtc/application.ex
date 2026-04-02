defmodule ElevenlabsWebrtc.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElevenlabsWebrtcWeb.Telemetry,
      {Phoenix.PubSub, name: ElevenlabsWebrtc.PubSub},
      ElevenlabsWebrtcWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ElevenlabsWebrtc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ElevenlabsWebrtcWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
