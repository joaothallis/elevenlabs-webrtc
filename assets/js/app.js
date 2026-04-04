import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

import WebRTCHook from "./hooks/webrtc_hook";
import AudioPreviewHook from "./hooks/audio_preview_hook";

let Hooks = {
  WebRTCHook,
  AudioPreviewHook,
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
