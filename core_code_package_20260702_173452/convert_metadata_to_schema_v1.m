function report = convert_metadata_to_schema_v1(dataset_root, max_files)
%CONVERT_METADATA_TO_SCHEMA_V1 Convert existing metadata JSON files to schema v1.
%
% Usage:
%   convert_metadata_to_schema_v1()
%   convert_metadata_to_schema_v1(dataset_root)
%   convert_metadata_to_schema_v1(dataset_root, max_files)
%
% The conversion is in-place. The original detailed metadata is preserved
% under original_metadata so that no generation parameters are lost.

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

report.total_seen = numel(json_files);
report.converted = 0;
report.skipped_already_v1 = 0;
report.failed = 0;
report.missing_water_depth_m = 0;
report.missing_ssp_source = 0;
report.nonstandard_sub_type = containers.Map('KeyType', 'char', 'ValueType', 'double');
report.failures = {};

fprintf('Dataset root: %s\n', dataset_root);
fprintf('JSON files found: %d\n', numel(json_files));

for i = 1:numel(json_files)
    if report.converted >= max_files
        break;
    end

    json_path = fullfile(json_files(i).folder, json_files(i).name);
    try
        loaded = jsondecode(fileread(json_path));

        if isfield(loaded, 'original_metadata')
            old = loaded.original_metadata;
        else
            old = loaded;
        end

        if isfield(loaded, 'id') && isfield(loaded, 'signal_type') && ...
                isfield(loaded, 'signal_params') && ...
                isfield(loaded, 'snr_after_mix_db') && ...
                isfield(loaded, 'line_spectrum') && ...
                isfield(loaded, 'geometry')
            report.skipped_already_v1 = report.skipped_already_v1 + 1;
            continue;
        end

        [~, key] = fileparts(json_files(i).name);
        class_name = old.class_name;
        sub_type = class_to_sub_type(class_name);

        wav_rel = strrep(fullfile(class_name, 'wav', [key, '.wav']), filesep, '/');

        new = struct();
        new.id = key;
        new.wav_path = wav_rel;
        new.has_target = true;
        new.signal_type = 'SHIP';
        new.signal_category = 'radiated_noise';
        new.sub_type = sub_type;
        new.signal_duration_s = old.duration_sec;
        new.signal_params = build_signal_params(old, class_name, sub_type);

        new.source_depth_m = old.geometry.tx_depth_m;
        new.receiver_depth_m = old.geometry.rx_depth_m;
        new.water_depth_m = NaN;
        new.range_m = old.geometry.distance_km * 1000;
        new.ssp_source = struct( ...
            'dataset', 'not_recorded', ...
            'latitude_deg', NaN, ...
            'longitude_deg', NaN, ...
            'month', NaN);

        wav_abs = fullfile(dataset_root, class_name, 'wav', [key, '.wav']);
        [snr_after_mix_db, snr_method] = compute_after_mix_snr_db(wav_abs, old);
        new.snr_after_mix_db = snr_after_mix_db;
        new.audio_duration_s = old.duration_sec;
        new.model_fs_hz = old.fs;
        new.num_channels = 1;
        new.geometry = old.geometry;
        new.geometry.range_m = new.range_m;
        new.line_spectrum = old.line_spectrum;

        new.conversion_notes = struct();
        new.conversion_notes.source_schema = 'original_ship_radiated_noise_metadata';
        new.conversion_notes.target_schema = 'metadata_schema_v1';
        new.conversion_notes.water_depth_m = ...
            'not recorded in original metadata; encoded as JSON null';
        new.conversion_notes.ssp_source = ...
            'not recorded in original metadata; dataset is not_recorded and numeric fields are JSON null';
        new.conversion_notes.snr_after_mix_db = snr_method;
        new.conversion_notes.line_spectrum = ...
            'original line_spectrum is preserved, including lines[].measured_line_snr_db';
        new.conversion_notes.geometry = ...
            'original geometry is preserved; source_depth_m/receiver_depth_m/range_m are schema aliases of tx_depth_m/rx_depth_m/distance_km*1000';
        new.conversion_notes.sub_type = ...
            'derived from original class_name; cruise_ship and underwater_target are outside the schema examples but preserved truthfully';

        new.original_metadata = old;

        write_json_utf8(json_path, new);

        report.converted = report.converted + 1;
        report.missing_water_depth_m = report.missing_water_depth_m + 1;
        report.missing_ssp_source = report.missing_ssp_source + 1;

        if ismember(sub_type, {'cruise', 'underwater_target'})
            if ~isKey(report.nonstandard_sub_type, sub_type)
                report.nonstandard_sub_type(sub_type) = 0;
            end
            report.nonstandard_sub_type(sub_type) = report.nonstandard_sub_type(sub_type) + 1;
        end

        if mod(report.converted, 1000) == 0
            fprintf('Converted %d files...\n', report.converted);
        end
    catch ME
        report.failed = report.failed + 1;
        report.failures{end+1, 1} = sprintf('%s: %s', json_path, ME.message); %#ok<AGROW>
    end
end

fprintf('\n========== conversion report ==========\n');
fprintf('Total JSON files seen: %d\n', report.total_seen);
fprintf('Converted: %d\n', report.converted);
fprintf('Skipped already v1: %d\n', report.skipped_already_v1);
fprintf('Failed: %d\n', report.failed);
fprintf('Missing water_depth_m encoded as null: %d\n', report.missing_water_depth_m);
fprintf('Missing ssp_source encoded as not_recorded/null: %d\n', report.missing_ssp_source);
print_nonstandard_subtypes(report.nonstandard_sub_type);

if report.failed > 0
    fprintf('\nFirst failures:\n');
    for k = 1:min(10, numel(report.failures))
        fprintf('  %s\n', report.failures{k});
    end
end

end

function signal_params = build_signal_params(old, class_name, sub_type)
signal_params = struct();
signal_params.ship_type = sub_type;
signal_params.original_class_name = class_name;
signal_params.class_name_zh = old.class_name_zh;
signal_params.speed_kt = NaN;
signal_params.blade_count = old.propeller.blade_number;
signal_params.shaft_freq_hz = old.propeller.shaft_freq_hz;
signal_params.blade_freq_hz = old.propeller.blade_freq_hz;
signal_params.shaft_mod_coeff = old.propeller.shaft_mod_coeff;
signal_params.blade_mod_coeff = old.propeller.blade_mod_coeff;
signal_params.other_mod_freqs_hz = old.propeller.other_mod_freqs_hz;
signal_params.other_mod_coeffs = old.propeller.other_mod_coeffs;
signal_params.spl_1k_db = old.continuous_spectrum.SPL1K_db;
signal_params.platform_freq_hz = old.continuous_spectrum.platform_freq_hz;
signal_params.slope_db_per_octave = old.continuous_spectrum.slope_db_per_octave;
signal_params.num_lines = old.line_spectrum.num_lines;
signal_params.line_frequency_range_hz = old.line_spectrum.frequency_range_hz;
signal_params.line_snr_definition = old.line_spectrum.local_snr_definition;
signal_params.lines = old.line_spectrum.lines;
end

function sub_type = class_to_sub_type(class_name)
switch class_name
    case 'cargo_ship'
        sub_type = 'cargo';
    case 'fishing_boat'
        sub_type = 'fishing';
    case 'warship'
        sub_type = 'warship';
    case 'cruise_ship'
        sub_type = 'cruise';
    case 'underwater_target'
        sub_type = 'underwater_target';
    otherwise
        sub_type = class_name;
end
end

function [snr_db, method] = compute_after_mix_snr_db(wav_abs, old)
snr_db = NaN;
method = ['global SNR computed as 10*log10(mean(line_sig.^2)/mean(noise.^2)); ' ...
    'line_sig reconstructed from line_spectrum.lines frequency/amplitude/phase; ' ...
    'noise reconstructed as physical WAV mixture minus line_sig'];

if ~exist(wav_abs, 'file')
    method = [method, '; WAV file missing, encoded as JSON null'];
    return;
end
if ~isfield(old, 'line_spectrum') || ~isfield(old.line_spectrum, 'lines') || ...
        isempty(old.line_spectrum.lines)
    method = [method, '; line metadata missing, encoded as JSON null'];
    return;
end

[y, fs_read] = audioread(wav_abs);
y = double(y(:));
if fs_read ~= old.fs
    method = sprintf('%s; warning: WAV sample rate %g differs from metadata fs %g', ...
        method, fs_read, old.fs);
end

scale_to_pcm = 1;
if isfield(old, 'wav_storage') && isfield(old.wav_storage, 'scale_to_pcm')
    scale_to_pcm = old.wav_storage.scale_to_pcm;
end
mixture = y / scale_to_pcm;

N = numel(mixture);
t = (0:N-1)' / fs_read;
line_sig = zeros(N, 1);
lines = old.line_spectrum.lines;
for k = 1:numel(lines)
    line_sig = line_sig + lines(k).amplitude * ...
        cos(2*pi*lines(k).frequency_hz*t + lines(k).phase_rad);
end

noise = mixture - line_sig;
signal_power = mean(line_sig.^2);
noise_power = mean(noise.^2);
if signal_power > 0 && noise_power > 0
    snr_db = 10 * log10(signal_power / noise_power);
end
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

function print_nonstandard_subtypes(map_obj)
keys_cell = keys(map_obj);
if isempty(keys_cell)
    fprintf('Nonstandard schema example subtypes: none\n');
    return;
end
fprintf('Nonstandard schema example subtypes:\n');
for k = 1:numel(keys_cell)
    key = keys_cell{k};
    fprintf('  %s: %d\n', key, map_obj(key));
end
end

function json_text = restore_schema_nulls(json_text)
json_text = strrep(json_text, '"speed_kt": []', '"speed_kt": null');
json_text = strrep(json_text, '"water_depth_m": []', '"water_depth_m": null');
json_text = strrep(json_text, '"latitude_deg": []', '"latitude_deg": null');
json_text = strrep(json_text, '"longitude_deg": []', '"longitude_deg": null');
json_text = strrep(json_text, '"month": []', '"month": null');
end