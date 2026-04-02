defmodule ElevenlabsWebrtc.AudioCodec do
  @moduledoc """
  Audio codec conversion between Opus (WebRTC) and PCM (ElevenLabs).

  WebRTC audio uses Opus codec (48kHz), while the ElevenLabs WebSocket
  conversation API expects PCM 16-bit 16kHz mono audio.

  ## Production Setup

  For full codec conversion, add `xav` (Elixir FFmpeg wrapper from the
  elixir-webrtc team) to your dependencies:

      {:xav, "~> 0.7"}

  Then implement the conversion using:

      # Opus -> PCM
      {:ok, decoder} = Xav.Decoder.new(:opus)
      {:ok, frame} = Xav.Decoder.decode(decoder, opus_data)
      pcm_data = frame.data

      # PCM -> Opus
      {:ok, encoder} = Xav.Encoder.new(:opus, ...)
      {:ok, packet} = Xav.Encoder.encode(encoder, pcm_frame)
      opus_data = packet.data

  Alternatively, use `membrane_opus_plugin` for a pipeline-based approach.

  ## Current Implementation

  Currently passes audio through with minimal conversion. The Opus frames
  from WebRTC are forwarded to ElevenLabs and vice versa. For correct audio,
  install xav and uncomment the conversion functions.
  """

  @doc """
  Convert Opus audio frame to PCM 16-bit 16kHz mono for ElevenLabs.

  In production, this should decode the Opus frame to PCM samples,
  then resample from 48kHz to 16kHz.
  """
  def opus_to_pcm(opus_data) when is_binary(opus_data) do
    # TODO: Replace with actual Opus decoding when xav is available:
    #
    #   state = get_decoder_state()
    #   {:ok, frame} = Xav.Decoder.decode(state.decoder, opus_data)
    #   pcm_48k = frame.data
    #   resample_48k_to_16k(pcm_48k)
    #
    # For now, pass through the raw audio data.
    # This will not produce correct audio without codec conversion.
    opus_data
  end

  @doc """
  Convert PCM 16-bit 16kHz mono audio to Opus for WebRTC.

  In production, this should resample from 16kHz to 48kHz,
  then encode as Opus.
  """
  def pcm_to_opus(pcm_data) when is_binary(pcm_data) do
    # TODO: Replace with actual Opus encoding when xav is available:
    #
    #   pcm_48k = resample_16k_to_48k(pcm_data)
    #   state = get_encoder_state()
    #   {:ok, packet} = Xav.Encoder.encode(state.encoder, pcm_48k)
    #   packet.data
    #
    # For now, pass through the raw audio data.
    # This will not produce correct audio without codec conversion.
    pcm_data
  end

  @doc """
  Resample PCM audio from 48kHz to 16kHz (simple decimation).
  Takes every 3rd sample for 3:1 downsampling.
  """
  def resample_48k_to_16k(pcm_48k) when is_binary(pcm_48k) do
    # PCM 16-bit = 2 bytes per sample
    # Take every 3rd sample (48000/16000 = 3)
    pcm_48k
    |> :binary.bin_to_list()
    |> Enum.chunk_every(2)
    |> Enum.take_every(3)
    |> Enum.flat_map(& &1)
    |> :binary.list_to_bin()
  end

  @doc """
  Resample PCM audio from 16kHz to 48kHz (simple interpolation).
  Triplicates each sample for 1:3 upsampling.
  """
  def resample_16k_to_48k(pcm_16k) when is_binary(pcm_16k) do
    # PCM 16-bit = 2 bytes per sample
    # Repeat each sample 3 times (16000*3 = 48000)
    for <<sample::binary-size(2) <- pcm_16k>>, into: <<>> do
      <<sample::binary, sample::binary, sample::binary>>
    end
  end
end
