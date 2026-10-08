close all;
clear;
clc;

try
    rng(42, 'twister');
catch
    rand('seed', 42);
    randn('seed', 42);
end

%% Parse command-line argument for parallel job filtering
args = argv();
target_sig = '';
if numel(args) > 1
    target_sig = args{2};
end
if ~isempty(target_sig)
    fprintf('Filtering for signal type: %s\n', target_sig);
end

%% Path and global configuration
SCRIPT_DIR = fileparts(mfilename('fullpath'));
REPO_ROOT = fileparts(SCRIPT_DIR);
OUT_ROOT = fullfile(REPO_ROOT, 'GeneratedPure16k');
WAV_ROOT = fullfile(OUT_ROOT, 'wav_by_type');
STFT_ROOT = fullfile(OUT_ROOT, 'stft_by_type');
JSON_ROOT = fullfile(OUT_ROOT, 'jsonc');

addpath(SCRIPT_DIR);

Fs = 16000;
F_EDGE = 100;
F_NYQ = Fs / 2;
WATER_DEPTH_M = 100;
RECEIVER_DEPTH_RANGE_M = [5, WATER_DEPTH_M - 10];

% Set to 1 or 2 for a quick smoke run. Use 0 for full generation.
DEBUG_MAX_PER_BAND = 0;
STFT_DEBUG_PLOT = false;

%% Subband configuration from signal parameter master table
SUBBANDS = [ ...
    struct('idx', 1, 'f0', 300,  'f1', 700,  'cw_tau', [1, 10],     'chirp_tau', [1, 10],     'chirp_bmin', 50,  'range_km', [10, 150]); ...
    struct('idx', 2, 'f0', 700,  'f1', 1500, 'cw_tau', [0.5, 10],   'chirp_tau', [0.5, 10],   'chirp_bmin', 50,  'range_km', [10, 100]); ...
    struct('idx', 3, 'f0', 1500, 'f1', 3500, 'cw_tau', [0.05, 5],   'chirp_tau', [0.05, 5],   'chirp_bmin', 50,  'range_km', [5, 80]); ...
    struct('idx', 4, 'f0', 3500, 'f1', 7500, 'cw_tau', [0.02, 2],   'chirp_tau', [0.02, 2],   'chirp_bmin', 100, 'range_km', [2, 40]) ...
    ];

SIG_CFGS = { ...
    struct('name', 'CW',  'count_per_band', 6000, 'source_level_db', [200, 220]); ...
    struct('name', 'LFM', 'count_per_band', 7000, 'source_level_db', [200, 220]); ...
    struct('name', 'HFM', 'count_per_band', 7000, 'source_level_db', [200, 220]) ...
    };

% Filter by command-line argument if specified
if ~isempty(target_sig)
    known_names = cellfun(@(c) c.name, SIG_CFGS, 'UniformOutput', false);
    idx = find(strcmpi(target_sig, known_names), 1);
    if isempty(idx)
        error('Unknown signal: %s. Available: %s', target_sig, strjoin(known_names, ', '));
    end
    SIG_CFGS = SIG_CFGS(idx);
end

ensure_dir(WAV_ROOT);
ensure_dir(STFT_ROOT);
ensure_dir(JSON_ROOT);

fprintf('Pure pulse dataset root: %s\n', OUT_ROOT);
fprintf('Fs = %d Hz, expected full count = 80000\n', Fs);

for iSig = 1:numel(SIG_CFGS)
    cfg = SIG_CFGS{iSig};
    sig_name = cfg.name;
    wav_dir = fullfile(WAV_ROOT, sig_name);
    stft_dir = fullfile(STFT_ROOT, sig_name);
    json_dir = fullfile(JSON_ROOT, sig_name);
    ensure_dir(wav_dir);
    ensure_dir(stft_dir);
    ensure_dir(json_dir);

    saved_count = 0;
    fprintf('\n=== Start %s ===\n', sig_name);

    for iBand = 1:numel(SUBBANDS)
        sb = SUBBANDS(iBand);
        n_target = cfg.count_per_band;
        if DEBUG_MAX_PER_BAND > 0
            n_target = min(n_target, DEBUG_MAX_PER_BAND);
        end

        for n = 1:n_target
            max_try = 200;
            ok = false;

            for retry = 1:max_try
                if strcmp(sig_name, 'CW')
                    fc = round_one_decimal(rand_uniform(sb.f0, sb.f1));
                    tau = round_one_decimal(rand_uniform(sb.cw_tau(1), sb.cw_tau(2)));
                    direction = 'none';
                    bandwidth_hz = 0;
                    start_freq_hz = fc;
                    end_freq_hz = fc;

                    [signal, band, B, Nb, s_code] = Sig_Gernerate_NEW( ...
                        2, Fs, fc, 0, tau, 0, 1, 6, 0, 0, 8, 4, 512, 0);
                    ok = true;
                else
                    fc = round_one_decimal(rand_uniform(sb.f0, sb.f1));
                    b_upper = chirp_band_upper(fc, F_EDGE, F_NYQ);
                    if b_upper <= sb.chirp_bmin
                        continue;
                    end

                    bandwidth_hz = round_one_decimal(rand_uniform(sb.chirp_bmin, b_upper));
                    tau = round_one_decimal(rand_uniform(sb.chirp_tau(1), sb.chirp_tau(2)));

                    if rand() < 0.5
                        direction = 'upsweep';
                        start_freq_hz = round_one_decimal(fc - bandwidth_hz / 2);
                        end_freq_hz = round_one_decimal(fc + bandwidth_hz / 2);
                    else
                        direction = 'downsweep';
                        start_freq_hz = round_one_decimal(fc + bandwidth_hz / 2);
                        end_freq_hz = round_one_decimal(fc - bandwidth_hz / 2);
                    end

                    if min(start_freq_hz, end_freq_hz) < F_EDGE || max(start_freq_hz, end_freq_hz) > F_NYQ - F_EDGE
                        continue;
                    end

                    if strcmp(sig_name, 'LFM')
                        [signal, band, B, Nb, s_code] = Sig_Gernerate_NEW( ...
                            2, Fs, fc, 100, tau, bandwidth_hz, 1, 4, 0, 0, 8, 4, 512, 0);
                        if strcmp(direction, 'downsweep')
                            signal = fliplr(signal);
                        end
                    else
                        hfm_band = round_one_decimal(end_freq_hz - start_freq_hz);
                        [signal, band, B, Nb, s_code] = Sig_Gernerate_NEW( ...
                            2, Fs, fc, 0, tau, hfm_band, 1, 7, 0, 0, 8, 4, 512, 0);
                    end
                    ok = true;
                end

                if ok && ~isempty(signal) && any(signal ~= 0)
                    break;
                end
            end

            if ~ok
                error('Failed to sample a valid %s signal in subband %d after %d tries.', sig_name, sb.idx, max_try);
            end

            signal = normalize_unit(signal);
            signal = signal(:);
            actual_duration_s = numel(signal) / Fs;

            saved_count = saved_count + 1;
            sample_id = sprintf('%s_%06d', lower(sig_name), saved_count);
            wav_rel = rel_join('wav_by_type', sig_name, [sample_id '.wav']);
            stft_rel = rel_join('stft_by_type', sig_name, [sample_id '.png']);
            wav_path = fullfile(OUT_ROOT, strrep(wav_rel, '/', filesep));
            stft_path = fullfile(OUT_ROOT, strrep(stft_rel, '/', filesep));
            json_path = fullfile(json_dir, [sample_id '.jsonc']);

            audiowrite(wav_path, signal, Fs);
            save_stft_image(signal, Fs, sb, stft_path, STFT_DEBUG_PLOT);

            env = sample_environment(cfg.source_level_db, [5, 20], RECEIVER_DEPTH_RANGE_M, sb.range_km, WATER_DEPTH_M);

            params = struct();
            params.subband_index = sb.idx;
            params.subband_low_hz = sb.f0;
            params.subband_high_hz = sb.f1;
            params.center_freq_hz = round_one_decimal(fc);
            params.band_low_hz = round_one_decimal(min(band));
            params.band_high_hz = round_one_decimal(max(band));
            params.generator = 'Sig_Gernerate_NEW';

            if strcmp(sig_name, 'CW')
                params.pulse_width_s = tau;
            else
                params.start_freq_hz = round_one_decimal(start_freq_hz);
                params.end_freq_hz = round_one_decimal(end_freq_hz);
                params.bandwidth_hz = round_one_decimal(bandwidth_hz);
                params.sweep_direction = direction;
                params.pulse_width_s = tau;
            end

            meta = base_metadata(sample_id, wav_rel, sig_name, 'pulse', actual_duration_s, Fs, env);
            write_metadata_jsonc(json_path, meta, params);

            if mod(saved_count, 1000) == 0
                fprintf('[%s] saved = %d\n', sig_name, saved_count);
            end
        end
    end

    fprintf('>>> %s finished. total saved = %d\n', sig_name, saved_count);
end

disp('Pure pulse dataset generation done.');

%% Local functions
function x = rand_uniform(a, b)
    x = a + (b - a) * rand();
end

function x = round_one_decimal(x)
    x = round(x * 10) / 10;
end

function b_upper = chirp_band_upper(fc, f_edge, f_nyq)
    alias_limit = 2 * min(fc - f_edge, f_nyq - f_edge - fc);
    b_upper = min(0.9 * fc, alias_limit);
end

function y = normalize_unit(x)
    x = real(x(:));
    peak = max(abs(x));
    if peak > 0
        y = x ./ peak;
    else
        y = x;
    end
end

function env = sample_environment(source_level_range, source_depth_range, receiver_depth_range, range_km, water_depth_m)
    env = struct();
    env.source_level_db = round_one_decimal(rand_uniform(source_level_range(1), source_level_range(2)));
    env.source_depth_m = round_one_decimal(rand_uniform(source_depth_range(1), source_depth_range(2)));
    env.receiver_depth_m = round_one_decimal(rand_uniform(receiver_depth_range(1), receiver_depth_range(2)));
    env.water_depth_m = water_depth_m;
    env.range_m = round_one_decimal(1000 * rand_uniform(range_km(1), range_km(2)));
end

function meta = base_metadata(sample_id, wav_rel, signal_type, signal_category, duration_s, Fs, env)
    meta = struct();
    meta.id = sample_id;
    meta.wav_path = wav_rel;
    meta.has_target = true;
    meta.signal_type = signal_type;
    meta.signal_category = signal_category;
    meta.signal_duration_s = duration_s;
    meta.source_level_db = env.source_level_db;
    meta.source_depth_m = env.source_depth_m;
    meta.receiver_depth_m = env.receiver_depth_m;
    meta.water_depth_m = env.water_depth_m;
    meta.range_m = env.range_m;
    meta.audio_duration_s = 30.0;
    meta.model_fs_hz = Fs;
    meta.num_channels = 1;
end

function write_metadata_jsonc(path, meta, signal_params)
    fid = fopen(path, 'w', 'n', 'UTF-8');
    if fid < 0
        error('Could not open metadata file for writing: %s', path);
    end
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, '{\n');
    write_pair(fid, 'id', meta.id, 2, true);
    write_pair(fid, 'wav_path', meta.wav_path, 2, true);
    write_pair(fid, 'has_target', meta.has_target, 2, true);
    write_pair(fid, 'signal_type', meta.signal_type, 2, true);
    write_pair(fid, 'signal_category', meta.signal_category, 2, true);
    write_pair(fid, 'signal_duration_s', meta.signal_duration_s, 2, true);
    fprintf(fid, '  "signal_params": ');
    write_json_value(fid, signal_params, 2);
    fprintf(fid, ',\n');
    write_pair(fid, 'source_level_db', meta.source_level_db, 2, true);
    write_pair(fid, 'source_depth_m', meta.source_depth_m, 2, true);
    write_pair(fid, 'receiver_depth_m', meta.receiver_depth_m, 2, true);
    write_pair(fid, 'water_depth_m', meta.water_depth_m, 2, true);
    write_pair(fid, 'range_m', meta.range_m, 2, true);
    fprintf(fid, '  "ssp_source": null,\n');
    fprintf(fid, '  "snr_after_mix_db": null,\n');
    write_pair(fid, 'audio_duration_s', meta.audio_duration_s, 2, true);
    write_pair(fid, 'model_fs_hz', meta.model_fs_hz, 2, true);
    write_pair(fid, 'num_channels', meta.num_channels, 2, false);
    fprintf(fid, '}\n');
end

function write_pair(fid, key, value, indent, trailing_comma)
    fprintf(fid, '%s"%s": ', blanks(indent), json_escape(key));
    write_json_value(fid, value, indent, key);
    if trailing_comma
        fprintf(fid, ',');
    end
    fprintf(fid, '\n');
end

function write_json_value(fid, value, indent, key_hint)
    if nargin < 4
        key_hint = '';
    end

    if isstruct(value)
        fields = fieldnames(value);
        fprintf(fid, '{\n');
        for i = 1:numel(fields)
            key = fields{i};
            fprintf(fid, '%s"%s": ', blanks(indent + 2), json_escape(key));
            write_json_value(fid, value.(key), indent + 2, key);
            if i < numel(fields)
                fprintf(fid, ',');
            end
            fprintf(fid, '\n');
        end
        fprintf(fid, '%s}', blanks(indent));
    elseif ischar(value) || isstring(value)
        fprintf(fid, '"%s"', json_escape(char(value)));
    elseif islogical(value)
        if value
            fprintf(fid, 'true');
        else
            fprintf(fid, 'false');
        end
    elseif isnumeric(value)
        if isscalar(value)
            if is_one_decimal_key(key_hint)
                fprintf(fid, '%.1f', round_one_decimal(value));
            else
                fprintf(fid, '%.12g', value);
            end
        else
            fprintf(fid, '[');
            for i = 1:numel(value)
                if i > 1
                    fprintf(fid, ', ');
                end
                if is_one_decimal_key(key_hint)
                    fprintf(fid, '%.1f', round_one_decimal(value(i)));
                else
                    fprintf(fid, '%.12g', value(i));
                end
            end
            fprintf(fid, ']');
        end
    else
        error('Unsupported JSON value type: %s', class(value));
    end
end

function tf = is_one_decimal_key(key)
    one_decimal_keys = { ...
        'carrier_freq_hz', 'target_bandwidth_hz', 'bandwidth_hz', ...
        'band_low_hz', 'band_high_hz', 'center_freq_hz', ...
        'start_freq_hz', 'end_freq_hz', 'subcarrier_spacing_hz', ...
        'pulse_width_s', 'source_level_db', 'source_depth_m', ...
        'receiver_depth_m', 'range_m' ...
        };
    tf = any(strcmp(key, one_decimal_keys));
end

function s = json_escape(s)
    s = strrep(s, '\', '\\');
    s = strrep(s, '"', '\"');
    s = strrep(s, newline, '\n');
    s = strrep(s, char(13), '\r');
    s = strrep(s, char(9), '\t');
end

function ensure_dir(path)
    if ~exist(path, 'dir')
        mkdir(path);
    end
end

function save_stft_image(signal, Fs, sb, stft_path, debug_plot)
    [window_len, step_len, signal_for_stft] = adaptive_stft_input(signal, sb.idx);
    [stft_db, tcoordinate, fcoordinate] = compute_stft_view( ...
        signal_for_stft, 0, window_len, step_len, Fs, sb.f0, sb.f1);

    write_stft_png(stft_db, stft_path);

    if debug_plot
        figure;
        imagesc(tcoordinate, fcoordinate, stft_db);
        axis('xy');
        xlabel('Time (s)');
        ylabel('Frequency (Hz)');
        title(sprintf('subband %d: %d-%d Hz', sb.idx, sb.f0, sb.f1), 'Interpreter', 'none');
        colormap('jet');
        colorbar;
        drawnow;
    end
end

function [stft_db, tcoordinate, fcoordinate_crop] = compute_stft_view(Data, t_Start, W_L, STEP, FS, fmin, fmax)
    datach = Data(:);
    L1 = length(datach);
    K = fix((L1 - W_L) / STEP) - 1;
    Mf = zeros(K, ceil(W_L / 2));

    for k = 1:K
        dataw = datach((k - 1) * STEP + 1:(k - 1) * STEP + W_L);
        fdata = abs(fft(dataw));
        Mf(k, :) = fdata(1:ceil(W_L / 2));
    end

    fcoordinate = 0:FS / W_L:FS / 2 - FS / W_L;
    tcoordinate = (0:STEP / FS:(K - 1) * STEP / FS) + t_Start;
    df = FS / W_L;
    fmaxN = min(round(fmax / df + 1), W_L / 2);
    fminN = max(round(fmin / df + 1), 1);

    crop = Mf(:, fminN:fmaxN);
    Mfmax = max(crop(:));
    Mfmin = min(crop(:));
    if Mfmax > Mfmin
        Mfu = (Mf - Mfmin) / (Mfmax - Mfmin);
    else
        Mfu = zeros(size(Mf));
    end

    stft_db = 20 * log10((Mfu(:, fminN:fmaxN) + 1).');
    fcoordinate_crop = fcoordinate(fminN:fmaxN);
end

function write_stft_png(stft_db, stft_path)
    lo = min(stft_db(:));
    hi = max(stft_db(:));
    if hi > lo
        img01 = (stft_db - lo) / (hi - lo);
    else
        img01 = zeros(size(stft_db));
    end

    idx = max(1, min(256, round(img01 * 255) + 1));
    rgb = ind2rgb(idx, jet(256));
    imwrite(flipud(rgb), stft_path);
end

function [window_len, step_len, y] = adaptive_stft_input(signal, subband_idx)
    [window_len, step_len] = stft_window_step(subband_idx);
    y = signal(:);

    while numel(y) < window_len + 2 * step_len && window_len > 64
        window_len = window_len / 2;
        step_len = max(1, window_len / 4);
    end

    min_len = window_len + 2 * step_len;
    if numel(y) < min_len
        y(end + 1:min_len, 1) = 0;
    end
end

function [window_len, step_len] = stft_window_step(subband_idx)
    if subband_idx <= 2
        window_len = 4096;
        step_len = 1024;
    else
        window_len = 1024;
        step_len = 256;
    end
end

function p = rel_join(varargin)
    p = fullfile(varargin{:});
    p = strrep(p, '\', '/');
end
