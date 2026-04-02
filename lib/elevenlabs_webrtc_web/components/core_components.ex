defmodule ElevenlabsWebrtcWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.
  """
  use Phoenix.Component

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div class="flash-group">
      <%= if info = Phoenix.Flash.get(@flash, :info) do %>
        <div class="alert alert-info" role="alert" phx-click="lv:clear-flash" phx-value-key="info">
          <%= info %>
        </div>
      <% end %>
      <%= if error = Phoenix.Flash.get(@flash, :error) do %>
        <div
          class="alert alert-error"
          role="alert"
          phx-click="lv:clear-flash"
          phx-value-key="error"
        >
          <%= error %>
        </div>
      <% end %>
    </div>
    """
  end
end
