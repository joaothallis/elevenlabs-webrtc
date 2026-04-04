defmodule MedsimAi.ElevenLabs.Conversation do
  @moduledoc """
  Conversation token and signed URL retrieval from ElevenLabs API.
  """

  alias MedsimAi.ElevenLabs.Client

  def get_token(agent_id) do
    case Client.get("/convai/conversation/token", params: %{"agent_id" => agent_id}) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_signed_url(agent_id) do
    case Client.get("/convai/conversation/get-signed-url", params: %{"agent_id" => agent_id}) do
      {:ok, %{status: 200, body: %{"signed_url" => url}}} -> {:ok, url}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
