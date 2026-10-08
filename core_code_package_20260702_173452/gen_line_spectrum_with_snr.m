function [line_sig, line_meta] = gen_line_spectrum_with_snr( ...
    fs, T, t, line_freqs, lineSNRRange, Pw1L, freq_axis, ...
    bg_sig, snr_eval_cfg, line_sources, line_harmonic_orders)
%GEN_LINE_SPECTRUM_WITH_SNR 生成线谱，并记录 design line-SNR ground truth。
%
% 先测量本条样本实际 bg_sig 的局部背景，再按照与最终评估完全
% 相同的矩形窗、FFT、局部频带和 1 Hz 带宽定义标定线谱幅值。
%
% 可选输入：
%   line_sources          每根线谱的来源：shaft_harmonic / blade_harmonic / random_mechanical
%   line_harmonic_orders  谐波阶数；随机机械线谱为 0

N = round(fs * T);
num_lines = numel(line_freqs);

if nargin < 10 || isempty(line_sources)
    line_sources = repmat({'random_mechanical'}, 1, num_lines);
end
if nargin < 11 || isempty(line_harmonic_orders)
    line_harmonic_orders = zeros(1, num_lines);
end

target_snr_db = zeros(1, num_lines);
phases = zeros(1, num_lines);
line_components = zeros(N, num_lines);

line_meta = struct( ...
    'frequency_hz', cell(1, num_lines), ...
    'source_type', cell(1, num_lines), ...
    'harmonic_order', cell(1, num_lines), ...
    'design_line_snr_db', cell(1, num_lines), ...
    'background_spl_db', cell(1, num_lines), ...
    'line_spl_db', cell(1, num_lines), ...
    'amplitude', cell(1, num_lines), ...
    'phase_rad', cell(1, num_lines), ...
    'measured_line_snr_db', cell(1, num_lines));

for k = 1:num_lines
    f0 = line_freqs(k);

    target_snr_db(k) = rand_uniform(lineSNRRange);
    phases(k) = 2*pi*rand;

    % 保留理论目标谱级，便于解释该频率所处的连续谱形状。
    bg_spl_db = interp1(freq_axis(:), Pw1L(:), f0, 'linear', 'extrap');
    line_spl_db = bg_spl_db + target_snr_db(k);

    % 单位幅值正弦，后续用实测 SNR 迭代标定其幅值。
    line_components(:, k) = cos(2*pi*f0*t + phases(k));

    line_meta(k).frequency_hz = f0;
    line_meta(k).source_type = line_sources{k};
    line_meta(k).harmonic_order = line_harmonic_orders(k);
    line_meta(k).design_line_snr_db = target_snr_db(k);
    line_meta(k).background_spl_db = bg_spl_db;
    line_meta(k).line_spl_db = line_spl_db;
    line_meta(k).amplitude = 1.0;
    line_meta(k).phase_rad = phases(k);
    line_meta(k).measured_line_snr_db = NaN;
end

% 先逐根获得幅值初值，避免其他线谱对初始标定造成影响。
for k = 1:num_lines
    measured_unit_db = calc_measured_line_snr( ...
        bg_sig, line_components(:, k), fs, line_freqs(k), snr_eval_cfg);
    amplitude_scale = 10^((target_snr_db(k) - measured_unit_db) / 20);
    line_components(:, k) = line_components(:, k) * amplitude_scale;
end

% 在全部线谱叠加后微调，补偿其他线谱的有限窗泄漏。
max_iterations = 8;
tolerance_db = 0.02;
for iteration = 1:max_iterations
    line_sig = sum(line_components, 2);
    measured_snr_db = calc_measured_line_snr( ...
        bg_sig, line_sig, fs, line_freqs, snr_eval_cfg);
    snr_error_db = target_snr_db - measured_snr_db;

    if max(abs(snr_error_db)) <= tolerance_db
        break;
    end

    for k = 1:num_lines
        line_components(:, k) = line_components(:, k) * ...
            10^(snr_error_db(k) / 20);
    end
end

line_sig = sum(line_components, 2);
for k = 1:num_lines
    line_meta(k).amplitude = max(abs(line_components(:, k)));
end

end
