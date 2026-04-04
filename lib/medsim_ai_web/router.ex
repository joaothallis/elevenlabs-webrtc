defmodule MedsimAiWeb.Router do
  use MedsimAiWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MedsimAiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", MedsimAiWeb do
    pipe_through :browser

    live "/", PatientLive, :index
  end
end
