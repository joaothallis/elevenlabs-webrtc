import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

import Conversation from "./hooks/conversation";
import { VoicePreview, VoicePreviewUrl } from "./hooks/voice_preview";

let Hooks = {
  Conversation,
  VoicePreview,
  VoicePreviewUrl,
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

liveSocket.connect();

window.liveSocket = liveSocket;
