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
MAT_ROOT = fullfile(OUT_ROOT, 'mat_by_type');
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
COMM_SUBBANDS = [ ...
    struct('idx', 1, 'f0', 300,  'f1', 700,  'comm_bmin', 50,  'ofdm_bmin', 500, 'range_km', [5, 75]); ...
    struct('idx', 2, 'f0', 700,  'f1', 1500, 'comm_bmin', 50,  'ofdm_bmin', 500, 'range_km', [5, 50]); ...
    struct('idx', 3, 'f0', 1500, 'f1', 3500, 'comm_bmin', 100, 'ofdm_bmin', 500, 'range_km', [2.5, 40]); ...
    struct('idx', 4, 'f0', 3500, 'f1', 7500, 'comm_bmin', 150, 'ofdm_bmin', 500, 'range_km', [1, 20]) ...
    ];

OFDM_SUBBANDS = COMM_SUBBANDS(3:4);

SIG_CFGS = { ...
    struct('name', '2FSK', 'kind', 'fsk',  'M', 2, 'count_per_band', 4000, 'source_level_db', [180, 200]); ...
    struct('name', '4FSK', 'kind', 'fsk',  'M', 4, 'count_per_band', 4000, 'source_level_db', [180, 200]); ...
    struct('name', 'BPSK', 'kind', 'psk',  'M', 2, 'count_per_band', 4000, 'source_level_db', [180, 200]); ...
    struct('name', 'QPSK', 'kind', 'psk',  'M', 4, 'count_per_band', 4000, 'source_level_db', [180, 200]); ...
    struct('name', 'OFDM', 'kind', 'ofdm', 'M', 4, 'count_per_band', 8000, 'source_level_db', [180, 200]) ...
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
ensure_dir(MAT_ROOT);
ensure_dir(JSON_ROOT);

fprintf('Pure communication dataset root: %s\n', OUT_ROOT);
fprintf('Fs = %d Hz, expected full count = 80000\n', Fs);

for iSig = 1:numel(SIG_CFGS)
    cfg = SIG_CFGS{iSig};
    sig_name = cfg.name;
    wav_dir = fullfile(WAV_ROOT, sig_name);
    stft_dir = fullfile(STFT_ROOT, sig_name);
    mat_dir = fullfile(MAT_ROOT, sig_name);
    json_dir = fullfile(JSON_ROOT, sig_name);
    ensure_dir(wav_dir);
    ensure_dir(stft_dir);
    ensure_dir(mat_dir);
    ensure_dir(json_dir);

    if strcmp(cfg.kind, 'ofdm')
        subbands = OFDM_SUBBANDS;
    else
        subbands = COMM_SUBBANDS;
    end

    saved_count = 0;
    fprintf('\n=== Start %s ===\n', sig_name);

    for iBand = 1:numel(subbands)
        sb = subbands(iBand);
        n_target = cfg.count_per_band;
        if DEBUG_MAX_PER_BAND > 0
            n_target = min(n_target, DEBUG_MAX_PER_BAND);
        end

        for n = 1:n_target
            max_try = 200;
            ok = false;

            for retry = 1:max_try
                ok = false;
                PNOrder = 8;
                waveNum = 4;

                if strcmp(cfg.kind, 'fsk')
                    M = cfg.M;
                    H = sample_from_vector(0.5:0.5:5);
                    [fc, target_bandwidth_hz, valid] = sample_centered_bandwidth(sb.f0, sb.f1, sb.comm_bmin, F_EDGE, F_NYQ);
                    if ~valid
                        continue;
                    end

                    Baud = quantize_baud(Fs, target_bandwidth_hz / ((M - 1) * H + 2));
                    B_guard = round_one_decimal(Baud * ((M - 1) * H + 2));
                    if ~is_centered_band_valid(fc, B_guard, F_EDGE, F_NYQ)
                        continue;
                    end

                    n_sym = sample_symbol_count(Baud);
                    tau = n_sym / Baud;

                    rcosflag = 0;
                    roll_factor = 0;
                    NumSubcarrier = 512;
                    CP_Factor = 0;

                    [signal, band, B, Nb, s_code] = Sig_Gernerate_NEW( ...
                        M, Fs, fc, Baud, tau, B_guard, H, 1, ...
                        rcosflag, roll_factor, PNOrder, waveNum, NumSubcarrier, CP_Factor);

                    params = struct();
                    params.modulation = lower(sig_name);
                    params.M = M;
                    params.carrier_freq_hz = round_one_decimal(fc);
                    params.target_bandwidth_hz = round_one_decimal(target_bandwidth_hz);
                    params.symbol_rate_baud = Baud;
                    params.num_symbols = n_sym;
                    params.modulation_index_h = H;
                    params.bandwidth_hz = round_one_decimal(B);
                    params.band_low_hz = round_one_decimal(min(band));
                    params.band_high_hz = round_one_decimal(max(band));
                    params.rcosflag = rcosflag;
                    params.rolloff_beta = roll_factor;
                    params.generator = 'Sig_Gernerate_NEW';
                    ok = true;

                elseif strcmp(cfg.kind, 'psk')
                    M = cfg.M;
                    [fc, target_bandwidth_hz, valid] = sample_centered_bandwidth(sb.f0, sb.f1, sb.comm_bmin, F_EDGE, F_NYQ);
                    if ~valid
                        continue;
                    end

                    Baud = quantize_baud(Fs, target_bandwidth_hz / 2);
                    [rcosflag, roll_factor] = sample_psk_rolloff();
                    B_guard = round_one_decimal(2 * Baud);
                    if ~is_centered_band_valid(fc, B_guard, F_EDGE, F_NYQ)
                        continue;
                    end

                    n_sym = sample_symbol_count(Baud);
                    tau = n_sym / Baud;

                    H = 1;
                    NumSubcarrier = 512;
                    CP_Factor = 0;

                    [signal, band, B, Nb, s_code] = Sig_Gernerate_NEW( ...
                        M, Fs, fc, Baud, tau, B_guard, H, 2, ...
                        rcosflag, roll_factor, PNOrder, waveNum, NumSubcarrier, CP_Factor);

                    params = struct();
                    params.modulation = lower(sig_name);
                    params.M = M;
                    params.carrier_freq_hz = round_one_decimal(fc);
                    params.target_bandwidth_hz = round_one_decimal(target_bandwidth_hz);
                    params.symbol_rate_baud = Baud;
                    params.num_symbols = n_sym;
                    params.bandwidth_hz = round_one_decimal(B);
                    params.band_low_hz = round_one_decimal(min(band));
                    params.band_high_hz = round_one_decimal(max(band));
                    params.rcosflag = rcosflag;
                    params.rolloff_beta = roll_factor;
                    params.generator = 'Sig_Gernerate_NEW';
                    ok = true;

                elseif strcmp(cfg.kind, 'ofdm')
                    [fc, target_bandwidth_hz, valid] = sample_ofdm_bandwidth(sb.f0, sb.f1, sb.ofdm_bmin, F_EDGE, F_NYQ);
                    if ~valid
                        continue;
                    end

                    [NumSubcarrier, Band, CP_Factor, n_ofdm_sym, tau, valid_template] = sample_ofdm_template(target_bandwidth_hz, fc, sb.ofdm_bmin, F_EDGE, F_NYQ);
                    if ~valid_template
                        continue;
                    end

                    if ~is_ofdm_band_valid(fc, Band, F_EDGE, F_NYQ)
                        continue;
                    end

                    M = cfg.M;
                    Baud = max(20, round(Band / 8));
                    H = 1;
                    rcosflag = 0;
                    roll_factor = 0;

                    [signal, band, B, Nb, s_code] = Sig_Gernerate_NEW( ...
                        M, Fs, fc, Baud, tau, Band, H, 3, ...
                        rcosflag, roll_factor, PNOrder, waveNum, NumSubcarrier, CP_Factor);

                    params = struct();
                    params.modulation = 'ofdm';
                    params.carrier_freq_hz = round_one_decimal(fc);
                    params.target_bandwidth_hz = round_one_decimal(target_bandwidth_hz);
                    params.bandwidth_hz = round_one_decimal(B);
                    params.band_low_hz = round_one_decimal(min(band));
                    params.band_high_hz = round_one_decimal(max(band));
                    params.num_subcarriers = NumSubcarrier;
                    params.cp_factor = CP_Factor;
                    params.num_ofdm_symbols = n_ofdm_sym;
                    params.subcarrier_spacing_hz = round_one_decimal(Band / NumSubcarrier);
                    params.generator = 'Sig_Gernerate_NEW';
                    ok = true;
                else
                    error('Unknown signal kind: %s', cfg.kind);
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
            mat_rel = rel_join('mat_by_type', sig_name, [sample_id '.mat']);
            wav_path = fullfile(OUT_ROOT, strrep(wav_rel, '/', filesep));
            stft_path = fullfile(OUT_ROOT, strrep(stft_rel, '/', filesep));
            mat_path = fullfile(OUT_ROOT, strrep(mat_rel, '/', filesep));
            json_path = fullfile(json_dir, [sample_id '.jsonc']);

            audiowrite(wav_path, signal, Fs);
            save_stft_image(signal, Fs, sb, stft_path, STFT_DEBUG_PLOT);

            env = sample_environment(cfg.source_level_db, [5, 20], RECEIVER_DEPTH_RANGE_M, sb.range_km, WATER_DEPTH_M);

            params.subband_index = sb.idx;
            params.subband_low_hz = sb.f0;
            params.subband_high_hz = sb.f1;

            meta = base_metadata(sample_id, wav_rel, sig_name, 'communication', actual_duration_s, Fs, env);
            meta.symbol_mat_path = mat_rel;
            write_metadata_jsonc(json_path, meta, params);
            save_symbol_mat(mat_path, sample_id, sig_name, cfg.kind, s_code, params, meta);

            if mod(saved_count, 1000) == 0
                fprintf('[%s] saved = %d\n', sig_name, saved_count);
            end
        end
    end

    fprintf('>>> %s finished. total saved = %d\n', sig_name, saved_count);
end

disp('Pure communication dataset generation done.');

%% Local functions
function value = sample_from_vector(values)
    value = values(randi(numel(values)));
end

function [rcosflag, roll_factor] = sample_psk_rolloff()
    templates = [ ...
        1, 0.50; ...
        1, 0.60; ...
        1, 0.70; ...
        1, 0.80; ...
        1, 0.90; ...
        0, 0.00 ...
        ];
    idx = randi(size(templates, 1));
    rcosflag = templates(idx, 1);
    roll_factor = templates(idx, 2);
end

function n_sym = sample_symbol_count(Baud)
    max_sym = max(50, floor(30 * Baud));
    n_sym = randi([50, max_sym]);
end

function [NumSubcarrier, Band, CP_Factor, n_ofdm_sym, tau, valid] = sample_ofdm_template(target_bandwidth_hz, fc, b_min, f_edge, f_nyq)
    nsc_values = [512, 1024, 2048, 4096];
    cp_values = [0, 0.125, 0.25, 0.5];
    b_upper = ofdm_bandwidth_upper(fc, f_edge, f_nyq);
    band_values = compatible_ofdm_bandwidths();
    band_values = band_values(band_values >= b_min & band_values <= b_upper);
    band_values = band_values(is_ofdm_band_valid(fc, band_values, f_edge, f_nyq));

    valid = false;
    NumSubcarrier = NaN;
    Band = NaN;
    CP_Factor = NaN;
    n_ofdm_sym = NaN;
    tau = NaN;

    if isempty(band_values)
        return;
    end

    [~, nearest_idx] = min(abs(band_values - target_bandwidth_hz));
    Band = band_values(nearest_idx);

    for retry = 1:100
        NumSubcarrier = sample_from_vector(nsc_values);
        CP_Factor = sample_from_vector(cp_values);

        tsym_cp = NumSubcarrier / Band * (1 + CP_Factor);
        max_sym = min(10, floor(30 / tsym_cp));
        if max_sym < 1
            continue;
        end

        n_ofdm_sym = randi([1, max_sym]);
        tau = n_ofdm_sym * tsym_cp + 0.5 / 16000;
        valid = true;
        return;
    end
end

function Baud = quantize_baud(Fs, baud_target)
    n_samp = max(1, round(Fs / baud_target));
    Baud = Fs / n_samp;
end

function [fc, bandwidth_hz, valid] = sample_centered_bandwidth(sub_low, sub_high, b_min, f_edge, f_nyq)
    valid = false;
    fc = NaN;
    bandwidth_hz = NaN;

    for retry = 1:100
        fc_try = round_one_decimal(rand_uniform(sub_low, sub_high));
        b_upper = centered_bandwidth_upper(fc_try, f_edge, f_nyq);
        if b_upper <= b_min
            continue;
        end

        bandwidth_try = round_one_decimal(rand_uniform(b_min, b_upper));
        if ~is_centered_band_valid(fc_try, bandwidth_try, f_edge, f_nyq)
            continue;
        end

        fc = fc_try;
        bandwidth_hz = bandwidth_try;
        valid = true;
        return;
    end
end

function [fc, bandwidth_hz, valid] = sample_ofdm_bandwidth(sub_low, sub_high, b_min, f_edge, f_nyq)
    valid = false;
    fc = NaN;
    bandwidth_hz = NaN;

    for retry = 1:100
        fc_try = round_one_decimal(rand_uniform(sub_low, sub_high));
        b_upper = ofdm_bandwidth_upper(fc_try, f_edge, f_nyq);
        if b_upper <= b_min
            continue;
        end

        bandwidth_try = round_one_decimal(rand_uniform(b_min, b_upper));
        if ~is_ofdm_band_valid(fc_try, bandwidth_try, f_edge, f_nyq)
            continue;
        end

        fc = fc_try;
        bandwidth_hz = bandwidth_try;
        valid = true;
        return;
    end
end

function b_upper = centered_bandwidth_upper(fc, f_edge, f_nyq)
    b_upper = min(0.9 * fc, 2 * min(fc - f_edge, f_nyq - f_edge - fc));
end

function b_upper = ofdm_bandwidth_upper(fc, f_edge, f_nyq)
    b_upper = min(0.9 * fc, 2 * min(fc - f_edge, f_nyq - f_edge - fc));
end

function valid = is_centered_band_valid(fc, bandwidth_hz, f_edge, f_nyq)
    valid = (fc - bandwidth_hz / 2 >= f_edge) && (fc + bandwidth_hz / 2 <= f_nyq - f_edge);
end

function valid = is_ofdm_band_valid(fc, bandwidth_hz, f_edge, f_nyq)
    valid = (fc - bandwidth_hz / 2 >= f_edge) & (fc + bandwidth_hz / 2 <= f_nyq - f_edge);
end

function values = compatible_ofdm_bandwidths()
    divisors = 1:16000;
    values = divisors(mod(16000, divisors) == 0);
end

function x = rand_uniform(a, b)
    x = a + (b - a) * rand();
end

function x = round_one_decimal(x)
    x = round(x * 10) / 10;
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
    if isfield(meta, 'symbol_mat_path')
        write_pair(fid, 'symbol_mat_path', meta.symbol_mat_path, 2, true);
    end
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

function save_symbol_mat(mat_path, sample_id, sig_name, sig_kind, s_code, params, meta)
    symbols = s_code;
    symbol_values = unique(s_code);
    symbol_count = numel(s_code);
    save(mat_path, ...
        'sample_id', 'sig_name', 'sig_kind', ...
        'symbols', 's_code', 'symbol_values', 'symbol_count', ...
        'params', 'meta');
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
