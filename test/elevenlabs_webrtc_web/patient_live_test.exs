defmodule ElevenlabsWebrtcWeb.PatientLiveTest do
  use ElevenlabsWebrtcWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the main page with tabs", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "MedSimAI Patient Builder"
    assert html =~ "Simple Patient"
    assert html =~ "Adaptive Patient"
    assert html =~ "Use Existing"
  end

  test "create tab is active by default", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Create New Patient"
    assert html =~ "Patient History"
  end

  test "switching to workflow tab shows adaptive patient designer", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html = view |> element(~s{button[phx-value-tab="workflow"]}) |> render_click()

    assert html =~ "Adaptive Patient Designer"
    assert html =~ "Patient Case"
    assert html =~ "Behavioral Pivots"
    assert html =~ "Workflow Preview"
  end

  test "switching to existing tab shows agents list", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html = view |> element(~s{button[phx-value-tab="existing"]}) |> render_click()

    assert html =~ "Your Patients"
  end

  test "default adaptive patient data is populated", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html = view |> element(~s{button[phx-value-tab="workflow"]}) |> render_click()

    assert html =~ "Marcus Johnson"
    assert html =~ "Validates and Shows Interest"
    assert html =~ "Slow Down Too Quickly"
    assert html =~ "Asks About Medications"
  end

  test "add_pivot adds a new pivot card", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    # Switch to workflow tab first
    view |> element(~s{button[phx-value-tab="workflow"]}) |> render_click()

    # Count existing pivots (5 defaults)
    html_before = render(view)
    pivot_count_before = count_occurrences(html_before, "pivot-card")

    # Add a pivot
    html = view |> element(~s{button[phx-click="add_pivot"]}) |> render_click()
    pivot_count_after = count_occurrences(html, "pivot-card")

    assert pivot_count_after == pivot_count_before + 1
    assert html =~ "Custom Behavioral Pivot"
  end

  test "conversation section is hidden when no agent selected", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    refute html =~ "conversation-section"
  end

  test "selecting an agent shows conversation section", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      view
      |> render_click("select_agent", %{"id" => "test-agent-id", "name" => "Test Agent"})

    assert html =~ "conversation-section"
    assert html =~ "Test Agent"
    assert html =~ "Status: idle"
  end

  test "reset_designer restores default values", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> element(~s{button[phx-value-tab="workflow"]}) |> render_click()

    # Reset
    html = view |> render_click("reset_designer", %{})

    assert html =~ "Marcus Johnson"
  end

  defp count_occurrences(string, substring) do
    string
    |> String.split(substring)
    |> length()
    |> Kernel.-(1)
  end
end
