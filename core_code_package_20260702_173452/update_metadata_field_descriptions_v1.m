function report = update_metadata_field_descriptions_v1(dataset_root, max_files)
%UPDATE_METADATA_FIELD_DESCRIPTIONS_V1 Replace JSON field descriptions with schema v1 descriptions.
%
% Usage:
%   update_metadata_field_descriptions_v1()
%   update_metadata_field_descriptions_v1(dataset_root)
%   update_metadata_field_descriptions_v1(dataset_root, max_files)
%
% This updates all converted metadata JSON files in-place:
%   1) top-level field_descriptions is replaced with schema v1 descriptions
%   2) original_metadata.field_descriptions is removed to avoid relying on
%      the old metadata description block

if nargin < 1 || isempty(dataset_root)
    dataset_root = fullfile(pwd, 'ship_radiated_noise_dataset_toSZ');
end
if nargin < 2 || isempty(max_files)
    max_files = inf;
end

json_files = dir(fullfile(dataset_root, '*', 'json', '*.json'));
if isempty(json_files)
    error('No metadata JSON files found under: %s', dataset_root);
end

desc = get_schema_v1_field_descriptions();

report.total_seen = numel(json_files);
report.updated = 0;
report.failed = 0;
report.failures = {};

fprintf('Dataset root: %s\n', dataset_root);
fprintf('JSON files found: %d\n', numel(json_files));

for i = 1:numel(json_files)
    if report.updated >= max_files
        break;
    end

    json_path = fullfile(json_files(i).folder, json_files(i).name);
    try
        meta = jsondecode(fileread(json_path));
        meta.field_descriptions = desc;

        if isfield(meta, 'original_metadata') && ...
                isfield(meta.original_metadata, 'field_descriptions')
            meta.original_metadata = rmfield(meta.original_metadata, 'field_descriptions');
        end

        write_json_utf8(json_path, meta);
        report.updated = report.updated + 1;

        if mod(report.updated, 1000) == 0
            fprintf('Updated %d files...\n', report.updated);
        end
    catch ME
        report.failed = report.failed + 1;
        report.failures{end+1, 1} = sprintf('%s: %s', json_path, ME.message); %#ok<AGROW>
    end
end

fprintf('\n========== field description update report ==========\n');
fprintf('Total JSON files seen: %d\n', report.total_seen);
fprintf('Updated: %d\n', report.updated);
fprintf('Failed: %d\n', report.failed);

if report.failed > 0
    fprintf('\nFirst failures:\n');
    for k = 1:min(10, numel(report.failures))
        fprintf('  %s\n', report.failures{k});
    end
end

end

function desc = get_schema_v1_field_descriptions()
desc = struct();
desc.id = '样本唯一编号，与音频和 JSON 文件主名一致，例如 cargo_ship_000001。';
desc.wav_path = '16 kHz 单通道 WAV 音频在数据集内部的相对路径。';
desc.has_target = '是否存在目标信号；本数据集均为 true。';
desc.signal_type = '信号主类型；本数据集为 SHIP，表示舰船/水下目标辐射噪声。';
desc.signal_category = '信号粗类别；SHIP 对应 radiated_noise。';
desc.sub_type = '信号子类型，由原始 class_name 映射得到；cruise 和 underwater_target 为扩展子类型。';
desc.signal_duration_s = '目标信号实际持续时间，单位 s；连续船噪样本中与 audio_duration_s 一致。';

desc.signal_params = struct();
desc.signal_params.ship_type = '舰船/目标子类型，与 sub_type 一致。';
desc.signal_params.original_class_name = '转换前原始类别英文名。';
desc.signal_params.class_name_zh = '转换前原始类别中文名。';
desc.signal_params.speed_kt = '航速，单位 kt；原始生成阶段未记录时为 null。';
desc.signal_params.blade_count = '螺旋桨桨叶数量。';
desc.signal_params.shaft_freq_hz = '螺旋桨轴频，单位 Hz。';
desc.signal_params.blade_freq_hz = '叶频，等于桨叶数乘以轴频，单位 Hz。';
desc.signal_params.shaft_mod_coeff = '轴频对应的幅度调制系数。';
desc.signal_params.blade_mod_coeff = '叶频对应的幅度调制系数。';
desc.signal_params.other_mod_freqs_hz = '其他机械幅度调制频率，单位 Hz；可能为标量或数组。';
desc.signal_params.other_mod_coeffs = '其他机械调制频率对应的幅度调制系数；可能为标量或数组。';
desc.signal_params.spl_1k_db = '1 kHz 处连续谱参考谱级，单位 dB。';
desc.signal_params.platform_freq_hz = '低频连续谱平台截止频率，单位 Hz。';
desc.signal_params.slope_db_per_octave = '平台截止频率以上连续谱随倍频程变化的斜率，单位 dB/oct。';
desc.signal_params.num_lines = '当前样本包含的线谱数量。';
desc.signal_params.line_frequency_range_hz = '允许生成线谱的频率范围，单位 Hz。';
desc.signal_params.line_snr_definition = '线谱局部 SNR 的定义。';
desc.signal_params.lines = '线谱明细数组；每个元素记录一根线谱的频率、来源、谐波阶数、幅度、相位和局部 SNR。';

desc.source_depth_m = '声源/发射器深度，单位 m；对应 geometry.tx_depth_m。';
desc.receiver_depth_m = '接收器深度，单位 m；对应 geometry.rx_depth_m。';
desc.water_depth_m = '水深，单位 m；原始生成阶段未记录时为 null。';
desc.range_m = '声源与接收器之间的水平距离，单位 m；对应 geometry.distance_km*1000。';
desc.ssp_source = struct();
desc.ssp_source.dataset = '声速剖面数据来源；原始生成阶段未记录时为 not_recorded。';
desc.ssp_source.latitude_deg = '声速剖面格点纬度，单位度；未记录时为 null。';
desc.ssp_source.longitude_deg = '声速剖面格点经度，单位度；未记录时为 null。';
desc.ssp_source.month = '声速剖面月份；未记录时为 null。';
desc.snr_after_mix_db = '合成后整体 SNR，单位 dB；由 WAV 混合信号减去重建线谱目标信号得到背景噪声后计算。';
desc.audio_duration_s = '最终 WAV 总时长，单位 s。';
desc.model_fs_hz = '模型输入采样率，单位 Hz；本数据集统一为 16000。';
desc.num_channels = '音频通道数；本数据集统一为 1。';

desc.geometry = struct();
desc.geometry.tx_depth_m = '声源/发射器深度，单位 m；每条样本独立随机生成。';
desc.geometry.rx_depth_m = '接收器深度，单位 m；每条样本独立随机生成。';
desc.geometry.distance_km = '声源与接收器之间的水平距离，单位 km；每条样本独立随机生成。';
desc.geometry.transmission_loss_db_for_record_only = '按球面扩展公式计算的记录用传播损失，单位 dB；当前未施加到波形。';
desc.geometry.range_m = '声源与接收器之间的水平距离，单位 m。';

desc.line_spectrum = struct();
desc.line_spectrum.num_lines = '当前样本包含的线谱数量。';
desc.line_spectrum.frequency_range_hz = '允许生成线谱的频率范围，单位 Hz。';
desc.line_spectrum.design_line_snr_range_db = '每根线谱预设局部 SNR 的随机取值范围，单位 dB。';
desc.line_spectrum.frequency_generation_rule = '物理关联线谱和随机机械线谱的频率生成规则。';
desc.line_spectrum.min_frequency_separation_hz = '任意两根线谱之间允许的最小频率间隔，单位 Hz。';
desc.line_spectrum.local_snr_definition = '预设线谱局部 SNR 的定义。';
desc.line_spectrum.measured_local_snr_definition = '实测线谱局部 SNR 的频谱计算方法。';
desc.line_spectrum.local_snr_band_hz = '估计局部连续谱背景时，以线频为中心的半带宽，单位 Hz。';
desc.line_spectrum.local_snr_exclude_hz = '估计背景时在线频中心两侧排除的半带宽，单位 Hz。';
desc.line_spectrum.measured_snr_reference_bandwidth_hz = '实测线谱局部 SNR 最终换算到的参考噪声带宽，单位 Hz。';
desc.line_spectrum.snr_analysis_window = '计算和标定线谱局部 SNR 使用的时间窗类型。';
desc.line_spectrum.snr_analysis_window_sec = '计算线谱局部 SNR 使用的时间窗长度，单位 s。';
desc.line_spectrum.snr_analysis_nfft = '线谱局部 SNR 分析使用的 FFT 点数。';
desc.line_spectrum.snr_analysis_enbw_hz = '线谱局部 SNR 分析窗的等效噪声带宽，单位 Hz。';
desc.line_spectrum.snr_time_gain_correction_db = '从分析窗带宽换算到 1 Hz 参考带宽时使用的修正量，单位 dB。';
desc.line_spectrum.lines = struct();
desc.line_spectrum.lines.frequency_hz = '该线谱的频率，单位 Hz。';
desc.line_spectrum.lines.source_type = '线谱来源类型，例如轴频谐波、叶频谐波或随机机械线谱。';
desc.line_spectrum.lines.harmonic_order = '物理关联线谱的谐波阶数；随机机械线谱为 0。';
desc.line_spectrum.lines.design_line_snr_db = '随机预设并用于幅值标定的线谱局部 SNR，单位 dB。';
desc.line_spectrum.lines.background_spl_db = '目标连续谱曲线在该线频处的理论背景谱级，单位 dB。';
desc.line_spectrum.lines.line_spl_db = '理论线谱谱级，等于理论背景谱级加预设局部 SNR，单位 dB。';
desc.line_spectrum.lines.amplitude = '按实际调制背景和统一线谱局部 SNR 测量方法标定后的时域正弦峰值幅度。';
desc.line_spectrum.lines.phase_rad = '线谱正弦信号的初始相位，单位 rad。';
desc.line_spectrum.lines.measured_line_snr_db = '生成后按矩形窗、局部背景频带和 1 Hz 参考带宽实测的线谱局部 SNR，单位 dB。';

desc.conversion_notes = 'metadata_schema_v1 转换说明，记录缺失字段、扩展子类型和 SNR 计算方法。';
end

function write_json_utf8(json_path, data)
try
    json_text = jsonencode(data, 'PrettyPrint', true);
catch
    json_text = jsonencode(data);
end

json_text = restore_schema_nulls(json_text);

fid = fopen(json_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('Cannot open json file: %s', json_path);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, json_text, 'char');
end

function json_text = restore_schema_nulls(json_text)
json_text = strrep(json_text, '"speed_kt": []', '"speed_kt": null');
json_text = strrep(json_text, '"water_depth_m": []', '"water_depth_m": null');
json_text = strrep(json_text, '"latitude_deg": []', '"latitude_deg": null');
json_text = strrep(json_text, '"longitude_deg": []', '"longitude_deg": null');
json_text = strrep(json_text, '"month": []', '"month": null');
end