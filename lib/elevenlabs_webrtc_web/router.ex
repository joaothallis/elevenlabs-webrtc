defmodule ElevenlabsWebrtcWeb.Router do
  use ElevenlabsWebrtcWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElevenlabsWebrtcWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ElevenlabsWebrtcWeb do
    pipe_through :browser

    live "/", PatientLive, :index
  end

  scope "/api", ElevenlabsWebrtcWeb do
    pipe_through :api

    get "/config", ApiController, :config
    get "/voices", ApiController, :voices
    get "/voice-library", ApiController, :voice_library
    post "/voice-library/add", ApiController, :add_voice
    get "/agents", ApiController, :list_agents
    post "/agents", ApiController, :create_agent
    get "/agents/:agent_id", ApiController, :get_agent
    patch "/agents/:agent_id", ApiController, :update_agent
    delete "/agents/:agent_id", ApiController, :delete_agent
    post "/webrtc-token", ApiController, :webrtc_token
    post "/signed-url", ApiController, :signed_url
  end
end
