defmodule MedsimAi.ElevenLabs.Client do
  @moduledoc """
  Base HTTP client for ElevenLabs API.
  """

  @base_url "https://api.elevenlabs.io/v1"

  def api_key do
    Application.get_env(:medsim_ai, :eleven_api_key)
  end

  def default_agent_id do
    Application.get_env(:medsim_ai, :eleven_agent_id)
  end

  def get(path, opts \\ []) do
    url = @base_url <> path
    params = Keyword.get(opts, :params, %{})

    Req.get(url,
      headers: headers(),
      params: params
    )
  end

  def post(path, body \\ %{}) do
    url = @base_url <> path

    Req.post(url,
      headers: headers(),
      json: body
    )
  end

  def patch(path, body) do
    url = @base_url <> path

    Req.patch(url,
      headers: headers(),
      json: body
    )
  end

  def delete(path) do
    url = @base_url <> path

    Req.delete(url,
      headers: headers()
    )
  end

  defp headers do
    [
      {"xi-api-key", api_key()},
      {"content-type", "application/json"}
    ]
  end
end
