/**
 * WebRTC Hook for Phoenix LiveView
 *
 * Handles browser-side WebRTC peer connection for bidirectional audio
 * with the Phoenix server (which bridges to ElevenLabs via WebSocket).
 */
const WebRTCHook = {
  mounted() {
    this.pc = null;
    this.localStream = null;

    // Handle SDP offer from server (ex_webrtc)
    this.handleEvent("rtc_offer", async ({ sdp, type }) => {
      try {
        this.pc = new RTCPeerConnection({
          iceServers: [{ urls: "stun:stun.l.google.com:19302" }],
        });

        // Handle ICE candidates
        this.pc.onicecandidate = (event) => {
          if (event.candidate) {
            this.pushEvent("rtc_ice_candidate", {
              candidate: {
                candidate: event.candidate.candidate,
                sdpMid: event.candidate.sdpMid,
                sdpMLineIndex: event.candidate.sdpMLineIndex,
              },
            });
          }
        };

        // Handle incoming audio track from server
        this.pc.ontrack = (event) => {
          const audio = document.createElement("audio");
          audio.srcObject = event.streams[0];
          audio.autoplay = true;
          audio.id = "remote-audio";
          document.body.appendChild(audio);
        };

        // Connection state changes
        this.pc.onconnectionstatechange = () => {
          console.log("WebRTC connection state:", this.pc.connectionState);
        };

        // Get microphone access
        this.localStream = await navigator.mediaDevices.getUserMedia({
          audio: {
            sampleRate: 16000,
            channelCount: 1,
            echoCancellation: true,
            noiseSuppression: true,
          },
        });

        // Add local audio track
        this.localStream.getTracks().forEach((track) => {
          this.pc.addTrack(track, this.localStream);
        });

        // Set remote description (server's offer)
        await this.pc.setRemoteDescription(
          new RTCSessionDescription({ sdp, type })
        );

        // Create and send answer
        const answer = await this.pc.createAnswer();
        await this.pc.setLocalDescription(answer);

        this.pushEvent("rtc_answer", {
          sdp: answer.sdp,
          type: answer.type,
        });
      } catch (error) {
        console.error("WebRTC setup error:", error);
      }
    });

    // Handle ICE candidates from server
    this.handleEvent("rtc_ice_candidate", async (data) => {
      if (this.pc) {
        try {
          await this.pc.addIceCandidate(
            new RTCIceCandidate({
              candidate: data.candidate,
              sdpMid: data.sdpMid,
              sdpMLineIndex: data.sdpMLineIndex,
            })
          );
        } catch (error) {
          console.error("Error adding ICE candidate:", error);
        }
      }
    });

    // Handle close from server
    this.handleEvent("rtc_close", () => {
      this.cleanup();
    });
  },

  destroyed() {
    this.cleanup();
  },

  cleanup() {
    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => track.stop());
      this.localStream = null;
    }

    if (this.pc) {
      this.pc.close();
      this.pc = null;
    }

    const remoteAudio = document.getElementById("remote-audio");
    if (remoteAudio) {
      remoteAudio.remove();
    }
  },
};

export default WebRTCHook;
