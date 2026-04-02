/**
 * LiveView Hook for voice preview playback.
 * Fetches the preview URL from the voices API and plays audio.
 */

let currentAudio = null;

function stopAllPreviews() {
  if (currentAudio) {
    currentAudio.pause();
    currentAudio = null;
  }
  document.querySelectorAll(".btn-preview, .btn-preview-lib").forEach((btn) => {
    btn.classList.remove("playing");
    btn.innerHTML = "&#9654;";
  });
}

/**
 * VoicePreview hook - plays preview for a voice selected in a <select>.
 * Reads `data-select` attribute to find the target select element.
 */
const VoicePreview = {
  mounted() {
    this.el.addEventListener("click", () => {
      const selectId = this.el.dataset.select;
      const select = document.getElementById(selectId);
      if (!select || !select.value) return;

      stopAllPreviews();

      // Fetch voices to get preview URL
      fetch("/api/voices")
        .then((r) => r.json())
        .then(({ voices }) => {
          const voice = voices.find((v) => v.voice_id === select.value);
          if (!voice || !voice.preview_url) {
            alert("No preview available for this voice");
            return;
          }

          currentAudio = new Audio(voice.preview_url);
          this.el.classList.add("playing");
          this.el.innerHTML = "&#9632;";

          currentAudio.play().catch(() => {
            this.el.classList.remove("playing");
            this.el.innerHTML = "&#9654;";
          });

          currentAudio.onended = () => {
            this.el.classList.remove("playing");
            this.el.innerHTML = "&#9654;";
            currentAudio = null;
          };
        });
    });
  },
};

/**
 * VoicePreviewUrl hook - plays preview from a direct URL.
 * Reads `data-url` attribute for the audio URL.
 */
const VoicePreviewUrl = {
  mounted() {
    this.el.addEventListener("click", () => {
      stopAllPreviews();

      const url = this.el.dataset.url;
      if (!url) {
        alert("No preview available for this voice");
        return;
      }

      currentAudio = new Audio(url);
      this.el.classList.add("playing");
      this.el.innerHTML = "&#9632;";

      currentAudio.play().catch(() => {
        this.el.classList.remove("playing");
        this.el.innerHTML = "&#9654;";
      });

      currentAudio.onended = () => {
        this.el.classList.remove("playing");
        this.el.innerHTML = "&#9654;";
        currentAudio = null;
      };
    });
  },
};

export { VoicePreview, VoicePreviewUrl };
