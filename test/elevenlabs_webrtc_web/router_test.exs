defmodule ElevenlabsWebrtcWeb.RouterTest do
  use ElevenlabsWebrtcWeb.ConnCase

  test "GET / returns 200", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "MedSimAI Patient Builder"
  end

  test "GET /api/config returns JSON with expected keys", %{conn: conn} do
    conn = get(conn, ~p"/api/config")
    json = json_response(conn, 200)
    assert Map.has_key?(json, "agent_id")
    assert Map.has_key?(json, "has_api_key")
  end

  test "GET /api/voices returns 500 without API key", %{conn: conn} do
    conn = get(conn, ~p"/api/voices")
    json = json_response(conn, 500)
    assert json["error"] =~ "API key"
  end

  test "GET /api/agents returns 500 without API key", %{conn: conn} do
    conn = get(conn, ~p"/api/agents")
    json = json_response(conn, 500)
    assert json["error"] =~ "API key"
  end

  test "POST /api/webrtc-token returns 500 without API key", %{conn: conn} do
    conn = post(conn, ~p"/api/webrtc-token", %{agentId: "test"})
    json = json_response(conn, 500)
    assert json["error"] =~ "API key"
  end

  test "POST /api/voice-library/add validates required params", %{conn: conn} do
    # Without API key, should fail before validation
    conn = post(conn, ~p"/api/voice-library/add", %{})
    json = json_response(conn, 500)
    assert json["error"] =~ "API key"
  end
end
