defmodule ElevenlabsWebrtc.WorkflowTest do
  use ExUnit.Case, async: true

  alias ElevenlabsWebrtc.Workflow

  describe "build_patient_prompt/1" do
    test "includes patient identity fields" do
      prompt =
        Workflow.build_patient_prompt(%{
          name: "Jane Doe",
          age: "45",
          gender: "female",
          complaint: "Chest pain for 2 days",
          diagnosis: "Anxiety-induced chest pain"
        })

      assert prompt =~ "Jane Doe"
      assert prompt =~ "45"
      assert prompt =~ "female"
      assert prompt =~ "Chest pain for 2 days"
      assert prompt =~ "Anxiety-induced chest pain"
      assert prompt =~ "HIDDEN INFORMATION"
    end

    test "handles missing age" do
      prompt =
        Workflow.build_patient_prompt(%{
          name: "Test",
          age: nil,
          gender: "male",
          complaint: "Headache",
          diagnosis: nil
        })

      assert prompt =~ "Not specified"
    end

    test "omits hidden info section when diagnosis is empty" do
      prompt =
        Workflow.build_patient_prompt(%{
          name: "Test",
          age: "30",
          gender: "male",
          complaint: "Headache",
          diagnosis: ""
        })

      refute prompt =~ "HIDDEN INFORMATION"
    end

    test "includes role-playing instructions" do
      prompt =
        Workflow.build_patient_prompt(%{
          name: "Test",
          age: "30",
          gender: "other",
          complaint: "Test",
          diagnosis: nil
        })

      assert prompt =~ "standardized patient"
      assert prompt =~ "Stay in character"
      assert prompt =~ "empathetic"
    end
  end

  describe "build_workflow_data/1" do
    test "creates start node and initial state" do
      data =
        Workflow.build_workflow_data(%{
          name: "Test Patient",
          age: "30",
          gender: "male",
          complaint: "Test complaint",
          diagnosis: "Test diagnosis",
          initial_presentation: "Looks nervous",
          first_words: "Hello doctor",
          pivots: []
        })

      assert Map.has_key?(data.nodes, "start_node")
      assert Map.has_key?(data.nodes, "initial_state")
      assert data.nodes["start_node"]["type"] == "start"
      assert data.nodes["initial_state"]["type"] == "override_agent"
      assert data.first_message == "Hello doctor"
    end

    test "creates edge from start to initial state" do
      data =
        Workflow.build_workflow_data(%{
          name: "Test",
          age: "30",
          gender: "male",
          complaint: "Test",
          diagnosis: "",
          initial_presentation: "Nervous",
          first_words: "Hi",
          pivots: []
        })

      assert Map.has_key?(data.edges, "edge_start_to_initial")
      edge = data.edges["edge_start_to_initial"]
      assert edge["source"] == "start_node"
      assert edge["target"] == "initial_state"
      assert edge["forward_condition"]["type"] == "unconditional"
    end

    test "creates pivot nodes and edges" do
      pivots = [
        %{title: "Good Response", condition: "Student is empathetic", response: "Opens up"},
        %{title: "Bad Response", condition: "Student is cold", response: "Shuts down"}
      ]

      data =
        Workflow.build_workflow_data(%{
          name: "Test",
          age: "30",
          gender: "male",
          complaint: "Test",
          diagnosis: "",
          initial_presentation: "Nervous",
          first_words: "Hi",
          pivots: pivots
        })

      # Should have start + initial + 2 pivots = 4 nodes
      assert map_size(data.nodes) == 4

      # Should have start->initial + 2 pivot edges = 3 edges
      assert map_size(data.edges) == 3

      # Check pivot nodes exist and have correct type
      assert data.nodes["state_pivot_0"]["type"] == "override_agent"
      assert data.nodes["state_pivot_0"]["label"] == "Good Response"
      assert data.nodes["state_pivot_1"]["label"] == "Bad Response"

      # Check pivot edges have LLM conditions
      assert data.edges["edge_initial_to_pivot_0"]["forward_condition"]["type"] == "llm"

      assert data.edges["edge_initial_to_pivot_0"]["forward_condition"]["condition"] ==
               "Student is empathetic"

      # Check initial state's edge_order includes pivot edges
      assert "edge_initial_to_pivot_0" in data.nodes["initial_state"]["edge_order"]
      assert "edge_initial_to_pivot_1" in data.nodes["initial_state"]["edge_order"]
    end

    test "includes initial presentation in initial state prompt" do
      data =
        Workflow.build_workflow_data(%{
          name: "Test",
          age: "30",
          gender: "male",
          complaint: "Test",
          diagnosis: "",
          initial_presentation: "Pacing around nervously",
          first_words: "Hi",
          pivots: []
        })

      assert data.nodes["initial_state"]["additional_prompt"] =~ "Pacing around nervously"
    end

    test "generates base prompt from patient data" do
      data =
        Workflow.build_workflow_data(%{
          name: "Marcus Johnson",
          age: "34",
          gender: "male",
          complaint: "Wife concerned about behavior",
          diagnosis: "Bipolar I",
          initial_presentation: "Pressured speech",
          first_words: "Yeah, I'm fine",
          pivots: []
        })

      assert data.base_prompt =~ "Marcus Johnson"
      assert data.base_prompt =~ "34"
      assert data.base_prompt =~ "Bipolar I"
    end
  end
end
