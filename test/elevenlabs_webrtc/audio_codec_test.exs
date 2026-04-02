defmodule ElevenlabsWebrtc.AudioCodecTest do
  use ExUnit.Case, async: true

  alias ElevenlabsWebrtc.AudioCodec

  describe "opus_to_pcm/1" do
    test "accepts binary data" do
      assert is_binary(AudioCodec.opus_to_pcm(<<1, 2, 3, 4>>))
    end

    test "returns binary output" do
      result = AudioCodec.opus_to_pcm(<<0, 0, 0, 0>>)
      assert is_binary(result)
    end
  end

  describe "pcm_to_opus/1" do
    test "accepts binary data" do
      assert is_binary(AudioCodec.pcm_to_opus(<<1, 2, 3, 4>>))
    end

    test "returns binary output" do
      result = AudioCodec.pcm_to_opus(<<0, 0, 0, 0>>)
      assert is_binary(result)
    end
  end

  describe "resample_48k_to_16k/1" do
    test "reduces sample count by factor of 3" do
      # 6 samples at 16-bit (12 bytes) -> 2 samples (4 bytes)
      input = <<1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0>>
      result = AudioCodec.resample_48k_to_16k(input)
      # Takes every 3rd sample: sample 1 and sample 4
      assert byte_size(result) == 4
    end

    test "handles empty input" do
      assert AudioCodec.resample_48k_to_16k(<<>>) == <<>>
    end

    test "preserves 16-bit sample alignment" do
      # 9 samples (18 bytes) -> 3 samples (6 bytes)
      input = <<1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0, 9, 0>>
      result = AudioCodec.resample_48k_to_16k(input)
      assert byte_size(result) == 6
    end
  end

  describe "resample_16k_to_48k/1" do
    test "increases sample count by factor of 3" do
      # 2 samples (4 bytes) -> 6 samples (12 bytes)
      input = <<1, 0, 2, 0>>
      result = AudioCodec.resample_16k_to_48k(input)
      assert byte_size(result) == 12
    end

    test "triplicates each sample" do
      input = <<0xAA, 0xBB>>
      result = AudioCodec.resample_16k_to_48k(input)
      assert result == <<0xAA, 0xBB, 0xAA, 0xBB, 0xAA, 0xBB>>
    end

    test "handles empty input" do
      assert AudioCodec.resample_16k_to_48k(<<>>) == <<>>
    end

    test "roundtrip preserves sample count" do
      # 3 samples at 16kHz -> 9 at 48kHz -> 3 at 16kHz
      input = <<1, 0, 2, 0, 3, 0>>
      result = input |> AudioCodec.resample_16k_to_48k() |> AudioCodec.resample_48k_to_16k()
      assert byte_size(result) == byte_size(input)
    end
  end
end
