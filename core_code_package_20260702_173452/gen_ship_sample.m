function [x, meta, components] = gen_ship_sample(fs, T, class_name, cfg, index)
%GEN_SHIP_SAMPLE 生成一条舰船辐射噪声样本。
%
% 输出：
%   x          未做全局归一化的 wav 信号，保留仿真幅度关系
%   meta       json 元数据
%   components 可选保存的 clean 分量

N = round(fs * T);
t = (0:N-1)' / fs;
actual_duration_sec = N / fs;

%% ===================== 1. 随机基础参数 =====================
SPL1K = rand_uniform(cfg.SPL1KRange);
blade_num = cfg.bladeChoices(randi(numel(cfg.bladeChoices)));

tx_depth_m = rand_uniform(cfg.depthRange);
rx_depth_m = rand_uniform(cfg.depthRange);
distance_km = rand_uniform(cfg.distanceRangeKm);

shaft_freq_hz = rand_uniform(cfg.shaftFreqRange);
blade_freq_hz = blade_num * shaft_freq_hz;

% 轴频/叶频处调制系数最强，且满足阈值要求。
main_mod_coeff = rand_uniform([cfg.mainModMin, cfg.modRange(2)]);
shaft_mod_coeff = main_mod_coeff;
blade_mod_coeff = main_mod_coeff;

% 其他调制分量必须小于主调制系数。
num_other_mod = randi([1, 4]);
other_mod_freqs = rand_uniform_vec([1, 80], num_other_mod);
other_upper = min(main_mod_coeff * 0.85, cfg.modRange(2));
other_lower = cfg.modRange(1);
if other_upper <= other_lower
    other_lower = 0;
end
other_mod_coeffs = other_lower + (other_upper - other_lower) * rand(1, num_other_mod);

%% ===================== 2. 连续谱背景：300 Hz平台 + 6 dB/oct =====================
fc = 300;
ar_order = 32;
isWhite = false;

[bg, Pw1L, bg_power, freq_axis] = gen_colored_noise_6dboct( ...
    fs, T, SPL1K, ar_order, isWhite, fc);
bg = bg(:);

%% ===================== 3. 螺旋桨调制包络 =====================
% 对连续谱背景进行幅度调制，形成舰船机械调制特征。
env = ones(N, 1);
env = env + shaft_mod_coeff * cos(2*pi*shaft_freq_hz*t + 2*pi*rand);
env = env + blade_mod_coeff * cos(2*pi*blade_freq_hz*t + 2*pi*rand);
for k = 1:num_other_mod
    env = env + other_mod_coeffs(k) * cos(2*pi*other_mod_freqs(k)*t + 2*pi*rand);
end

% 防止包络为负。随后归一化到均值约为 1，避免整体能量剧烈漂移。
env = max(env, 0.05);
env = env / mean(env);
bg_modulated = bg .* env;

%% ===================== 4. 线谱：3-10根，部分绑定轴频/叶频/谐波 =====================
num_lines = randi([3, 10]);
min_sep_hz = 3.0;

% 为了增强物理关联，不再让所有线谱完全随机。
% 其中 1-3 根线谱来自轴频谐波、叶频及叶频谐波，其余线谱随机生成。
[line_freqs, line_sources, line_harmonic_orders] = gen_physically_coupled_line_freqs( ...
    cfg, num_lines, shaft_freq_hz, blade_freq_hz, blade_num, min_sep_hz);

snr_eval_cfg.nfft = 2^nextpow2(N);
snr_eval_cfg.local_band_hz = 0.5;
snr_eval_cfg.exclude_hz = 0.1;

[line_sig, line_meta] = gen_line_spectrum_with_snr( ...
    fs, T, t, line_freqs, cfg.lineSNRRange, Pw1L, freq_axis, ...
    bg_modulated, snr_eval_cfg, line_sources, line_harmonic_orders);

%% ===================== 5. 合成 =====================
x_raw = bg_modulated + line_sig;

% 不做全局归一化，保留 SPL1K、连续谱、线谱幅度之间的绝对幅度关系。
% 注意：若后续增加传播损失或更大谱级范围，写入 wav 前需检查是否超出 [-1, 1]。
x = x_raw;

%% ===================== 6. 自动计算 measured line-SNR ground truth =====================
measured_line_snr_db = calc_measured_line_snr( ...
    bg_modulated, line_sig, fs, line_freqs, snr_eval_cfg);

for k = 1:num_lines
    line_meta(k).measured_line_snr_db = measured_line_snr_db(k);
end

%% ===================== 7. 简单传播参数记录 =====================
% 当前版本只记录几何参数，不对信号施加传播损失。
% 原因：该数据集重点控制“局部谱级SNR”；当前几何参数用于元数据记录和后续传播模型扩展。
transmission_loss_db = 20 * log10(distance_km * 1000 + eps);

%% ===================== 8. metadata =====================
meta.index = index;
meta.class_name = class_name;
meta.class_name_zh = cfg.displayNameZh;
meta.fs = fs;
meta.duration_sec = actual_duration_sec;
meta.num_samples = N;
meta.normalization = 'none; waveform amplitude is not globally normalized';

meta.continuous_spectrum.SPL1K_db = SPL1K;
meta.continuous_spectrum.platform_freq_hz = fc;
meta.continuous_spectrum.slope_db_per_octave = -6;
meta.continuous_spectrum.ar_order = ar_order;
meta.continuous_spectrum.is_white_noise = isWhite;
meta.continuous_spectrum.background_power_before_modulation = bg_power;
meta.continuous_spectrum.description = ...
    'Below 300 Hz the spectrum is flat; above 300 Hz it decays at 6 dB per octave relative to the 1 kHz reference spectral level.';

meta.propeller.blade_number = blade_num;
meta.propeller.shaft_freq_hz = shaft_freq_hz;
meta.propeller.blade_freq_hz = blade_freq_hz;
meta.propeller.shaft_mod_coeff = shaft_mod_coeff;
meta.propeller.blade_mod_coeff = blade_mod_coeff;
meta.propeller.other_mod_freqs_hz = other_mod_freqs;
meta.propeller.other_mod_coeffs = other_mod_coeffs;
meta.propeller.modulation_rule = ...
    'The shaft frequency and blade frequency have the strongest modulation coefficients; all other modulation coefficients are smaller.';

meta.geometry.tx_depth_m = tx_depth_m;
meta.geometry.rx_depth_m = rx_depth_m;
meta.geometry.distance_km = distance_km;
meta.geometry.transmission_loss_db_for_record_only = transmission_loss_db;

meta.line_spectrum.num_lines = num_lines;
meta.line_spectrum.frequency_range_hz = cfg.lineFreqRange;
meta.line_spectrum.design_line_snr_range_db = cfg.lineSNRRange;
meta.line_spectrum.frequency_generation_rule = ...
    'A subset of line spectra is physically coupled to shaft-frequency harmonics, blade frequency, and blade-frequency harmonics; the remaining lines are random mechanical tonal components.';
meta.line_spectrum.min_frequency_separation_hz = min_sep_hz;
meta.line_spectrum.local_snr_definition = ...
    'line spectral level minus local continuous-spectrum level at the same frequency';
meta.line_spectrum.measured_local_snr_definition = ...
    ['center line-bin power divided by the average background power within ' ...
    '+/-0.5 Hz excluding +/-0.1 Hz, corrected from the rectangular-window ENBW ' ...
    'to a 1 Hz reference noise bandwidth'];
meta.line_spectrum.local_snr_band_hz = snr_eval_cfg.local_band_hz;
meta.line_spectrum.local_snr_exclude_hz = snr_eval_cfg.exclude_hz;
meta.line_spectrum.measured_snr_reference_bandwidth_hz = 1.0;
snr_window = ones(N, 1);
snr_enbw_hz = fs * sum(snr_window.^2) / sum(snr_window)^2;
meta.line_spectrum.snr_analysis_window = 'rectangular';
meta.line_spectrum.snr_analysis_window_sec = actual_duration_sec;
meta.line_spectrum.snr_analysis_nfft = snr_eval_cfg.nfft;
meta.line_spectrum.snr_analysis_enbw_hz = snr_enbw_hz;
meta.line_spectrum.snr_time_gain_correction_db = 10 * log10(snr_enbw_hz);
meta.line_spectrum.lines = line_meta;

%% ===================== 9. components =====================
components.x_raw = x_raw;
components.bg = bg;
components.bg_modulated = bg_modulated;
components.line_sig = line_sig;
components.env = env;
components.freq_axis = freq_axis;
components.Pw1L = Pw1L;

end
