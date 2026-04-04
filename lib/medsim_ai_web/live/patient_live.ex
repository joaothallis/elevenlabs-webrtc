defmodule MedsimAiWeb.PatientLive do
  use MedsimAiWeb, :live_view

  alias MedsimAi.ElevenLabs.{Agents, Voices, Conversation}
  alias MedsimAi.Workflows.Builder
  alias MedsimAi.Conversation.Session
  alias MedsimAi.WebRTC.PeerConnection

  @default_pivots [
    %{
      "title" => "If Professional Validates and Shows Interest",
      "condition" =>
        "The healthcare professional shows genuine curiosity about the patient's ideas and projects without immediately dismissing them. They use phrases like \"tell me more about that\" or \"that sounds interesting\" and don't try to immediately redirect or calm the patient down.",
      "response" =>
        "Becomes slightly more engaged and less hostile. Excitedly shares details about his \"revolutionary\" business idea (which is actually unrealistic - something like \"I'm going to buy 50 houses and flip them all by next month\"). Speaks even faster as he gets excited. May briefly reveal he hasn't been sleeping much because \"sleep is for people without vision.\" Still grandiose but more willing to talk. Might say \"FINALLY someone who gets it - my wife thinks I'm crazy but YOU understand.\"",
      "icon_class" => "good"
    },
    %{
      "title" => "If Professional Tries to Slow Down Too Quickly",
      "condition" =>
        "The healthcare professional interrupts, tells the patient to \"slow down,\" \"take a breath,\" or immediately tries to redirect the conversation to medication, sleep, or clinical questions before building rapport.",
      "response" =>
        "Becomes noticeably more irritated and defensive. Speaks even faster. Says things like \"Don't tell me to calm down, I AM calm!\" or \"You sound just like my wife\" or \"Look, I don't need another person trying to put me in a box.\" May threaten to hang up. Becomes resistant to answering questions. Might say \"I called to help YOU understand, not to be lectured.\"",
      "icon_class" => "bad"
    },
    %{
      "title" => "If Professional Asks About Medications",
      "condition" =>
        "The healthcare professional asks about medications, specifically lithium or mood stabilizers, or asks if the patient has been taking their prescribed medications.",
      "response" =>
        "Becomes evasive and defensive. Initially deflects with \"medications, medications - that's all you people care about.\" If pressed gently, eventually admits he stopped taking lithium two weeks ago but immediately justifies it: \"I stopped because I don't NEED it anymore - I've never felt better in my life! The lithium was making me slow and foggy. Now I can finally THINK clearly.\" Gets agitated if the professional suggests going back on medication.",
      "icon_class" => "neutral"
    },
    %{
      "title" => "If Professional Expresses Genuine Concern",
      "condition" =>
        "The healthcare professional gently expresses concern about the patient's wellbeing, mentions they're worried, or asks caring questions about sleep, eating, or how the patient is really doing beneath the energy.",
      "response" =>
        "Initially dismisses concern with irritation: \"I'm FINE, why does everyone keep asking that?\" But if the professional persists with genuine warmth (not clinical coldness), the patient may have a brief moment of vulnerability. Might pause and say something like \"I mean... I guess I haven't slept much... but that's because my brain won't stop. There's so much I need to do.\" Voice might crack slightly or slow down momentarily before the manic energy returns. This is the window for building rapport.",
      "icon_class" => "good"
    },
    %{
      "title" => "If Professional Uses Cold Clinical Language",
      "condition" =>
        "The healthcare professional uses overly clinical terms, sounds detached or robotic, reads from a script, or treats the interaction like a checkbox exercise rather than a human conversation.",
      "response" =>
        "Becomes hostile and dismissive. \"Oh great, another robot reading from a manual. You don't actually CARE, you're just doing your job.\" May start mocking the professional or become sarcastic. Resistance increases dramatically. May say \"You know what, I don't have time for this - I have important things to do\" and threaten to end the call. Trust is lost.",
      "icon_class" => "bad"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    voices = load_voices_async()

    socket =
      socket
      |> assign(
        active_tab: :create,
        voices: voices,
        agents: [],
        # Simple patient form
        # Conversation state
        current_agent_id: nil,
        current_agent_name: nil,
        conversation_status: "idle",
        conversation_log: [],
        conversation_session: nil,
        pc: nil,
        audio_track_id: nil,
        # Edit modal
        edit_modal_open: false,
        edit_agent: nil,
        # Voice library modal
        voice_library_open: false,
        voice_library_results: [],
        voice_library_target: nil,
        # Adaptive patient designer
        pivots: @default_pivots,
        editing_agent_id: nil,
        # Preview state
        preview_playing: false
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab = String.to_existing_atom(tab)

    socket =
      socket
      |> assign(active_tab: tab)
      |> then(fn s ->
        if tab == :existing, do: assign(s, agents: load_agents()), else: s
      end)
      |> then(fn s ->
        if tab != :workflow, do: assign(s, editing_agent_id: nil), else: s
      end)

    {:noreply, socket}
  end

  # Simple Patient Creation
  @impl true
  def handle_event("create_simple_patient", params, socket) do
    agent_params = %{
      "name" => params["agent_name"] || "Custom Agent",
      "prompt" => params["agent_prompt"],
      "first_message" => params["first_message"],
      "voice_id" => params["voice_id"],
      "language" => params["language"]
    }

    case Agents.create(agent_params) do
      {:ok, agent} ->
        socket =
          socket
          |> put_flash(:info, "Patient created successfully!")
          |> assign(
            current_agent_id: agent["agent_id"],
            current_agent_name: agent_params["name"]
          )
          |> add_log("Created agent: #{agent["agent_id"]}")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create patient: #{inspect(reason)}")}
    end
  end

  # Adaptive Patient Creation/Update
  @impl true
  def handle_event("create_adaptive_patient", params, socket) do
    pivots = parse_pivots_from_params(params)

    patient_data =
      Builder.get_patient_form_data(%{
        "name" => params["patient_name"],
        "age" => params["patient_age"],
        "gender" => params["patient_gender"],
        "presenting_complaint" => params["presenting_complaint"],
        "hidden_diagnosis" => params["hidden_diagnosis"],
        "initial_presentation" => params["initial_presentation"],
        "first_words" => params["first_words"],
        "voice_id" => params["patient_voice"],
        "pivots" => pivots
      })

    result =
      case socket.assigns.editing_agent_id do
        nil -> Agents.create(patient_data)
        agent_id -> Agents.update(agent_id, patient_data)
      end

    action = if socket.assigns.editing_agent_id, do: "updated", else: "created"

    case result do
      {:ok, _agent} ->
        socket =
          socket
          |> put_flash(:info, "Adaptive patient #{action} successfully!")
          |> assign(editing_agent_id: nil, active_tab: :existing, agents: load_agents())

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to #{action} patient: #{inspect(reason)}")}
    end
  end

  # Agent Selection
  @impl true
  def handle_event("select_agent", %{"id" => id, "name" => name}, socket) do
    socket =
      socket
      |> assign(current_agent_id: id, current_agent_name: name)
      |> add_log("Selected agent: #{name}")

    {:noreply, socket}
  end

  # Edit Modal
  @impl true
  def handle_event("open_edit_modal", %{"id" => agent_id}, socket) do
    case Agents.get(agent_id) do
      {:ok, agent} ->
        # Check if adaptive patient
        if agent["workflow"] && is_map(agent["workflow"]["nodes"]) &&
             map_size(agent["workflow"]["nodes"]) > 1 do
          # Load into adaptive patient designer
          patient_data = Builder.parse_patient_data(agent)

          socket =
            socket
            |> assign(
              active_tab: :workflow,
              editing_agent_id: agent_id,
              pivots: patient_data["pivots"]
            )
            |> push_event("load_patient_data", %{data: patient_data})

          {:noreply, socket}
        else
          {:noreply, assign(socket, edit_modal_open: true, edit_agent: agent)}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to load agent")}
    end
  end

  @impl true
  def handle_event("close_edit_modal", _params, socket) do
    {:noreply, assign(socket, edit_modal_open: false, edit_agent: nil)}
  end

  @impl true
  def handle_event("save_agent", params, socket) do
    agent_id = params["agent_id"]

    update_params = %{
      "name" => params["name"],
      "prompt" => params["prompt"],
      "first_message" => params["first_message"],
      "voice_id" => params["voice_id"],
      "language" => params["language"]
    }

    case Agents.update(agent_id, update_params) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Agent updated!")
          |> assign(edit_modal_open: false, edit_agent: nil, agents: load_agents())

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_agent", %{"id" => agent_id}, socket) do
    case Agents.delete(agent_id) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Agent deleted!")
          |> assign(edit_modal_open: false, edit_agent: nil, agents: load_agents())
          |> then(fn s ->
            if s.assigns.current_agent_id == agent_id,
              do: assign(s, current_agent_id: nil, current_agent_name: nil),
              else: s
          end)
          |> add_log("Deleted agent: #{agent_id}")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete: #{inspect(reason)}")}
    end
  end

  # Pivot Management
  @impl true
  def handle_event("add_pivot", _params, socket) do
    new_pivot = %{
      "title" => "Custom Behavioral Pivot",
      "condition" => "",
      "response" => "",
      "icon_class" => "neutral"
    }

    {:noreply, assign(socket, pivots: socket.assigns.pivots ++ [new_pivot])}
  end

  @impl true
  def handle_event("remove_pivot", %{"index" => index}, socket) do
    index = String.to_integer(index)
    pivots = socket.assigns.pivots

    if length(pivots) > 1 do
      {:noreply, assign(socket, pivots: List.delete_at(pivots, index))}
    else
      {:noreply, put_flash(socket, :error, "You need at least one behavioral pivot.")}
    end
  end

  # Voice Library
  @impl true
  def handle_event("open_voice_library", %{"target" => target}, socket) do
    {:noreply,
     assign(socket, voice_library_open: true, voice_library_target: target, voice_library_results: [])}
  end

  @impl true
  def handle_event("close_voice_library", _params, socket) do
    {:noreply, assign(socket, voice_library_open: false, voice_library_results: [])}
  end

  @impl true
  def handle_event("search_voices", params, socket) do
    search_params = %{
      "search" => params["search"],
      "language" => params["language"],
      "gender" => params["gender"]
    }

    case Voices.search_library(search_params) do
      {:ok, %{"voices" => voices}} ->
        {:noreply, assign(socket, voice_library_results: voices)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to search voices")}
    end
  end

  @impl true
  def handle_event("add_voice", params, socket) do
    case Voices.add_from_library(params["owner_id"], params["voice_id"], params["name"]) do
      {:ok, result} ->
        voices = load_voices_async()

        socket =
          socket
          |> assign(voices: voices, voice_library_open: false, voice_library_results: [])
          |> put_flash(:info, "Voice added successfully!")
          |> push_event("voice_added", %{voice_id: result["voice_id"] || params["voice_id"]})

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add voice: #{inspect(reason)}")}
    end
  end

  # Audio Preview
  @impl true
  def handle_event("preview_voice", %{"url" => url}, socket) do
    {:noreply, push_event(socket, "play_preview", %{url: url})}
  end

  @impl true
  def handle_event("stop_preview", _params, socket) do
    {:noreply, push_event(socket, "stop_preview", %{})}
  end

  # Conversation - Start
  @impl true
  def handle_event("start_conversation", _params, socket) do
    agent_id = socket.assigns.current_agent_id

    if agent_id do
      socket =
        socket
        |> assign(conversation_status: "requesting token")
        |> add_log("Requesting signed URL...")

      case Conversation.get_signed_url(agent_id) do
        {:ok, signed_url} ->
          # Start the WebSocket bridge session
          {:ok, session_pid} = Session.start_link(%{
            signed_url: signed_url,
            caller: self()
          })

          # Create ex_webrtc PeerConnection
          {:ok, pc} = PeerConnection.start_link(
            ice_servers: [%{urls: "stun:stun.l.google.com:19302"}]
          )

          # Add audio transceiver for bidirectional audio
          {:ok, _tr} = PeerConnection.add_transceiver(pc, :audio, direction: :sendrecv)

          # Create offer
          {:ok, offer} = PeerConnection.create_offer(pc)
          :ok = PeerConnection.set_local_description(pc, offer)

          socket =
            socket
            |> assign(
              conversation_status: "connecting",
              conversation_session: session_pid,
              pc: pc
            )
            |> add_log("WebRTC offer created, starting signaling...")
            |> push_event("rtc_offer", %{
              sdp: offer.sdp,
              type: to_string(offer.type)
            })

          {:noreply, socket}

        {:error, reason} ->
          socket =
            socket
            |> assign(conversation_status: "error")
            |> add_log("Error: #{inspect(reason)}")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Please select an agent first.")}
    end
  end

  # Conversation - Stop
  @impl true
  def handle_event("stop_conversation", _params, socket) do
    if socket.assigns.conversation_session do
      Session.stop(socket.assigns.conversation_session)
    end

    if socket.assigns.pc do
      PeerConnection.close(socket.assigns.pc)
    end

    socket =
      socket
      |> assign(
        conversation_status: "idle",
        conversation_session: nil,
        pc: nil,
        audio_track_id: nil
      )
      |> add_log("Conversation stopped")
      |> push_event("rtc_close", %{})

    {:noreply, socket}
  end

  # WebRTC Signaling from browser
  @impl true
  def handle_event("rtc_answer", %{"sdp" => sdp, "type" => type}, socket) do
    if socket.assigns.pc do
      answer = %{type: String.to_existing_atom(type), sdp: sdp}
      :ok = PeerConnection.set_remote_description(socket.assigns.pc, answer)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("rtc_ice_candidate", %{"candidate" => candidate_data}, socket) do
    if socket.assigns.pc do
      candidate = %{
        candidate: candidate_data["candidate"],
        sdp_mid: candidate_data["sdpMid"],
        sdp_m_line_index: candidate_data["sdpMLineIndex"]
      }

      PeerConnection.add_ice_candidate(socket.assigns.pc, candidate)
    end

    {:noreply, socket}
  end

  # ex_webrtc process messages
  @impl true
  def handle_info({:ex_webrtc, _pc, {:ice_candidate, candidate}}, socket) do
    socket =
      push_event(socket, "rtc_ice_candidate", %{
        candidate: candidate.candidate,
        sdpMid: candidate.sdp_mid,
        sdpMLineIndex: candidate.sdp_m_line_index
      })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, {:connection_state_change, :connected}}, socket) do
    socket =
      socket
      |> assign(conversation_status: "connected")
      |> add_log("WebRTC connected")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, {:connection_state_change, state}}, socket) do
    {:noreply, add_log(socket, "Connection state: #{state}")}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, {:track, %{kind: :audio} = track}}, socket) do
    {:noreply, assign(socket, audio_track_id: track.id)}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, {:rtp, _track_id, packet}}, socket) do
    # Forward browser audio to the ElevenLabs WebSocket session
    if socket.assigns.conversation_session do
      Session.send_audio(socket.assigns.conversation_session, packet)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:ex_webrtc, _pc, _msg}, socket) do
    # Catch-all for other ex_webrtc messages
    {:noreply, socket}
  end

  # Messages from ElevenLabs WebSocket Session
  @impl true
  def handle_info({:conversation_audio, audio_data}, socket) do
    # Send audio back to browser via ex_webrtc
    if socket.assigns.pc && socket.assigns.audio_track_id do
      # audio_data is an RTP packet to send
      PeerConnection.send_rtp(
        socket.assigns.pc,
        socket.assigns.audio_track_id,
        audio_data
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:conversation_event, type, data}, socket) do
    socket =
      case type do
        "agent_response" ->
          add_log(socket, "Agent: #{data}")

        "user_transcript" ->
          add_log(socket, "You: #{data}")

        "interruption" ->
          add_log(socket, "Interruption detected")

        "conversation_initiation_metadata" ->
          socket
          |> assign(conversation_status: "connected")
          |> add_log("Conversation started (ID: #{data})")

        _ ->
          add_log(socket, "Event: #{type}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:conversation_error, reason}, socket) do
    socket =
      socket
      |> assign(conversation_status: "error")
      |> add_log("Conversation error: #{inspect(reason)}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:conversation_closed}, socket) do
    socket =
      socket
      |> assign(conversation_status: "disconnected", conversation_session: nil)
      |> add_log("Conversation disconnected")

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Helpers

  defp load_voices_async do
    case Voices.list() do
      {:ok, voices} -> voices
      {:error, _} -> []
    end
  end

  defp load_agents do
    case Agents.list() do
      {:ok, %{"agents" => agents}} -> agents
      {:ok, agents} when is_list(agents) -> agents
      _ -> []
    end
  end

  defp add_log(socket, message) do
    entry = %{
      time: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S"),
      message: message
    }

    assign(socket, conversation_log: [entry | socket.assigns.conversation_log])
  end

  defp parse_pivots_from_params(params) do
    case params["pivots"] do
      nil ->
        []

      pivots when is_map(pivots) ->
        pivots
        |> Enum.sort_by(fn {k, _v} -> String.to_integer(k) end)
        |> Enum.map(fn {_k, v} ->
          %{
            "title" => v["title"] || "Behavioral Pivot",
            "condition" => v["condition"] || "",
            "response" => v["response"] || ""
          }
        end)

      _ ->
        []
    end
  end
end
