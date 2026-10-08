function write_scaled_wav(wav_path, signal, fs, scale, bits_per_sample)
%WRITE_SCALED_WAV Apply a fixed dataset-wide scale and reject clipping.

signal_wav = double(signal(:)) * scale;

if any(~isfinite(signal_wav))
    error('WAV signal contains NaN or Inf: %s', wav_path);
end

peak = max(abs(signal_wav));
if peak > 0.99
    error(['WAV peak %.6f exceeds the 0.99 safety limit: %s\n' ...
        'Reduce the dataset-wide wav_scale; do not scale this sample separately.'], ...
        peak, wav_path);
end

if bits_per_sample ~= 32
    error('This writer currently requires 32-bit PCM output.');
end

pcm_max = double(intmax('int32'));
signal_pcm = int32(round(signal_wav * pcm_max));
audiowrite(wav_path, signal_pcm, fs, 'BitsPerSample', bits_per_sample);

end
