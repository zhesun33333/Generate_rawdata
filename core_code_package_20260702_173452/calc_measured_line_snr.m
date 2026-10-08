function snr_db = calc_measured_line_snr(bg_sig, line_sig, fs, line_freqs, cfg)
%CALC_MEASURED_LINE_SNR 自动估计每根线谱的实测局部谱级 SNR。
%
% 定义：
%   measured_line_snr_db = 10log10(P_line / P_bg_local)
%
% 其中：
%   P_line     为 line_sig 在中心频率附近最接近频点的功率；
%   P_bg_local 为 bg_sig 在中心频率 +/- local_band_hz 范围内，
%              挖空 +/- exclude_hz 后的平均背景功率。
% 最终结果按矩形窗的等效噪声带宽换算到 1 Hz 参考带宽。
%
% 默认使用：
%   local_band_hz = 0.5
%   exclude_hz = 0.1
%   nfft = 65536

nfft = cfg.nfft;
local_band_hz = cfg.local_band_hz;
exclude_hz = cfg.exclude_hz;

N = length(bg_sig);
win = ones(N, 1);
enbw_hz = fs * sum(win.^2) / sum(win)^2;
reference_bandwidth_hz = 1.0;
bandwidth_correction_db = 10 * log10(enbw_hz / reference_bandwidth_hz);

bg_sig = bg_sig(:) - mean(bg_sig);
line_sig = line_sig(:) - mean(line_sig);

bg_fft = fft(bg_sig .* win, nfft);
line_fft = fft(line_sig .* win, nfft);

P_bg = abs(bg_fft(1:nfft/2+1)).^2 / N;
P_line = abs(line_fft(1:nfft/2+1)).^2 / N;

freq_axis = (0:nfft/2)' * fs / nfft;

num_lines = numel(line_freqs);
snr_db = zeros(1, num_lines);

for k = 1:num_lines
    f0 = line_freqs(k);

    [~, center_bin] = min(abs(freq_axis - f0));
    line_power = P_line(center_bin);

    dist_hz = abs(freq_axis - f0);
    noise_idx = dist_hz <= local_band_hz & dist_hz >= exclude_hz;
    noise_idx(center_bin) = false;

    if ~any(noise_idx)
        snr_db(k) = NaN;
        continue;
    end

    bg_power_mean = mean(P_bg(noise_idx));
    raw_bin_snr_db = 10 * log10( ...
        (line_power + eps) / (bg_power_mean + eps));
    snr_db(k) = raw_bin_snr_db + bandwidth_correction_db;
end

end
