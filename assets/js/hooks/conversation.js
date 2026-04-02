/**
 * LiveView Hook for WebRTC conversation via ex_webrtc.
 *
 * This hook manages the browser-side RTCPeerConnection that connects
 * to the Phoenix server's ex_webrtc PeerConnection. The server then
 * bridges audio to/from ElevenLabs via WebSocket.
 *
 * Flow:
 * 1. User clicks Start -> LiveView creates server-side PeerConnection
 * 2. LiveView pushes "create_offer" -> this hook creates browser PeerConnection + offer
 * 3. Hook sends SDP offer to LiveView -> LiveView passes to ex_webrtc -> gets answer
 * 4. LiveView pushes "sdp_answer" -> hook sets remote description
 * 5. ICE candidates exchanged via LiveView events
 * 6. Connection established, audio flows: Browser <-> Phoenix (ex_webrtc) <-> ElevenLabs
 */
const Conversation = {
  mounted() {
    this.pc = null;
    this.localStream = null;

    const startBtn = this.el.querySelector("#start-btn");
    const stopBtn = this.el.querySelector("#stop-btn");

    startBtn.addEventListener("click", () => {
      startBtn.disabled = true;
      // Tell LiveView to start the server-side PeerConnection
      this.pushEvent("start_conversation", {});
    });

    stopBtn.addEventListener("click", () => {
      this.cleanup();
      this.pushEvent("stop_conversation", {});
      startBtn.disabled = false;
      stopBtn.disabled = true;
    });

    // LiveView event: create an SDP offer
    this.handleEvent("create_offer", async () => {
      try {
        await this.createPeerConnection();
        await this.createAndSendOffer();
      } catch (error) {
        console.error("Failed to create offer:", error);
        this.pushEvent("conversation_log", {
          message: `Error creating offer: ${error.message}`,
        });
      }
    });

    // LiveView event: set the SDP answer from the server
    this.handleEvent("sdp_answer", async ({ sdp }) => {
      try {
        const answer = new RTCSessionDescription({ type: "answer", sdp });
        await this.pc.setRemoteDescription(answer);
        this.pushEvent("conversation_log", {
          message: "SDP answer set, WebRTC connecting...",
        });
      } catch (error) {
        console.error("Failed to set remote description:", error);
        this.pushEvent("conversation_log", {
          message: `Error setting answer: ${error.message}`,
        });
      }
    });

    // LiveView event: add ICE candidate from server
    this.handleEvent("ice_candidate", ({ candidate }) => {
      if (this.pc && candidate) {
        this.pc
          .addIceCandidate(new RTCIceCandidate(candidate))
          .catch((err) =>
            console.warn("Failed to add ICE candidate:", err)
          );
      }
    });

    // LiveView event: conversation stopped by server
    this.handleEvent("conversation_stopped", () => {
      this.cleanup();
      const startBtn = this.el.querySelector("#start-btn");
      const stopBtn = this.el.querySelector("#stop-btn");
      if (startBtn) startBtn.disabled = false;
      if (stopBtn) stopBtn.disabled = true;
    });
  },

  destroyed() {
    this.cleanup();
  },

  async createPeerConnection() {
    // Create the browser-side RTCPeerConnection
    this.pc = new RTCPeerConnection({
      iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
    });

    // Handle ICE candidates - send to server via LiveView
    this.pc.onicecandidate = (event) => {
      if (event.candidate) {
        this.pushEvent("ice_candidate", {
          candidate: {
            candidate: event.candidate.candidate,
            sdpMid: event.candidate.sdpMid,
            sdpMLineIndex: event.candidate.sdpMLineIndex,
          },
        });
      }
    };

    // Handle connection state changes
    this.pc.onconnectionstatechange = () => {
      const state = this.pc.connectionState;
      this.pushEvent("conversation_log", {
        message: `WebRTC connection: ${state}`,
      });

      if (state === "connected") {
        this.pushEvent("conversation_status", { status: "connected" });
        const stopBtn = this.el.querySelector("#stop-btn");
        if (stopBtn) stopBtn.disabled = false;
      } else if (state === "failed" || state === "disconnected") {
        this.pushEvent("conversation_status", { status: state });
      }
    };

    // Handle ICE connection state
    this.pc.oniceconnectionstatechange = () => {
      this.pushEvent("conversation_log", {
        message: `ICE connection: ${this.pc.iceConnectionState}`,
      });
    };

    // Handle remote audio track (agent's voice from ElevenLabs via server)
    this.pc.ontrack = (event) => {
      this.pushEvent("conversation_log", {
        message: `Remote track received: ${event.track.kind}`,
      });

      if (event.track.kind === "audio") {
        // Create an audio element to play the remote audio
        const audio = document.createElement("audio");
        audio.srcObject = new MediaStream([event.track]);
        audio.autoplay = true;
        audio.id = "remote-audio";
        // Append to conversation section (hidden)
        this.el.appendChild(audio);
      }
    };

    // Capture microphone and add audio track to PeerConnection
    try {
      this.localStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
        video: false,
      });

      this.localStream.getTracks().forEach((track) => {
        this.pc.addTrack(track, this.localStream);
      });

      this.pushEvent("conversation_log", {
        message: "Microphone captured",
      });
    } catch (error) {
      this.pushEvent("conversation_log", {
        message: `Microphone error: ${error.message}`,
      });
      throw error;
    }
  },

  async createAndSendOffer() {
    const offer = await this.pc.createOffer();
    await this.pc.setLocalDescription(offer);

    this.pushEvent("conversation_log", { message: "SDP offer created" });

    // Send the offer to the server via LiveView
    this.pushEvent("sdp_offer", { sdp: offer.sdp });
  },

  cleanup() {
    // Stop microphone
    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => track.stop());
      this.localStream = null;
    }

    // Close PeerConnection
    if (this.pc) {
      this.pc.close();
      this.pc = null;
    }

    // Remove remote audio element
    const audioEl = document.getElementById("remote-audio");
    if (audioEl) audioEl.remove();
  },
};

export default Conversation;
