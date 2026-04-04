/**
 * Audio Preview Hook for Phoenix LiveView
 *
 * Handles voice preview playback in the browser.
 */
const AudioPreviewHook = {
  mounted() {
    this.audio = null;

    this.handleEvent("play_preview", ({ url }) => {
      this.stopAudio();

      if (!url) return;

      this.audio = new Audio(url);

      this.audio.play().catch((error) => {
        console.error("Error playing preview:", error);
      });

      this.audio.onended = () => {
        this.audio = null;
      };
    });

    this.handleEvent("stop_preview", () => {
      this.stopAudio();
    });
  },

  destroyed() {
    this.stopAudio();
  },

  stopAudio() {
    if (this.audio) {
      this.audio.pause();
      this.audio = null;
    }
  },
};

export default AudioPreviewHook;
