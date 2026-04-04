defmodule MedsimAiWeb.Layouts do
  use MedsimAiWeb, :html

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <title>MedSimAI Patient Builder</title>
        <link phx-track-static rel="stylesheet" href={"/assets/app.css"} />
        <script defer phx-track-static type="text/javascript" src={"/assets/app.js"}></script>
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  def render("app.html", assigns) do
    ~H"""
    <main>
      <.flash_group flash={@flash} />
      <%= @inner_content %>
    </main>
    """
  end

  defp flash_group(assigns) do
    ~H"""
    <div :if={Phoenix.Flash.get(@flash, :info)} class="flash flash-info" role="alert">
      <%= Phoenix.Flash.get(@flash, :info) %>
    </div>
    <div :if={Phoenix.Flash.get(@flash, :error)} class="flash flash-error" role="alert">
      <%= Phoenix.Flash.get(@flash, :error) %>
    </div>
    """
  end
end
