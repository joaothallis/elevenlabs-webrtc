defmodule ElevenlabsWebrtc.ElevenlabsClientTest do
  use ExUnit.Case, async: true

  alias ElevenlabsWebrtc.ElevenlabsClient

  describe "config/0" do
    test "returns map with expected keys" do
      config = ElevenlabsClient.config()
      assert Map.has_key?(config, :agent_id)
      assert Map.has_key?(config, :has_api_key)
    end

    test "has_api_key is boolean" do
      config = ElevenlabsClient.config()
      assert is_boolean(config.has_api_key)
    end
  end

  describe "has_api_key?/0" do
    test "returns false when no key configured" do
      # In test env, no API key is set
      refute ElevenlabsClient.has_api_key?()
    end
  end

  describe "get_signed_url/1" do
    test "returns error when no agent_id and no default" do
      assert {:error, 400, %{"error" => "Agent ID is required"}} =
               ElevenlabsClient.get_signed_url(nil)
    end

    test "returns error for empty agent_id" do
      assert {:error, 400, %{"error" => "Agent ID is required"}} =
               ElevenlabsClient.get_signed_url("")
    end
  end

  describe "get_webrtc_token/1" do
    test "returns error when no agent_id and no default" do
      assert {:error, 400, %{"error" => "Agent ID is required"}} =
               ElevenlabsClient.get_webrtc_token(nil)
    end
  end
end
