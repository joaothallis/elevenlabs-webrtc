defmodule ElevenlabsWebrtc.Workflow do
  @moduledoc """
  Builds ElevenLabs workflow data from patient designer form inputs.
  Converts structured patient behavior pivots into workflow nodes and edges.
  """

  def build_patient_prompt(%{name: name, age: age, gender: gender, complaint: complaint, diagnosis: diagnosis}) do
    diagnosis_text =
      if diagnosis && diagnosis != "" do
        "\nHIDDEN INFORMATION (reveal only if the student builds rapport and asks the right questions): #{diagnosis}"
      else
        ""
      end

    """
    You are a standardized patient for medical education. You are role-playing as a patient in a clinical encounter with a medical student.

    PATIENT IDENTITY:
    - Name: #{name}
    - Age: #{age || "Not specified"}
    - Gender: #{gender}

    PRESENTING COMPLAINT: #{complaint}
    #{diagnosis_text}

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

  def build_workflow_data(%{
        initial_presentation: initial_presentation,
        first_words: first_words,
        pivots: pivots
      } = patient_data) do
    base_prompt = build_patient_prompt(patient_data)

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
      |> Enum.reduce({nodes, edges}, fn {pivot, index}, {acc_nodes, acc_edges} ->
        pivot_id = "pivot_#{index}"
        node_id = "state_#{pivot_id}"
        edge_id = "edge_initial_to_#{pivot_id}"

        node = %{
          "type" => "override_agent",
          "label" => pivot.title,
          "additional_prompt" =>
            "BEHAVIORAL STATE: #{pivot.title}\n\nThe medical student has triggered this response. Your behavior now:\n#{pivot.response}\n\nContinue the conversation in this emotional state. If the student's approach changes significantly, you may shift to a different state.",
          "position" => %{"x" => 400, "y" => index * 100},
          "edge_order" => []
        }

        edge = %{
          "source" => "initial_state",
          "target" => node_id,
          "forward_condition" => %{
            "type" => "llm",
            "condition" => pivot.condition
          }
        }

        initial_node = acc_nodes["initial_state"]

        updated_initial =
          Map.update!(initial_node, "edge_order", fn order -> order ++ [edge_id] end)

        acc_nodes =
          acc_nodes
          |> Map.put(node_id, node)
          |> Map.put("initial_state", updated_initial)

        acc_edges = Map.put(acc_edges, edge_id, edge)

        {acc_nodes, acc_edges}
      end)

    %{
      nodes: nodes,
      edges: edges,
      base_prompt: base_prompt,
      first_message: first_words
    }
  end
end
