defmodule ElevenlabsWebrtc.PeerServerTest do
  use ExUnit.Case, async: true

  alias ElevenlabsWebrtc.PeerServer

  test "starts and links to caller" do
    {:ok, pid} = PeerServer.start_link(live_view_pid: self())
    assert is_pid(pid)
    assert Process.alive?(pid)

    GenServer.stop(pid)
  end

  test "set_bridge stores bridge pid" do
    {:ok, pid} = PeerServer.start_link(live_view_pid: self())
    bridge = spawn(fn -> Process.sleep(:infinity) end)

    assert :ok = PeerServer.set_bridge(pid, bridge)

    GenServer.stop(pid)
    Process.exit(bridge, :kill)
  end

  test "forwards ICE candidates to live_view_pid" do
    {:ok, pid} = PeerServer.start_link(live_view_pid: self())

    # Simulate an ICE candidate from ex_webrtc
    send(pid, {:ex_webrtc, pid, {:ice_candidate, %{candidate: "candidate:1", sdp_mid: "0", sdp_m_line_index: 0}}})

    assert_receive {:ice_candidate, %{"candidate" => "candidate:1", "sdpMid" => "0", "sdpMLineIndex" => 0}}, 1000

    GenServer.stop(pid)
  end

  test "forwards connection state changes to live_view_pid" do
    {:ok, pid} = PeerServer.start_link(live_view_pid: self())

    send(pid, {:ex_webrtc, pid, {:connection_state_change, :connected}})

    assert_receive {:webrtc_connection_state, :connected}, 1000

    GenServer.stop(pid)
  end

  test "handles unknown ex_webrtc messages without crashing" do
    {:ok, pid} = PeerServer.start_link(live_view_pid: self())

    send(pid, {:ex_webrtc, pid, {:some_unknown_event, :data}})

    # Should still be alive
    Process.sleep(50)
    assert Process.alive?(pid)

    GenServer.stop(pid)
  end
end
