defmodule MedsimAi.ElevenLabs.Voices do
  @moduledoc """
  Voice management operations against the ElevenLabs API.
  """

  alias MedsimAi.ElevenLabs.Client

  def list do
    case Client.get("/voices") do
      {:ok, %{status: 200, body: %{"voices" => voices}}} ->
        simplified =
          Enum.map(voices, fn v ->
            %{
              "voice_id" => v["voice_id"],
              "name" => v["name"],
              "category" => v["category"],
              "labels" => v["labels"],
              "preview_url" => v["preview_url"]
            }
          end)

        {:ok, simplified}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def search_library(params \\ %{}) do
    query_params =
      %{"page_size" => params["page_size"] || "30"}
      |> maybe_put("search", params["search"])
      |> maybe_put("language", params["language"])
      |> maybe_put("gender", params["gender"])

    case Client.get("/shared-voices", params: query_params) do
      {:ok, %{status: 200, body: body}} ->
        voices =
          (body["voices"] || [])
          |> Enum.map(fn v ->
            %{
              "voice_id" => v["voice_id"],
              "public_owner_id" => v["public_owner_id"],
              "name" => v["name"],
              "category" => v["category"],
              "labels" => v["labels"] || %{},
              "description" => v["description"],
              "preview_url" => v["preview_url"],
              "usage_character_count_1y" => v["usage_character_count_1y"]
            }
          end)

        {:ok, %{"voices" => voices, "has_more" => body["has_more"]}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def add_from_library(public_owner_id, voice_id, name \\ nil) do
    body = if name, do: %{"name" => name}, else: %{}

    case Client.post("/voices/add/#{public_owner_id}/#{voice_id}", body) do
      {:ok, %{status: status, body: body}} when status in [200, 201] -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
