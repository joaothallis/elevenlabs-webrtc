defmodule MedsimAi.Workflows.Builder do
  @moduledoc """
  Converts adaptive patient form data into ElevenLabs workflow API format.
  Port of src/workflow-builder.js.
  """

  def build_patient_prompt(params) do
    name = params["name"] || "Patient"
    age = params["age"] || "Not specified"
    gender = params["gender"] || "male"
    complaint = params["complaint"] || ""
    diagnosis = params["diagnosis"] || ""

    hidden_info =
      if diagnosis != "" do
        "\nHIDDEN INFORMATION (reveal only if the student builds rapport and asks the right questions): #{diagnosis}"
      else
        ""
      end

    """
    You are a standardized patient for medical education. You are role-playing as a patient in a clinical encounter with a medical student.

    PATIENT IDENTITY:
    - Name: #{name}
    - Age: #{age}
    - Gender: #{gender}

    PRESENTING COMPLAINT: #{complaint}
    #{hidden_info}

    IMPORTANT INSTRUCTIONS:
    1. Stay in character as the patient at all times
    2. Respond naturally and realistically to the student's questions
    3. Your emotional state and willingness to share information should depend on how the student treats you
    4. If the student is empathetic and professional, you can open up more
    5. If the student is rushed, dismissive, or uses too much jargon, become more guarded
    6. Never break character to explain what you're doing or why
    7. React emotionally as a real patient would - show anxiety, frustration, relief, etc.
    8. Don't volunteer all information at once - let the student discover things through good questioning\
    """
  end

  def build_workflow(params) do
    initial_presentation = params["initial_presentation"] || ""
    pivots = params["pivots"] || []

    nodes = %{
      "start_node" => %{
        "type" => "start",
        "position" => %{"x" => 0, "y" => 0},
        "edge_order" => ["edge_start_to_initial"]
      },
      "initial_state" => %{
        "type" => "override_agent",
        "label" => "Initial Presentation",
        "additional_prompt" =>
          "CURRENT STATE: Initial presentation. #{initial_presentation}\n\nYou are in your initial state. Present your symptoms as described but don't volunteer too much information yet. Wait to see how the medical student approaches you before deciding how open to be.",
        "position" => %{"x" => 200, "y" => 0},
        "edge_order" => []
      }
    }

    edges = %{
      "edge_start_to_initial" => %{
        "source" => "start_node",
        "target" => "initial_state",
        "forward_condition" => %{"type" => "unconditional"}
      }
    }

    {nodes, edges} =
      pivots
      |> Enum.with_index()
      |> Enum.reduce({nodes, edges}, fn {pivot, index}, {nodes_acc, edges_acc} ->
        pivot_id = "pivot_#{index}"
        node_id = "state_#{pivot_id}"
        edge_id = "edge_initial_to_#{pivot_id}"

        condition = pivot["condition"] || ""
        response = pivot["response"] || ""
        title = pivot["title"] || "State #{index + 1}"

        node = %{
          "type" => "override_agent",
          "label" => title,
          "additional_prompt" =>
            "BEHAVIORAL STATE: #{title}\n\nThe medical student has triggered this response. Your behavior now:\n#{response}\n\nContinue the conversation in this emotional state. If the student's approach changes significantly, you may shift to a different state.",
          "position" => %{"x" => 400, "y" => index * 100},
          "edge_order" => []
        }

        edge = %{
          "source" => "initial_state",
          "target" => node_id,
          "forward_condition" => %{
            "type" => "llm",
            "condition" => condition
          }
        }

        nodes_acc = Map.put(nodes_acc, node_id, node)
        edges_acc = Map.put(edges_acc, edge_id, edge)

        # Add edge to initial state's edge_order
        nodes_acc =
          update_in(nodes_acc, ["initial_state", "edge_order"], fn order ->
            order ++ [edge_id]
          end)

        {nodes_acc, edges_acc}
      end)

    %{"nodes" => nodes, "edges" => edges}
  end

  def get_patient_form_data(params) do
    base_prompt =
      build_patient_prompt(%{
        "name" => params["name"],
        "age" => params["age"],
        "gender" => params["gender"],
        "complaint" => params["presenting_complaint"],
        "diagnosis" => params["hidden_diagnosis"]
      })

    workflow =
      build_workflow(%{
        "initial_presentation" => params["initial_presentation"],
        "pivots" => params["pivots"] || []
      })

    %{
      "name" => params["name"] || "Adaptive Patient",
      "prompt" => base_prompt,
      "first_message" => params["first_words"] || "",
      "voice_id" => params["voice_id"] || "",
      "workflow" => workflow
    }
  end

  def parse_patient_data(agent) do
    prompt = get_in(agent, ["conversation_config", "agent", "prompt", "prompt"]) || ""

    name = agent["name"] || ""

    age =
      case Regex.run(~r/Age:\s*(\d+)/i, prompt) do
        [_, age] -> age
        _ -> ""
      end

    gender =
      case Regex.run(~r/Gender:\s*(\w+)/i, prompt) do
        [_, gender] -> String.downcase(gender)
        _ -> "male"
      end

    complaint =
      case Regex.run(~r/PRESENTING COMPLAINT:\s*([^\n]+)/i, prompt) do
        [_, complaint] -> String.trim(complaint)
        _ -> ""
      end

    diagnosis =
      case Regex.run(~r/HIDDEN INFORMATION[^:]*:\s*([^\n]+)/i, prompt) do
        [_, diagnosis] -> String.trim(diagnosis)
        _ -> ""
      end

    first_message = get_in(agent, ["conversation_config", "agent", "first_message"]) || ""
    voice_id = get_in(agent, ["conversation_config", "tts", "voice_id"]) || ""

    pivots = parse_workflow_pivots(agent["workflow"])

    initial_presentation =
      parse_initial_presentation(get_in(agent, ["workflow", "nodes", "initial_state"]))

    %{
      "name" => name,
      "age" => age,
      "gender" => gender,
      "presenting_complaint" => complaint,
      "hidden_diagnosis" => diagnosis,
      "first_words" => first_message,
      "voice_id" => voice_id,
      "initial_presentation" => initial_presentation,
      "pivots" => pivots
    }
  end

  defp parse_initial_presentation(nil), do: ""

  defp parse_initial_presentation(node) do
    (node["additional_prompt"] || "")
    |> String.replace(~r/CURRENT STATE:[^\n]*\n?/i, "")
    |> String.replace(~r/You are in your initial state\.[^\n]*\n?/i, "")
    |> String.trim()
  end

  defp parse_workflow_pivots(nil), do: []
  defp parse_workflow_pivots(%{"nodes" => nil}), do: []

  defp parse_workflow_pivots(%{"nodes" => nodes, "edges" => edges}) do
    nodes
    |> Enum.filter(fn {id, node} ->
      id not in ["start_node", "initial_state"] and node["type"] == "override_agent"
    end)
    |> Enum.map(fn {node_id, node} ->
      edge = Enum.find(edges || %{}, fn {_id, e} -> e["target"] == node_id end)
      condition = if edge, do: elem(edge, 1)["forward_condition"]["condition"] || "", else: ""

      response =
        (node["additional_prompt"] || "")
        |> String.replace(~r/BEHAVIORAL STATE:[^\n]*\n?/i, "")
        |> String.replace(~r/The medical student has triggered this response\.[^\n]*\n?/i, "")
        |> String.replace(~r/Continue the conversation[^\n]*\n?/i, "")
        |> String.replace(~r/Your behavior now:\s*/i, "")
        |> String.trim()

      title = node["label"] || "Behavioral Pivot"

      icon_class = classify_pivot_icon(title)

      %{
        "title" => title,
        "condition" => condition,
        "response" => response,
        "icon_class" => icon_class
      }
    end)
  end

  defp parse_workflow_pivots(_), do: []

  def classify_pivot_icon(label) do
    lower = String.downcase(label)

    cond do
      String.contains?(lower, "empathy") or String.contains?(lower, "concern") or
        String.contains?(lower, "interest") or String.contains?(lower, "validates") ->
        "good"

      String.contains?(lower, "dismiss") or String.contains?(lower, "cold") or
        String.contains?(lower, "slow down") or String.contains?(lower, "hostile") ->
        "bad"

      true ->
        "neutral"
    end
  end
end
