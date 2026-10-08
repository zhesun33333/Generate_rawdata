function meta_v1 = ship_metadata_to_schema_v1(old, key, wav_path)
%SHIP_METADATA_TO_SCHEMA_V1 Convert one generated ship metadata struct to schema v1.

class_name = old.class_name;
sub_type = class_to_sub_type(class_name);
wav_rel = strrep(fullfile(class_name, 'wav', [key, '.wav']), filesep, '/');

meta_v1 = struct();
meta_v1.id = key;
meta_v1.wav_path = wav_rel;
meta_v1.has_target = true;
meta_v1.signal_type = 'SHIP';
meta_v1.signal_category = 'radiated_noise';
meta_v1.sub_type = sub_type;
meta_v1.signal_duration_s = old.duration_sec;
meta_v1.signal_params = build_signal_params(old, class_name, sub_type);

meta_v1.source_depth_m = old.geometry.tx_depth_m;
meta_v1.receiver_depth_m = old.geometry.rx_depth_m;
meta_v1.water_depth_m = NaN;
meta_v1.range_m = old.geometry.distance_km * 1000;
meta_v1.ssp_source = struct( ...
    'dataset', 'not_recorded', ...
    'latitude_deg', NaN, ...
    'longitude_deg', NaN, ...
    'month', NaN);

[snr_after_mix_db, snr_method] = compute_after_mix_snr_db(wav_path, old);
meta_v1.snr_after_mix_db = snr_after_mix_db;
meta_v1.audio_duration_s = old.duration_sec;
meta_v1.model_fs_hz = old.fs;
meta_v1.num_channels = 1;
meta_v1.geometry = old.geometry;
meta_v1.geometry.range_m = meta_v1.range_m;
meta_v1.line_spectrum = old.line_spectrum;

meta_v1.conversion_notes = struct();
meta_v1.conversion_notes.source_schema = 'original_ship_radiated_noise_metadata';
meta_v1.conversion_notes.target_schema = 'metadata_schema_v1';
meta_v1.conversion_notes.water_depth_m = ...
    'not recorded in original metadata; encoded as JSON null';
meta_v1.conversion_notes.ssp_source = ...
    'not recorded in original metadata; dataset is not_recorded and numeric fields are JSON null';
meta_v1.conversion_notes.snr_after_mix_db = snr_method;
meta_v1.conversion_notes.line_spectrum = ...
    'original line_spectrum is preserved, including lines[].measured_line_snr_db';
meta_v1.conversion_notes.geometry = ...
    'original geometry is preserved; source_depth_m/receiver_depth_m/range_m are schema aliases of tx_depth_m/rx_depth_m/distance_km*1000';
meta_v1.conversion_notes.sub_type = ...
    'derived from original class_name; cruise_ship and underwater_target are outside the schema examples but preserved truthfully';

if isfield(old, 'field_descriptions')
    old = rmfield(old, 'field_descriptions');
end
meta_v1.original_metadata = old;
meta_v1.field_descriptions = get_schema_v1_field_descriptions();

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

function [snr_db, method] = compute_after_mix_snr_db(wav_path, old)
snr_db = NaN;
method = ['global SNR computed as 10*log10(mean(line_sig.^2)/mean(noise.^2)); ' ...
    'line_sig reconstructed from line_spectrum.lines frequency/amplitude/phase; ' ...
    'noise reconstructed as physical WAV mixture minus line_sig'];

if ~exist(wav_path, 'file')
    method = [method, '; WAV file missing, encoded as JSON null'];
    return;
end

[y, fs_read] = audioread(wav_path);
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
