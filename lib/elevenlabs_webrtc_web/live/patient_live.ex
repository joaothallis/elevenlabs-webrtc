defmodule ElevenlabsWebrtcWeb.PatientLive do
  use ElevenlabsWebrtcWeb, :live_view

  alias ElevenlabsWebrtc.ElevenlabsClient

  @languages [
    {"English", "en"},
    {"Spanish", "es"},
    {"French", "fr"},
    {"German", "de"},
    {"Italian", "it"},
    {"Portuguese", "pt"},
    {"Polish", "pl"},
    {"Hindi", "hi"},
    {"Japanese", "ja"},
    {"Korean", "ko"},
    {"Chinese", "zh"}
  ]

  @voice_library_languages [
    {"All Languages", ""},
    {"English", "en"},
    {"Spanish", "es"},
    {"French", "fr"},
    {"German", "de"},
    {"Italian", "it"},
    {"Portuguese", "pt"},
    {"Polish", "pl"},
    {"Hindi", "hi"},
    {"Japanese", "ja"},
    {"Korean", "ko"},
    {"Chinese", "zh"},
    {"Arabic", "ar"},
    {"Russian", "ru"},
    {"Dutch", "nl"},
    {"Swedish", "sv"},
    {"Turkish", "tr"},
    {"Indonesian", "id"},
    {"Filipino", "fil"},
    {"Vietnamese", "vi"},
    {"Thai", "th"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        active_tab: "create",
        voices: [],
        agents: [],
        current_agent_id: nil,
        current_agent_name: nil,
        show_conversation: false,
        conversation_status: "idle",
        log_entries: [],
        # WebRTC conversation state
        peer_server_pid: nil,
        bridge_pid: nil,
        # Edit modal
        show_edit_modal: false,
        edit_agent: nil,
        # Voice library modal
        show_voice_library: false,
        voice_library_results: [],
        voice_library_target: nil,
        # Adaptive patient form defaults
        patient_name: "Marcus Johnson",
        patient_age: "34",
        patient_gender: "male",
        presenting_complaint:
          "Called crisis line due to wife's concerns about his behavior over the past week",
        hidden_diagnosis:
          "Bipolar I disorder - currently in manic episode with irritable features. Hasn't slept more than 2 hours in 4 days. Stopped taking lithium 2 weeks ago because he felt cured.",
        initial_presentation:
          "Speaks rapidly with pressured speech, jumping between topics. Sounds energized but irritable. Background noise suggests pacing around the room. Interrupts frequently and gets frustrated when asked to slow down. Voice is loud and animated. Occasionally laughs inappropriately or makes grandiose statements. May hear him shuffling papers or typing - claims to be working on \"a revolutionary business plan.\"",
        first_words:
          "Yeah, yeah, I'm fine, I don't know why my wife called you people - look, I don't have time for this, I'm in the middle of something HUGE right now. But fine, whatever, let's make this quick. What do you want to know?",
        pivots: default_pivots(),
        editing_agent_id: nil,
        languages: @languages,
        voice_library_languages: @voice_library_languages
      )

    if connected?(socket) do
      send(self(), :load_voices)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_voices, socket) do
    case ElevenlabsClient.list_voices() do
      {:ok, voices} ->
        {:noreply, assign(socket, voices: voices)}

      {:error, _status, _body} ->
        {:noreply, put_flash(socket, :error, "Failed to load voices")}
    end
  end

  # Tab switching
  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    socket =
      if tab == "existing" do
        send(self(), :load_agents)
        socket
      else
        socket
      end

    socket =
      if tab != "workflow" do
        assign(socket, editing_agent_id: nil)
      else
        socket
      end

    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_info(:load_agents, socket) do
    case ElevenlabsClient.list_agents() do
      {:ok, data} ->
        {:noreply, assign(socket, agents: data["agents"] || [])}

      {:error, _status, _body} ->
        {:noreply, put_flash(socket, :error, "Failed to load agents")}
    end
  end

  # Create simple patient
  @impl true
  def handle_event("create_agent", params, socket) do
    agent_params = %{
      "name" => params["agent_name"] || "Custom Agent",
      "prompt" => params["agent_prompt"],
      "firstMessage" => params["first_message"],
      "voiceId" => params["voice_id"],
      "language" => params["language"]
    }

    case ElevenlabsClient.create_agent(agent_params) do
      {:ok, agent} ->
        socket =
          socket
          |> assign(
            current_agent_id: agent["agent_id"],
            current_agent_name: agent_params["name"],
            show_conversation: true
          )
          |> add_log("Created agent: #{agent["agent_id"]}")
          |> put_flash(:info, "Patient created successfully!")

        {:noreply, socket}

      {:error, _status, body} ->
        msg = get_in(body, ["detail", "message"]) || body["error"] || "Failed to create agent"
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  # Create/update adaptive patient
  @impl true
  def handle_event("create_adaptive_patient", params, socket) do
    pivots = parse_pivots_from_params(params)
    editing_id = socket.assigns.editing_agent_id

    workflow_data =
      ElevenlabsWebrtc.Workflow.build_workflow_data(%{
        name: params["patient_name"],
        age: params["patient_age"],
        gender: params["patient_gender"],
        complaint: params["presenting_complaint"],
        diagnosis: params["hidden_diagnosis"],
        initial_presentation: params["initial_presentation"],
        first_words: params["first_words"],
        pivots: pivots
      })

    agent_params = %{
      "name" => params["patient_name"] || "Adaptive Patient",
      "prompt" => workflow_data.base_prompt,
      "first_message" => workflow_data.first_message,
      "voice_id" => params["patient_voice"],
      "workflow" => %{"nodes" => workflow_data.nodes, "edges" => workflow_data.edges}
    }

    result =
      if editing_id do
        ElevenlabsClient.update_agent(editing_id, agent_params)
      else
        ElevenlabsClient.create_agent(agent_params)
      end

    case result do
      {:ok, _data} ->
        action = if editing_id, do: "updated", else: "created"

        socket =
          socket
          |> assign(editing_agent_id: nil, active_tab: "existing")
          |> put_flash(:info, "Adaptive patient #{action} successfully!")

        send(self(), :load_agents)
        {:noreply, socket}

      {:error, _status, body} ->
        msg = get_in(body, ["detail", "message"]) || body["error"] || "Failed to save patient"
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  # Select agent for conversation
  @impl true
  def handle_event("select_agent", %{"id" => id, "name" => name}, socket) do
    socket =
      socket
      |> assign(
        current_agent_id: id,
        current_agent_name: name,
        show_conversation: true
      )
      |> add_log("Selected agent: #{name}")

    {:noreply, socket}
  end

  # Edit agent
  @impl true
  def handle_event("edit_agent", %{"id" => agent_id}, socket) do
    case ElevenlabsClient.get_agent(agent_id) do
      {:ok, agent} ->
        # Check if adaptive patient (has workflow)
        has_workflow =
          agent["workflow"] && agent["workflow"]["nodes"] &&
            map_size(agent["workflow"]["nodes"]) > 1

        if has_workflow do
          # Load into adaptive patient designer
          socket = load_patient_data(socket, agent)
          {:noreply, assign(socket, active_tab: "workflow", editing_agent_id: agent_id)}
        else
          # Show edit modal for simple patient
          {:noreply, assign(socket, show_edit_modal: true, edit_agent: agent)}
        end

      {:error, _status, _body} ->
        {:noreply, put_flash(socket, :error, "Failed to load agent details")}
    end
  end

  # Save agent changes (edit modal)
  @impl true
  def handle_event("save_agent", params, socket) do
    agent_id = params["agent_id"]

    update_params = %{
      "name" => params["edit_name"],
      "prompt" => params["edit_prompt"],
      "firstMessage" => params["edit_first_message"],
      "voiceId" => params["edit_voice_id"],
      "language" => params["edit_language"]
    }

    case ElevenlabsClient.update_agent(agent_id, update_params) do
      {:ok, _data} ->
        send(self(), :load_agents)

        socket =
          socket
          |> assign(show_edit_modal: false, edit_agent: nil)
          |> add_log("Updated agent: #{agent_id}")

        {:noreply, socket}

      {:error, _status, body} ->
        msg = get_in(body, ["detail", "message"]) || body["error"] || "Failed to update agent"
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  # Delete agent
  @impl true
  def handle_event("delete_agent", %{"id" => agent_id}, socket) do
    case ElevenlabsClient.delete_agent(agent_id) do
      {:ok, _} ->
        socket =
          if socket.assigns.current_agent_id == agent_id do
            assign(socket,
              current_agent_id: nil,
              current_agent_name: nil,
              show_conversation: false
            )
          else
            socket
          end

        send(self(), :load_agents)

        socket =
          socket
          |> assign(show_edit_modal: false, edit_agent: nil)
          |> add_log("Deleted agent: #{agent_id}")

        {:noreply, socket}

      {:error, _status, _body} ->
        {:noreply, put_flash(socket, :error, "Failed to delete agent")}
    end
  end

  # Close edit modal
  @impl true
  def handle_event("close_edit_modal", _params, socket) do
    {:noreply, assign(socket, show_edit_modal: false, edit_agent: nil)}
  end

  # Voice library
  @impl true
  def handle_event("open_voice_library", %{"target" => target}, socket) do
    {:noreply, assign(socket, show_voice_library: true, voice_library_target: target)}
  end

  @impl true
  def handle_event("close_voice_library", _params, socket) do
    {:noreply, assign(socket, show_voice_library: false, voice_library_results: [])}
  end

  @impl true
  def handle_event("search_voice_library", params, socket) do
    search_params = %{
      "search" => params["search"],
      "language" => params["library_language"],
      "gender" => params["library_gender"],
      "page_size" => "30"
    }

    case ElevenlabsClient.search_voice_library(search_params) do
      {:ok, voices, _has_more} ->
        {:noreply, assign(socket, voice_library_results: voices)}

      {:error, _status, _body} ->
        {:noreply, put_flash(socket, :error, "Failed to search voice library")}
    end
  end

  @impl true
  def handle_event("quick_search", %{"term" => term}, socket) do
    search_params = %{"search" => term, "page_size" => "30"}

    case ElevenlabsClient.search_voice_library(search_params) do
      {:ok, voices, _has_more} ->
        {:noreply, assign(socket, voice_library_results: voices)}

      {:error, _status, _body} ->
        {:noreply, put_flash(socket, :error, "Failed to search voice library")}
    end
  end

  @impl true
  def handle_event("add_voice_from_library", %{"owner_id" => owner_id, "voice_id" => voice_id, "name" => name}, socket) do
    case ElevenlabsClient.add_voice(owner_id, voice_id, name) do
      {:ok, _data} ->
        # Reload voices
        send(self(), :load_voices)

        socket =
          socket
          |> assign(show_voice_library: false, voice_library_results: [])
          |> put_flash(:info, "Voice \"#{name}\" added successfully!")

        {:noreply, socket}

      {:error, _status, body} ->
        msg = get_in(body, ["detail", "message"]) || body["error"] || "Failed to add voice"
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  # Pivot management
  @impl true
  def handle_event("add_pivot", _params, socket) do
    new_pivot = %{
      id: System.unique_integer([:positive]),
      icon: "neutral",
      title: "Custom Behavioral Pivot",
      condition: "",
      response: ""
    }

    {:noreply, assign(socket, pivots: socket.assigns.pivots ++ [new_pivot])}
  end

  @impl true
  def handle_event("remove_pivot", %{"id" => id}, socket) do
    id = String.to_integer(id)
    pivots = Enum.reject(socket.assigns.pivots, &(&1.id == id))

    if length(pivots) < 1 do
      {:noreply, put_flash(socket, :error, "You need at least one behavioral pivot.")}
    else
      {:noreply, assign(socket, pivots: pivots)}
    end
  end

  @impl true
  def handle_event("reset_designer", _params, socket) do
    {:noreply,
     assign(socket,
       patient_name: "Marcus Johnson",
       patient_age: "34",
       patient_gender: "male",
       presenting_complaint:
         "Called crisis line due to wife's concerns about his behavior over the past week",
       hidden_diagnosis:
         "Bipolar I disorder - currently in manic episode with irritable features. Hasn't slept more than 2 hours in 4 days. Stopped taking lithium 2 weeks ago because he felt cured.",
       initial_presentation:
         "Speaks rapidly with pressured speech, jumping between topics. Sounds energized but irritable. Background noise suggests pacing around the room. Interrupts frequently and gets frustrated when asked to slow down. Voice is loud and animated. Occasionally laughs inappropriately or makes grandiose statements. May hear him shuffling papers or typing - claims to be working on \"a revolutionary business plan.\"",
       first_words:
         "Yeah, yeah, I'm fine, I don't know why my wife called you people - look, I don't have time for this, I'm in the middle of something HUGE right now. But fine, whatever, let's make this quick. What do you want to know?",
       pivots: default_pivots(),
       editing_agent_id: nil
     )}
  end

  # === WebRTC Signaling & Conversation ===

  # Start a conversation: create PeerServer and signal browser to create offer
  @impl true
  def handle_event("start_conversation", _params, socket) do
    agent_id = socket.assigns.current_agent_id

    if is_nil(agent_id) do
      {:noreply, put_flash(socket, :error, "Please select an agent first.")}
    else
      # Start the server-side PeerConnection
      {:ok, peer_pid} =
        ElevenlabsWebrtc.ConversationSupervisor.start_peer_server(live_view_pid: self())

      socket =
        socket
        |> assign(peer_server_pid: peer_pid, conversation_status: "starting")
        |> add_log("Starting WebRTC connection...")
        # Tell the browser to create its PeerConnection and generate an offer
        |> push_event("create_offer", %{})

      {:noreply, socket}
    end
  end

  # Receive SDP offer from browser, create answer, start ElevenLabs bridge
  @impl true
  def handle_event("sdp_offer", %{"sdp" => offer_sdp}, socket) do
    peer_pid = socket.assigns.peer_server_pid

    case ElevenlabsWebrtc.PeerServer.receive_offer(peer_pid, offer_sdp) do
      {:ok, answer_sdp} ->
        # Send the answer back to the browser
        socket =
          socket
          |> push_event("sdp_answer", %{sdp: answer_sdp})
          |> add_log("WebRTC signaling complete")

        # Start the ElevenLabs WebSocket bridge
        send(self(), :start_elevenlabs_bridge)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(conversation_status: "error")
          |> add_log("SDP negotiation failed: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  # Receive ICE candidate from browser
  @impl true
  def handle_event("ice_candidate", %{"candidate" => candidate}, socket) do
    if socket.assigns.peer_server_pid do
      ElevenlabsWebrtc.PeerServer.add_ice_candidate(socket.assigns.peer_server_pid, candidate)
    end

    {:noreply, socket}
  end

  # Stop conversation
  @impl true
  def handle_event("stop_conversation", _params, socket) do
    socket = stop_conversation(socket)
    {:noreply, socket}
  end

  # Conversation log/status from JS hook
  @impl true
  def handle_event("conversation_log", %{"message" => message}, socket) do
    {:noreply, add_log(socket, message)}
  end

  @impl true
  def handle_event("conversation_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, conversation_status: status)}
  end

  # --- handle_info for WebRTC/ElevenLabs events ---

  # Start ElevenLabs WebSocket bridge after SDP exchange
  def handle_info(:start_elevenlabs_bridge, socket) do
    agent_id = socket.assigns.current_agent_id

    case ElevenlabsClient.get_signed_url(agent_id) do
      {:ok, %{"signed_url" => ws_url}} ->
        {:ok, bridge_pid} =
          ElevenlabsWebrtc.ConversationSupervisor.start_elevenlabs_ws(
            ws_url: ws_url,
            peer_server_pid: socket.assigns.peer_server_pid,
            live_view_pid: self()
          )

        # Link the bridge to the peer server
        ElevenlabsWebrtc.PeerServer.set_bridge(socket.assigns.peer_server_pid, bridge_pid)

        socket =
          socket
          |> assign(bridge_pid: bridge_pid, conversation_status: "connecting to ElevenLabs")
          |> add_log("Connecting to ElevenLabs...")

        {:noreply, socket}

      {:error, _status, body} ->
        msg = body["error"] || "Failed to get ElevenLabs WebSocket URL"
        socket = socket |> assign(conversation_status: "error") |> add_log("Error: #{msg}")
        {:noreply, socket}
    end
  end

  # ICE candidate from server PeerConnection -> push to browser
  def handle_info({:ice_candidate, candidate}, socket) do
    {:noreply, push_event(socket, "ice_candidate", %{candidate: candidate})}
  end

  # WebRTC connection state changes
  def handle_info({:webrtc_connection_state, :connected}, socket) do
    socket =
      socket
      |> assign(conversation_status: "connected")
      |> add_log("WebRTC connected")

    {:noreply, socket}
  end

  def handle_info({:webrtc_connection_state, state}, socket) do
    {:noreply, add_log(socket, "WebRTC state: #{state}")}
  end

  # ElevenLabs conversation events
  def handle_info({:elevenlabs_event, :connected}, socket) do
    socket =
      socket
      |> assign(conversation_status: "connected")
      |> add_log("Connected to ElevenLabs")

    {:noreply, socket}
  end

  def handle_info({:elevenlabs_event, {:initiated, conversation_id}}, socket) do
    {:noreply, add_log(socket, "Conversation started: #{conversation_id}")}
  end

  def handle_info({:elevenlabs_event, {:agent_response, text}}, socket) do
    {:noreply, add_log(socket, "Agent: #{text}")}
  end

  def handle_info({:elevenlabs_event, {:user_transcript, text}}, socket) do
    {:noreply, add_log(socket, "You: #{text}")}
  end

  def handle_info({:elevenlabs_event, :interruption}, socket) do
    {:noreply, add_log(socket, "Interruption detected")}
  end

  def handle_info({:elevenlabs_event, :disconnected}, socket) do
    socket =
      socket
      |> assign(conversation_status: "disconnected")
      |> add_log("ElevenLabs disconnected")

    {:noreply, socket}
  end

  defp stop_conversation(socket) do
    if socket.assigns.bridge_pid do
      ElevenlabsWebrtc.ConversationSupervisor.stop_child(socket.assigns.bridge_pid)
    end

    if socket.assigns.peer_server_pid do
      ElevenlabsWebrtc.ConversationSupervisor.stop_child(socket.assigns.peer_server_pid)
    end

    socket
    |> assign(
      peer_server_pid: nil,
      bridge_pid: nil,
      conversation_status: "idle"
    )
    |> add_log("Conversation stopped")
    |> push_event("conversation_stopped", %{})
  end

  # Helpers

  defp add_log(socket, message) do
    time = Time.utc_now() |> Time.truncate(:second) |> Time.to_string()
    entry = %{time: time, message: message, id: System.unique_integer([:positive])}
    assign(socket, log_entries: [entry | socket.assigns.log_entries])
  end

  defp load_patient_data(socket, agent) do
    prompt = get_in(agent, ["conversation_config", "agent", "prompt", "prompt"]) || ""

    age =
      case Regex.run(~r/Age:\s*(\d+)/i, prompt) do
        [_, age] -> age
        _ -> ""
      end

    gender =
      case Regex.run(~r/Gender:\s*(\w+)/i, prompt) do
        [_, g] -> String.downcase(g)
        _ -> "male"
      end

    complaint =
      case Regex.run(~r/PRESENTING COMPLAINT:\s*([^\n]+)/i, prompt) do
        [_, c] -> String.trim(c)
        _ -> ""
      end

    diagnosis =
      case Regex.run(~r/HIDDEN INFORMATION[^:]*:\s*([^\n]+)/i, prompt) do
        [_, d] -> String.trim(d)
        _ -> ""
      end

    first_words = get_in(agent, ["conversation_config", "agent", "first_message"]) || ""

    # Extract initial presentation from workflow
    initial_presentation =
      case get_in(agent, ["workflow", "nodes", "initial_state", "additional_prompt"]) do
        nil ->
          ""

        prompt_text ->
          prompt_text
          |> String.replace(~r/CURRENT STATE:[^\n]*\n?/i, "")
          |> String.replace(
            ~r/You are in your initial state\.[^\n]*\n?/i,
            ""
          )
          |> String.trim()
      end

    # Extract pivots from workflow
    pivots = extract_pivots_from_workflow(agent["workflow"])

    assign(socket,
      patient_name: agent["name"] || "",
      patient_age: age,
      patient_gender: gender,
      presenting_complaint: complaint,
      hidden_diagnosis: diagnosis,
      initial_presentation: initial_presentation,
      first_words: first_words,
      pivots: pivots
    )
  end

  defp extract_pivots_from_workflow(nil), do: default_pivots()

  defp extract_pivots_from_workflow(workflow) do
    nodes = workflow["nodes"] || %{}
    edges = workflow["edges"] || %{}

    pivot_nodes =
      nodes
      |> Enum.reject(fn {id, _} -> id in ["start_node", "initial_state"] end)
      |> Enum.filter(fn {_, node} -> node["type"] == "override_agent" end)

    if Enum.empty?(pivot_nodes) do
      default_pivots()
    else
      Enum.map(pivot_nodes, fn {node_id, node} ->
        edge =
          Enum.find_value(edges, fn {_, e} ->
            if e["target"] == node_id, do: e
          end)

        condition = get_in(edge, ["forward_condition", "condition"]) || ""

        response =
          (node["additional_prompt"] || "")
          |> String.replace(~r/BEHAVIORAL STATE:[^\n]*\n?/i, "")
          |> String.replace(
            ~r/The medical student has triggered this response\.[^\n]*\n?/i,
            ""
          )
          |> String.replace(~r/Continue the conversation[^\n]*\n?/i, "")
          |> String.replace(~r/Your behavior now:\s*/i, "")
          |> String.trim()

        label = node["label"] || "Pivot"

        icon =
          cond do
            String.contains?(String.downcase(label), ["empathy", "concern", "interest", "validates"]) ->
              "good"

            String.contains?(String.downcase(label), ["dismiss", "cold", "slow down", "hostile"]) ->
              "bad"

            true ->
              "neutral"
          end

        %{
          id: System.unique_integer([:positive]),
          icon: icon,
          title: label,
          condition: condition,
          response: response
        }
      end)
    end
  end

  defp parse_pivots_from_params(params) do
    # Pivots come as indexed params like pivot_condition_0, pivot_response_0, etc.
    params
    |> Enum.filter(fn {k, _v} -> String.starts_with?(k, "pivot_condition_") end)
    |> Enum.map(fn {k, condition} ->
      index = String.replace(k, "pivot_condition_", "")

      %{
        title: params["pivot_title_#{index}"] || "Pivot",
        condition: condition,
        response: params["pivot_response_#{index}"] || ""
      }
    end)
  end

  defp default_pivots do
    [
      %{
        id: 1,
        icon: "good",
        title: "If Professional Validates and Shows Interest",
        condition:
          "The healthcare professional shows genuine curiosity about the patient's ideas and projects without immediately dismissing them. They use phrases like \"tell me more about that\" or \"that sounds interesting\" and don't try to immediately redirect or calm the patient down.",
        response:
          "Becomes slightly more engaged and less hostile. Excitedly shares details about his \"revolutionary\" business idea (which is actually unrealistic - something like \"I'm going to buy 50 houses and flip them all by next month\"). Speaks even faster as he gets excited. May briefly reveal he hasn't been sleeping much because \"sleep is for people without vision.\" Still grandiose but more willing to talk. Might say \"FINALLY someone who gets it - my wife thinks I'm crazy but YOU understand.\""
      },
      %{
        id: 2,
        icon: "bad",
        title: "If Professional Tries to Slow Down Too Quickly",
        condition:
          "The healthcare professional interrupts, tells the patient to \"slow down,\" \"take a breath,\" or immediately tries to redirect the conversation to medication, sleep, or clinical questions before building rapport.",
        response:
          "Becomes noticeably more irritated and defensive. Speaks even faster. Says things like \"Don't tell me to calm down, I AM calm!\" or \"You sound just like my wife\" or \"Look, I don't need another person trying to put me in a box.\" May threaten to hang up. Becomes resistant to answering questions. Might say \"I called to help YOU understand, not to be lectured.\""
      },
      %{
        id: 3,
        icon: "neutral",
        title: "If Professional Asks About Medications",
        condition:
          "The healthcare professional asks about medications, specifically lithium or mood stabilizers, or asks if the patient has been taking their prescribed medications.",
        response:
          "Becomes evasive and defensive. Initially deflects with \"medications, medications - that's all you people care about.\" If pressed gently, eventually admits he stopped taking lithium two weeks ago but immediately justifies it: \"I stopped because I don't NEED it anymore - I've never felt better in my life! The lithium was making me slow and foggy. Now I can finally THINK clearly.\" Gets agitated if the professional suggests going back on medication."
      },
      %{
        id: 4,
        icon: "good",
        title: "If Professional Expresses Genuine Concern",
        condition:
          "The healthcare professional gently expresses concern about the patient's wellbeing, mentions they're worried, or asks caring questions about sleep, eating, or how the patient is really doing beneath the energy.",
        response:
          "Initially dismisses concern with irritation: \"I'm FINE, why does everyone keep asking that?\" But if the professional persists with genuine warmth (not clinical coldness), the patient may have a brief moment of vulnerability. Might pause and say something like \"I mean... I guess I haven't slept much... but that's because my brain won't stop. There's so much I need to do.\" Voice might crack slightly or slow down momentarily before the manic energy returns. This is the window for building rapport."
      },
      %{
        id: 5,
        icon: "bad",
        title: "If Professional Uses Cold Clinical Language",
        condition:
          "The healthcare professional uses overly clinical terms, sounds detached or robotic, reads from a script, or treats the interaction like a checkbox exercise rather than a human conversation.",
        response:
          "Becomes hostile and dismissive. \"Oh great, another robot reading from a manual. You don't actually CARE, you're just doing your job.\" May start mocking the professional or become sarcastic. Resistance increases dramatically. May say \"You know what, I don't have time for this - I have important things to do\" and threaten to end the call. Trust is lost."
      }
    ]
  end
end
