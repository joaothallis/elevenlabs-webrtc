/**
 * LiveView Hook for managing ElevenLabs WebRTC conversations.
 *
 * This hook handles:
 * - Fetching WebRTC tokens from the server
 * - Starting/stopping conversations via the ElevenLabs client SDK
 * - Relaying conversation events back to the LiveView process
 *
 * Uses the ElevenLabs Conversation API which internally manages
 * WebRTC peer connections to their LiveKit infrastructure.
 */
const Conversation = {
  mounted() {
    this.conversation = null;

    const startBtn = this.el.querySelector("#start-btn");
    const stopBtn = this.el.querySelector("#stop-btn");

    startBtn.addEventListener("click", () => this.startCall());
    stopBtn.addEventListener("click", () => this.stopCall());

    // Cleanup on navigation
    this.handleEvent("phx:page-loading-stop", () => {
      if (this.conversation) {
        this.conversation.endSession();
        this.conversation = null;
      }
    });
  },

  destroyed() {
    if (this.conversation) {
      this.conversation.endSession();
      this.conversation = null;
    }
  },

  async startCall() {
    const startBtn = this.el.querySelector("#start-btn");
    const stopBtn = this.el.querySelector("#stop-btn");
    const agentId = startBtn.dataset.agentId;

    if (!agentId) {
      this.pushEvent("conversation_log", { message: "No agent selected" });
      return;
    }

    startBtn.disabled = true;
    stopBtn.disabled = true;
    this.pushEvent("conversation_status", { status: "requesting token" });

    try {
      // Fetch WebRTC token from our Phoenix server
      const tokenResp = await fetch("/api/webrtc-token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ agentId }),
      });

      if (!tokenResp.ok) {
        const err = await tokenResp.json().catch(() => ({}));
        throw new Error(err.error || "Failed to retrieve WebRTC token");
      }

      const { token } = await tokenResp.json();
      if (!token) throw new Error("Server did not return a token");

      this.pushEvent("conversation_log", { message: "Fetched WebRTC token" });
      this.pushEvent("conversation_status", { status: "connecting via WebRTC" });

      // Dynamically import the ElevenLabs client
      const { Conversation: ELConversation } = await import(
        "https://cdn.jsdelivr.net/npm/@elevenlabs/client@latest/+esm"
      );

      this.conversation = await ELConversation.startSession({
        conversationToken: token,
        onConnect: () => {
          this.pushEvent("conversation_log", { message: "WebRTC connected" });
          this.pushEvent("conversation_status", { status: "connected" });
          stopBtn.disabled = false;
        },
        onDisconnect: (details) => {
          this.pushEvent("conversation_log", {
            message: `Disconnected: ${details?.reason || "unknown reason"}`,
          });
          this.pushEvent("conversation_status", { status: "disconnected" });
          this.conversation = null;
          startBtn.disabled = false;
          stopBtn.disabled = true;
        },
        onMessage: (message) => {
          if (message.type === "agent_response") {
            this.pushEvent("conversation_log", {
              message: `Agent: ${message.message}`,
            });
          } else if (message.type === "user_transcript") {
            this.pushEvent("conversation_log", {
              message: `You: ${message.message}`,
            });
          } else if (message.type === "interruption") {
            this.pushEvent("conversation_log", {
              message: "Interruption detected",
            });
          } else if (message.type === "error") {
            this.pushEvent("conversation_log", {
              message: `Error: ${message.message || "Unknown error"}`,
            });
          }
        },
        onError: (error) => {
          this.pushEvent("conversation_log", {
            message: `Error: ${error.message || "Unknown error"}`,
          });
          console.error("Conversation error:", error);
        },
        onModeChange: (mode) => {
          this.pushEvent("conversation_log", {
            message: `Mode: ${mode.mode}`,
          });
        },
        onStatusChange: (status) => {
          this.pushEvent("conversation_log", {
            message: `Status: ${status.status}`,
          });
        },
      });

      this.pushEvent("conversation_log", {
        message: `Conversation started: ${this.conversation.getId()}`,
      });
    } catch (error) {
      this.pushEvent("conversation_log", {
        message: `Error: ${error.message}`,
      });
      this.pushEvent("conversation_status", { status: "error" });
      this.conversation = null;
      startBtn.disabled = false;
      stopBtn.disabled = true;
    }
  },

  async stopCall() {
    const startBtn = this.el.querySelector("#start-btn");
    const stopBtn = this.el.querySelector("#stop-btn");

    stopBtn.disabled = true;
    this.pushEvent("conversation_status", { status: "disconnecting" });

    if (this.conversation) {
      try {
        await this.conversation.endSession();
      } catch (error) {
        console.error("Error ending session:", error);
      }
      this.conversation = null;
    }

    this.pushEvent("conversation_log", { message: "Conversation stopped" });
    this.pushEvent("conversation_status", { status: "idle" });
    startBtn.disabled = false;
  },
};

export default Conversation;
