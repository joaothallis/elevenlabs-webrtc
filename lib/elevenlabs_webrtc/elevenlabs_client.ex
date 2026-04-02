defmodule ElevenlabsWebrtc.ElevenlabsClient do
  @moduledoc """
  HTTP client for the ElevenLabs ConvAI API.
  Proxies all requests to keep the API key server-side.
  """

  @base_url "https://api.elevenlabs.io/v1"

  defp api_key do
    Application.get_env(:elevenlabs_webrtc, :eleven_api_key)
  end

  defp default_agent_id do
    Application.get_env(:elevenlabs_webrtc, :eleven_agent_id)
  end

  defp headers do
    [{"xi-api-key", api_key()}, {"content-type", "application/json"}]
  end

  def has_api_key?, do: api_key() != nil and api_key() != ""

  def config do
    %{
      agent_id: default_agent_id(),
      has_api_key: has_api_key?()
    }
  end

  # Voices

  def list_voices do
    case Req.get("#{@base_url}/voices", headers: headers()) do
      {:ok, %{status: 200, body: body}} ->
        voices =
          (body["voices"] || [])
          |> Enum.map(fn v ->
            %{
              voice_id: v["voice_id"],
              name: v["name"],
              category: v["category"],
              labels: v["labels"],
              preview_url: v["preview_url"]
            }
          end)

        {:ok, voices}

      {:ok, %{status: status, body: body}} ->
        {:error, status, body}

      {:error, reason} ->
        {:error, 500, %{"error" => inspect(reason)}}
    end
  end

  def search_voice_library(params) do
    url = "#{@base_url}/shared-voices"

    query =
      [
        {"page_size", Map.get(params, "page_size", "30")},
        {"search", Map.get(params, "search")},
        {"language", Map.get(params, "language")},
        {"gender", Map.get(params, "gender")},
        {"age", Map.get(params, "age")},
        {"category", Map.get(params, "category")}
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)

    case Req.get(url, headers: headers(), params: query) do
      {:ok, %{status: 200, body: body}} ->
        voices =
          (body["voices"] || [])
          |> Enum.map(fn v ->
            %{
              voice_id: v["voice_id"],
              public_owner_id: v["public_owner_id"],
              name: v["name"],
              category: v["category"],
              labels: v["labels"] || %{},
              description: v["description"],
              preview_url: v["preview_url"],
              usage_character_count_1y: v["usage_character_count_1y"]
            }
          end)

        {:ok, voices, body["has_more"]}

      {:ok, %{status: status, body: body}} ->
        {:error, status, body}

      {:error, reason} ->
        {:error, 500, %{"error" => inspect(reason)}}
    end
  end

  def add_voice(public_owner_id, voice_id, name) do
    url = "#{@base_url}/voices/add/#{public_owner_id}/#{voice_id}"
    body = if name, do: %{name: name}, else: %{}

    case Req.post(url, headers: headers(), json: body) do
      {:ok, %{status: 200, body: resp}} ->
        {:ok, resp}

      {:ok, %{status: status, body: body}} ->
        {:error, status, body}

      {:error, reason} ->
        {:error, 500, %{"error" => inspect(reason)}}
    end
  end

  # Agents

  def list_agents do
    case Req.get("#{@base_url}/convai/agents", headers: headers()) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, status, body}

      {:error, reason} ->
        {:error, 500, %{"error" => inspect(reason)}}
    end
  end

  def get_agent(agent_id) do
    case Req.get("#{@base_url}/convai/agents/#{agent_id}", headers: headers()) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, status, body}

      {:error, reason} ->
        {:error, 500, %{"error" => inspect(reason)}}
    end
  end

  def create_agent(params) do
    prompt = params["prompt"] || params[:prompt]
    name = params["name"] || params[:name] || "Custom Agent"
    first_message = params["firstMessage"] || params["first_message"] || params[:first_message] || ""
    voice_id = params["voiceId"] || params["voice_id"] || params[:voice_id] || "cjVigY5qzO86Huf0OWal"
    language = params["language"] || params[:language] || "en"
    workflow = params["workflow"] || params[:workflow]

    agent_config = %{
      name: name,
      conversation_config: %{
        agent: %{
          prompt: %{
            prompt: prompt,
            llm: "gemini-2.0-flash-001",
            temperature: 0.7
          },
          first_message: first_message,
          language: language
        },
        tts: %{
          voice_id: voice_id,
          model_id: "eleven_turbo_v2"
        }
      }
    }

    agent_config =
      if workflow && is_map(workflow["nodes"]) && map_size(workflow["nodes"]) > 0 do
        Map.put(agent_config, :workflow, workflow)
      else
        agent_config
      end

    case Req.post("#{@base_url}/convai/agents/create", headers: headers(), json: agent_config) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, status, body}

      {:error, reason} ->
        {:error, 500, %{"error" => inspect(reason)}}
    end
  end

  def update_agent(agent_id, params) do
    update_data = %{}

    update_data =
      if params["name"], do: Map.put(update_data, :name, params["name"]), else: update_data

    first_message = params["firstMessage"] || params["first_message"]
    voice_id = params["voiceId"] || params["voice_id"]

    has_conversation_updates =
      params["prompt"] != nil || first_message != nil ||
        voice_id != nil || params["language"] != nil

    update_data =
      if has_conversation_updates do
        conv_config = %{}

        agent_config =
          %{}
          |> then(fn c ->
            if params["prompt"], do: Map.put(c, :prompt, %{prompt: params["prompt"]}), else: c
          end)
          |> then(fn c ->
            if first_message, do: Map.put(c, :first_message, first_message), else: c
          end)
          |> then(fn c ->
            if params["language"], do: Map.put(c, :language, params["language"]), else: c
          end)

        conv_config =
          if map_size(agent_config) > 0 do
            Map.put(conv_config, :agent, agent_config)
          else
            conv_config
          end

        conv_config =
          if voice_id do
            Map.put(conv_config, :tts, %{voice_id: voice_id})
          else
            conv_config
          end

        if map_size(conv_config) > 0 do
          Map.put(update_data, :conversation_config, conv_config)
        else
          update_data
        end
      else
        update_data
      end

    workflow = params["workflow"]

    update_data =
      if workflow && is_map(workflow["nodes"]) && map_size(workflow["nodes"]) > 0 do
        Map.put(update_data, :workflow, workflow)
      else
        update_data
      end

    case Req.patch("#{@base_url}/convai/agents/#{agent_id}",
           headers: headers(),
           json: update_data
         ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, status, body}

      {:error, reason} ->
        {:error, 500, %{"error" => inspect(reason)}}
    end
  end

  def delete_agent(agent_id) do
    case Req.delete("#{@base_url}/convai/agents/#{agent_id}", headers: headers()) do
      {:ok, %{status: status}} when status in [200, 204] ->
        {:ok, %{success: true}}

      {:ok, %{status: status, body: body}} ->
        {:error, status, body}

      {:error, reason} ->
        {:error, 500, %{"error" => inspect(reason)}}
    end
  end

  # WebRTC Token

  def get_webrtc_token(agent_id) do
    aid = agent_id || default_agent_id()

    if is_nil(aid) or aid == "" do
      {:error, 400, %{"error" => "Agent ID is required"}}
    else
      url = "#{@base_url}/convai/conversation/token"

      case Req.get(url, headers: headers(), params: [{"agent_id", aid}]) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %{status: status, body: body}} ->
          {:error, status, body}

        {:error, reason} ->
          {:error, 500, %{"error" => inspect(reason)}}
      end
    end
  end

  def get_signed_url(agent_id \\ nil) do
    aid = agent_id || default_agent_id()

    if is_nil(aid) or aid == "" do
      {:error, 400, %{"error" => "Agent ID is required"}}
    else
      url = "#{@base_url}/convai/conversation/get-signed-url"

      case Req.get(url, headers: headers(), params: [{"agent_id", aid}]) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %{status: status, body: body}} ->
          {:error, status, body}

        {:error, reason} ->
          {:error, 500, %{"error" => inspect(reason)}}
      end
    end
  end
end
