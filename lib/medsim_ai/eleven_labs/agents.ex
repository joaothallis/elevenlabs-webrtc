defmodule MedsimAi.ElevenLabs.Agents do
  @moduledoc """
  Agent CRUD operations against the ElevenLabs ConvAI API.
  """

  alias MedsimAi.ElevenLabs.Client

  def list do
    case Client.get("/convai/agents") do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def get(agent_id) do
    case Client.get("/convai/agents/#{agent_id}") do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def create(params) do
    agent_config = build_agent_config(params)

    case Client.post("/convai/agents/create", agent_config) do
      {:ok, %{status: status, body: body}} when status in [200, 201] -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def update(agent_id, params) do
    update_data = build_update_data(params)

    case Client.patch("/convai/agents/#{agent_id}", update_data) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  def delete(agent_id) do
    case Client.delete("/convai/agents/#{agent_id}") do
      {:ok, %{status: status}} when status in [200, 204] -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_agent_config(params) do
    config = %{
      "name" => params["name"] || "Custom Agent",
      "conversation_config" => %{
        "agent" => %{
          "prompt" => %{
            "prompt" => params["prompt"],
            "llm" => "gemini-2.0-flash-001",
            "temperature" => 0.7
          },
          "first_message" => params["first_message"] || "",
          "language" => params["language"] || "en"
        },
        "tts" => %{
          "voice_id" => params["voice_id"] || "cjVigY5qzO86Huf0OWal",
          "model_id" => "eleven_turbo_v2"
        }
      }
    }

    if workflow = params["workflow"],
      do: Map.put(config, "workflow", workflow),
      else: config
  end

  defp build_update_data(params) do
    data = %{}

    data =
      if params["name"],
        do: Map.put(data, "name", params["name"]),
        else: data

    has_conversation_updates =
      params["prompt"] || params["first_message"] || params["voice_id"] || params["language"]

    data =
      if has_conversation_updates do
        conv_config = %{}

        agent_config =
          %{}
          |> maybe_put_prompt(params["prompt"])
          |> maybe_put("first_message", params["first_message"])
          |> maybe_put("language", params["language"])

        conv_config =
          if map_size(agent_config) > 0,
            do: Map.put(conv_config, "agent", agent_config),
            else: conv_config

        conv_config =
          if params["voice_id"],
            do: Map.put(conv_config, "tts", %{"voice_id" => params["voice_id"]}),
            else: conv_config

        if map_size(conv_config) > 0,
          do: Map.put(data, "conversation_config", conv_config),
          else: data
      else
        data
      end

    if workflow = params["workflow"],
      do: Map.put(data, "workflow", workflow),
      else: data
  end

  defp maybe_put_prompt(map, nil), do: map
  defp maybe_put_prompt(map, prompt), do: Map.put(map, "prompt", %{"prompt" => prompt})

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
