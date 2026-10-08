function [feat224, p2_1024_max, f1024, meta] = my_feat_p2_224(x, Fs, f0, Band)
%MY_FEAT_P2_224  生成 P2 特征：
%  1) 取前 1 秒
%  2) band = [f0-Band/2, f0+Band/2] 并加 guard
%  3) FIR 带通 + filtfilt 零相位
%  4) 解析信号(只保留正频) -> 时域 -> 平方 -> 功率谱
%  5) 在 M*band 频率范围截取 P2 raw
%  6) 对 raw 做 peak-hold maxpool 到 1024 点
%  7) 再插值到 224 点并 tile 成 224x224
%
% 输入:
%   x   : 1D 信号（>= 1s；不足 1s 会补零）
%   Fs  : 采样率
%   f0  : 载频（Hz）
%   Band: 带宽（Hz）
%
% 输出:
%   feat224     : (224,224)  网络输入(由 224 点 1D 重采样后按行复制)
%   p2_1024_max : (1024,1)   peak-hold(max) 后的 1D 特征
%   f1024       : (1,1024)   对应频轴(Hz)，线性映射到 raw 的 [f_left,f_right]
%   meta        : 结构体，记录 band、deltaF、raw长度等调试信息

    % -----------------------
    % 参数（你可按需改）
    % -----------------------
    parseflag   = 1;      % 1=解析信号（只保留正频）
    FIR_ORDER   = 512;    % fir1 阶数（系数长度 = order+1）
    GUARD_HZ    = 50;    % band 两侧扩展
    M           = 2;      % P2

    x = x(:);

    % -----------------------
    % (1) 取 1 秒（不足补零）
    % -----------------------
    N1 = round(Fs * 1.0);
    if numel(x) >= N1
        x1 = x(1:N1);
    else
        x1 = [x; zeros(N1-numel(x),1)];
    end

    % -----------------------
    % (2) 频带 + guard
    % -----------------------
    band_use = [f0 - Band/2, f0 + Band/2];
    f1 = band_use(1) - GUARD_HZ;
    f2 = band_use(2) + GUARD_HZ;

    % 防越界（fir1 归一化频率必须在 (0,1) 内）
    f1 = max(1, f1);
    f2 = min(Fs/2 - 1, f2);

    band = [f1, f2];

    % -----------------------
    % (3) FIR 带通 + 零相位滤波
    % -----------------------
    Wn = [band(1) band(2)] / (Fs/2);
    b  = fir1(FIR_ORDER, Wn, 'bandpass', hamming(FIR_ORDER+1), 'scale');
    x1 = filtfilt(b, 1, x1);

    % -----------------------
    % (4)(5) 计算 P2 raw（只取 M*band 这一段）
    % -----------------------
    [p2_raw, f_raw, deltaF] = calc_PM_range_local(Fs, x1, band, M, parseflag);

    % -----------------------
    % (6) peak-hold maxpool -> 1024
    % -----------------------
    p2_1024_max = downsample_peak_hold_local(p2_raw, 1024, 'max');

    % 对应频轴：把 raw 的 [f_raw(1), f_raw(end)] 线性映射到 1024 点
    f1024 = linspace(f_raw(1), f_raw(end), 1024);

    % -----------------------
    % (7) 做 224x224（tile 方式）
    % -----------------------
    p2_224_1d = resample_1d_local(p2_1024_max, 224);     % 先从 1024 -> 224 更稳定
    feat224   = repmat(p2_224_1d(:).', 224, 1);          % 224x224

    % -----------------------
    % meta（方便你调试）
    % -----------------------
    meta = struct();
    meta.band_use   = band_use;
    meta.band_guard = band;
    meta.parseflag  = parseflag;
    meta.FIR_ORDER  = FIR_ORDER;
    meta.GUARD_HZ   = GUARD_HZ;
    meta.M          = M;
    meta.deltaF     = deltaF;
    meta.raw_len    = numel(p2_raw);
end


% ==========================================================
% 计算 P^M 在 M*band 范围内的 raw 线谱（并归一化 max=1）
% ==========================================================
function [pM_raw, ff, deltaF] = calc_PM_range_local(Fs, x1sec, band, M, parseflag)
    s_fft = fft(x1sec);
    nSigLength = length(s_fft);
    deltaF = Fs / nSigLength;

    if parseflag == 1
        % 只保留正频
        s_fft(nSigLength/2 + 2 : end) = 0;
        s_fft(2 : nSigLength/2) = 2 * s_fft(2 : nSigLength/2);
    end

    sig = ifft(s_fft);
    sM  = sig.^M;

    sM_fft = fft(sM);
    sM_psd = (abs(sM_fft).^2) / nSigLength;

    nLeft  = round(M * band(1) / deltaF);
    nRight = round(M * band(2) / deltaF);

    % 安全保护
    nLeft  = max(0, nLeft);
    nRight = min(nRight, length(sM_psd)-1);
    if nRight < nLeft
        error('band 太窄或参数异常：nRight < nLeft');
    end

    pM_raw = sM_psd(nLeft + 1 : nRight + 1);
    pM_raw = pM_raw ./ max(pM_raw + eps);  % 防 0

    ff = (nLeft : nRight) * deltaF;
end


% ==========================================================
% 1D 重采样到 L（线性插值），并归一化 max=1
% ==========================================================
function y = resample_1d_local(x, L)
    x = x(:).';
    N = numel(x);
    if N == L
        y = x;
        y = y ./ max(y + eps);
        return;
    end
    xi = 1:N;
    xq = linspace(1, N, L);
    y  = interp1(xi, x, xq, 'linear', 'extrap');
    y  = y ./ max(y + eps);
end


% ==========================================================
% peak-hold：L<=N 用 max/p99；L>N 用插值上采样（安全版）
% ==========================================================
function y = downsample_peak_hold_local(x, L, mode)
    if nargin < 3, mode = 'max'; end
    x = x(:);
    N = numel(x);

    if L <= 0
        error('L must be positive');
    end

    if L == N
        y = x;
        y = y ./ max(y + eps);
        return;
    end

    if L > N
        xi = 1:N;
        xq = linspace(1, N, L);
        y  = interp1(xi, x, xq, 'linear', 'extrap');
        y  = y ./ max(y + eps);
        return;
    end

    edges = round(linspace(1, N+1, L+1));
    y = zeros(L,1);

    for i = 1:L
        a = edges(i);
        b = edges(i+1) - 1;
        a = max(1, min(a, N));
        b = max(1, min(b, N));
        if b < a, b = a; end
        seg = x(a:b);

        switch lower(mode)
            case 'max'
                y(i) = max(seg);
            case 'p99'
                y(i) = prctile(seg, 99);
            otherwise
                error('unknown mode: %s', mode);
        end
    end

    y = y ./ max(y + eps);
end