defmodule ElevenlabsWebrtcWeb.ApiController do
  use ElevenlabsWebrtcWeb, :controller

  alias ElevenlabsWebrtc.ElevenlabsClient

  def config(conn, _params) do
    json(conn, ElevenlabsClient.config())
  end

  def voices(conn, _params) do
    with :ok <- check_api_key(),
         {:ok, voices} <- ElevenlabsClient.list_voices() do
      json(conn, %{voices: voices})
    else
      {:error, status, body} -> conn |> put_status(status) |> json(body)
    end
  end

  def voice_library(conn, params) do
    with :ok <- check_api_key(),
         {:ok, voices, has_more} <- ElevenlabsClient.search_voice_library(params) do
      json(conn, %{voices: voices, has_more: has_more})
    else
      {:error, status, body} -> conn |> put_status(status) |> json(body)
    end
  end

  def add_voice(conn, params) do
    with :ok <- check_api_key(),
         :ok <- validate_required(params, ["public_owner_id", "voice_id"]),
         {:ok, data} <-
           ElevenlabsClient.add_voice(
             params["public_owner_id"],
             params["voice_id"],
             params["name"]
           ) do
      json(conn, data)
    else
      {:error, status, body} -> conn |> put_status(status) |> json(body)
    end
  end

  def list_agents(conn, _params) do
    with :ok <- check_api_key(),
         {:ok, data} <- ElevenlabsClient.list_agents() do
      json(conn, data)
    else
      {:error, status, body} -> conn |> put_status(status) |> json(body)
    end
  end

  def get_agent(conn, %{"agent_id" => agent_id}) do
    with :ok <- check_api_key(),
         {:ok, data} <- ElevenlabsClient.get_agent(agent_id) do
      json(conn, data)
    else
      {:error, status, body} -> conn |> put_status(status) |> json(body)
    end
  end

  def create_agent(conn, params) do
    with :ok <- check_api_key(),
         {:ok, data} <- ElevenlabsClient.create_agent(params) do
      json(conn, data)
    else
      {:error, status, body} -> conn |> put_status(status) |> json(body)
    end
  end

  def update_agent(conn, %{"agent_id" => agent_id} = params) do
    with :ok <- check_api_key(),
         {:ok, data} <- ElevenlabsClient.update_agent(agent_id, params) do
      json(conn, data)
    else
      {:error, status, body} -> conn |> put_status(status) |> json(body)
    end
  end

  def delete_agent(conn, %{"agent_id" => agent_id}) do
    with :ok <- check_api_key(),
         {:ok, data} <- ElevenlabsClient.delete_agent(agent_id) do
      json(conn, data)
    else
      {:error, status, body} -> conn |> put_status(status) |> json(body)
    end
  end

  def webrtc_token(conn, params) do
    with :ok <- check_api_key(),
         {:ok, data} <- ElevenlabsClient.get_webrtc_token(params["agentId"]) do
      json(conn, data)
    else
      {:error, status, body} -> conn |> put_status(status) |> json(body)
    end
  end

  def signed_url(conn, _params) do
    with :ok <- check_api_key(),
         {:ok, data} <- ElevenlabsClient.get_signed_url() do
      json(conn, data)
    else
      {:error, status, body} -> conn |> put_status(status) |> json(body)
    end
  end

  defp check_api_key do
    if ElevenlabsClient.has_api_key?() do
      :ok
    else
      {:error, 500, %{error: "Server missing ElevenLabs API key"}}
    end
  end

  defp validate_required(params, keys) do
    missing = Enum.find(keys, fn k -> is_nil(params[k]) or params[k] == "" end)

    if missing do
      {:error, 400, %{error: "#{missing} is required"}}
    else
      :ok
    end
  end
end
