defmodule ElevenlabsWebrtc.ConversationSupervisorTest do
  use ExUnit.Case, async: true

  alias ElevenlabsWebrtc.ConversationSupervisor

  test "supervisor is running" do
    pid = Process.whereis(ConversationSupervisor)
    assert is_pid(pid)
    assert Process.alive?(pid)
  end

  test "can start a peer server" do
    {:ok, pid} = ConversationSupervisor.start_peer_server(live_view_pid: self())
    assert is_pid(pid)
    assert Process.alive?(pid)

    # Cleanup
    ConversationSupervisor.stop_child(pid)
    refute Process.alive?(pid)
  end

  test "stop_child terminates the process" do
    {:ok, pid} = ConversationSupervisor.start_peer_server(live_view_pid: self())
    assert Process.alive?(pid)

    :ok = ConversationSupervisor.stop_child(pid)
    refute Process.alive?(pid)
  end
end
