%% main_generate_dataset.m
% 生成舰船辐射噪声仿真数据集。
%
% 输出：
%   dataset_root/
%       manifest.csv
%       underwater_target/wav/*.wav, json/*.json
%       fishing_boat/wav/*.wav, json/*.json
%       cargo_ship/wav/*.wav, json/*.json
%       cruise_ship/wav/*.wav, json/*.json
%       warship/wav/*.wav, json/*.json
%
% 每条 wav 对应一个 json。json 直接写为 metadata_schema_v1 格式，
% 同时在 original_metadata 中保留原始舰船辐射噪声生成参数。
%
% 注意：默认每类生成 16000 条，总计 80000 条。为了先测试程序，
% 可以把 num_each_class 改成较小数值，例如 10。

clear; clc;

%% Parse command-line argument for parallel job filtering
args = argv();
target_class = '';
if numel(args) > 1
    target_class = args{2};
end
if ~isempty(target_class)
    fprintf('Filtering for class: %s\n', target_class);
end

%% ===================== 用户可改参数 =====================
base_seed = 20260613;            % 每个样本由该种子派生独立随机种子
fs = 16000;                     % 采样率
duration_range_sec = [10, 30];  % 每条信号时长独立均匀随机，秒
num_each_class = 16000;         % 每类数量

dataset_root = fullfile(pwd, 'ship_radiated_noise_dataset_toSZ');

% 是否额外保存未缩放的内部仿真分量 MAT；不生成 clean/noise WAV。
save_components = false;
wav_scale = 1e-5;               % 全数据集统一缩放，保持样本间绝对幅值关系
wav_bits_per_sample = 32;        % 降低固定缩放后的小信号量化误差

%% ===================== 初始化 =====================
if ~exist(dataset_root, 'dir')
    mkdir(dataset_root);
end

configs = get_ship_configs();
class_names = fieldnames(configs);

manifest_path = fullfile(dataset_root, 'manifest.csv');
manifest_header = [ ...
    'key,class_name,class_name_zh,wav_path,json_path,' ...
    'fs,duration_sec,SPL1K_db,blade_number,shaft_freq_hz,blade_freq_hz,' ...
    'tx_depth_m,rx_depth_m,distance_km,num_lines,mean_design_line_snr_db,mean_measured_line_snr_db'];

manifest_keys = read_manifest_keys(manifest_path);
manifest_info = dir(manifest_path);
manifest_exists = ~isempty(manifest_info) && manifest_info.bytes > 0;
if manifest_exists
    manifest_fid = fopen(manifest_path, 'a', 'n', 'UTF-8');
else
    manifest_fid = fopen(manifest_path, 'w', 'n', 'UTF-8');
end
if manifest_fid < 0
    error('Cannot create manifest: %s', manifest_path);
end
manifest_cleanup = onCleanup(@() fclose(manifest_fid));

if ~manifest_exists
    fprintf(manifest_fid, '%s\n', manifest_header);
end

fprintf('Dataset root: %s\n', dataset_root);
fprintf('Each class count: %d\n', num_each_class);
fprintf('Total expected count: %d\n', num_each_class * numel(class_names));
fprintf('Resume mode: completed WAV+JSON pairs will be skipped.\n');

%% ===================== 主循环 =====================
% Filter by command-line argument if specified
if ~isempty(target_class)
    if ~ismember(target_class, class_names)
        error('Unknown class: %s. Available: %s', target_class, strjoin(class_names, ', '));
    end
    class_names = {target_class};
end

for ci = 1:numel(class_names)
    class_name = class_names{ci};
    cfg = configs.(class_name);

    class_dir = fullfile(dataset_root, class_name);
    wav_dir = fullfile(class_dir, 'wav');
    json_dir = fullfile(class_dir, 'json');
    comp_dir = fullfile(class_dir, 'components');

    ensure_dir(class_dir);
    ensure_dir(wav_dir);
    ensure_dir(json_dir);
    if save_components
        ensure_dir(comp_dir);
    end

    fprintf('\nGenerating class: %s (%s)\n', class_name, cfg.displayNameZh);

    for idx = 1:num_each_class
        key = sprintf('%s_%06d', class_name, idx);
        wav_name = [key, '.wav'];
        json_name = [key, '.json'];

        wav_path = fullfile(wav_dir, wav_name);
        json_path = fullfile(json_dir, json_name);
        wav_rel_path = strrep(fullfile(class_name, 'wav', wav_name), filesep, '/');
        json_rel_path = strrep(fullfile(class_name, 'json', json_name), filesep, '/');

        if is_sample_complete(wav_path, json_path)
            meta = jsondecode(fileread(json_path));
        else
            sample_seed = base_seed + (ci - 1) * num_each_class + idx;
            try
                rng(sample_seed, 'twister');
            catch
                rand('seed', sample_seed);
                randn('seed', sample_seed);
            end

            sample_duration_sec = rand_uniform(duration_range_sec);
            [x, meta, components] = gen_ship_sample( ...
                fs, sample_duration_sec, class_name, cfg, idx);

            meta.random_seed = sample_seed;
            meta.wav_storage.scale_to_pcm = wav_scale;
            meta.wav_storage.bits_per_sample = wav_bits_per_sample;
            meta.wav_storage.restore_physical_amplitude = ...
                'physical_signal = audioread(wav_path) / scale_to_pcm';
            meta.wav_storage.saved_signal = ...
                'mixture only: bg_modulated + line_sig';

            write_scaled_wav( ...
                wav_path, x, fs, wav_scale, wav_bits_per_sample);
            meta = ship_metadata_to_schema_v1(meta, key, wav_path);
            write_json(json_path, meta);

            if save_components
                save(fullfile(comp_dir, [key, '_components.mat']), '-struct', 'components');
            end
        end

        if ~isKey(manifest_keys, key)
            append_manifest_row( ...
                manifest_fid, key, class_name, cfg.displayNameZh, ...
                wav_rel_path, json_rel_path, meta);
            manifest_keys(key) = true;
        end

        if mod(idx, 500) == 0 || idx == num_each_class
            fprintf('%s: %d / %d\n', class_name, idx, num_each_class);
        end
    end
end

clear manifest_cleanup;

fprintf('\n========== DONE ==========' );
fprintf('\nDataset root: %s', dataset_root);
fprintf('\nManifest: %s\n', manifest_path);
