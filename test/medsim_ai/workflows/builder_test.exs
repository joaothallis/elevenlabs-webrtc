defmodule MedsimAi.Workflows.BuilderTest do
  use ExUnit.Case, async: true

  alias MedsimAi.Workflows.Builder

  describe "build_patient_prompt/1" do
    test "generates prompt with patient identity" do
      prompt =
        Builder.build_patient_prompt(%{
          "name" => "John Smith",
          "age" => "45",
          "gender" => "male",
          "complaint" => "Chest pain",
          "diagnosis" => "Anxiety"
        })

      assert prompt =~ "John Smith"
      assert prompt =~ "45"
      assert prompt =~ "male"
      assert prompt =~ "Chest pain"
      assert prompt =~ "Anxiety"
    end

    test "handles missing diagnosis" do
      prompt =
        Builder.build_patient_prompt(%{
          "name" => "Jane",
          "age" => "30",
          "gender" => "female",
          "complaint" => "Headache",
          "diagnosis" => ""
        })

      assert prompt =~ "Jane"
      refute prompt =~ "HIDDEN INFORMATION"
    end
  end

  describe "build_workflow/1" do
    test "creates start node and initial state" do
      workflow =
        Builder.build_workflow(%{
          "initial_presentation" => "Anxious patient",
          "pivots" => []
        })

      assert Map.has_key?(workflow["nodes"], "start_node")
      assert Map.has_key?(workflow["nodes"], "initial_state")
      assert workflow["nodes"]["start_node"]["type"] == "start"
    end

    test "creates pivot nodes and edges" do
      workflow =
        Builder.build_workflow(%{
          "initial_presentation" => "Anxious",
          "pivots" => [
            %{"title" => "Empathy", "condition" => "Shows empathy", "response" => "Opens up"}
          ]
        })

      assert Map.has_key?(workflow["nodes"], "state_pivot_0")
      assert Map.has_key?(workflow["edges"], "edge_initial_to_pivot_0")
      assert workflow["edges"]["edge_initial_to_pivot_0"]["forward_condition"]["type"] == "llm"
    end
  end

  describe "classify_pivot_icon/1" do
    test "classifies positive labels as good" do
      assert Builder.classify_pivot_icon("If Professional Validates") == "good"
      assert Builder.classify_pivot_icon("Shows Concern") == "good"
    end

    test "classifies negative labels as bad" do
      assert Builder.classify_pivot_icon("Cold Clinical Language") == "bad"
      assert Builder.classify_pivot_icon("Dismissive Approach") == "bad"
    end

    test "classifies neutral labels" do
      assert Builder.classify_pivot_icon("Asks About Medications") == "neutral"
    end
  end
end
