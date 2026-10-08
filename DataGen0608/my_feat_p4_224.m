function [feat224, p4_1024_max, f1024, meta] = my_feat_p4_224(x, Fs, f0, Band)
%MY_FEAT_P4_224  根据你脚本生成 P4 特征（224x224 + 1024 maxpool）
%
% 输入:
%   x    : 1D 信号（>=1s；不足会补零）
%   Fs   : 原始采样率（你这里是 64e3）
%   f0   : 载频(Hz)
%   Band : 标量带宽(Hz)
%
% 输出:
%   feat224     : (224,224) 由 224 点 1D 特征 tile 得到
%   p4_1024_max : (1024,1) peak-hold(maxpool) 后的 1D 特征
%   f1024       : (1,1024) 对应频轴(Hz)，线性映射到 raw 的 [f_left,f_right]
%   meta        : 结构体，包含 band_use / band_guard / Fs_up 等信息
%
% 注意：
%   你脚本中：Fs=64k，P4 先 resample(x1,2,1) -> 128k，
%   并设置 Fs4 = 128e3。这里严格按这个逻辑。

    % -----------------------
    % 参数（与你脚本对齐）
    % -----------------------
    parseflag   = 1;        % 1=解析信号（只保留正频）
    FIR_ORDER   = 512;      % fir1(512,...)
    GUARD_HZ    = 50;      % band 两侧扩展
    M           = 4;        % P4
    Fs4         = 256e3;    % 你脚本写死给 P4 的 FsM

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
    % (2) band 与带通滤波（按你脚本：用原 Fs 设计滤波器）
    % -----------------------
    band_use = sort([double(f0) - double(Band)/2, double(f0) + double(Band)/2]);

    f1 = band_use(1) - GUARD_HZ;
    f2 = band_use(2) + GUARD_HZ;

    % 防越界
    f1 = max(1, f1);
    f2 = min(Fs/2 - 1, f2);
    band_guard = [f1, f2];

    % FIR bandpass + filtfilt
    Wn = band_guard / (Fs/2);
    b  = fir1(FIR_ORDER, Wn, 'bandpass', hamming(FIR_ORDER+1), 'scale');
    x1 = filtfilt(b, 1, x1);

    % % -----------------------
    % % (3) P4 用升采样（按你脚本：*2 -> 128k）
    % % -----------------------
    x_up  = resample(x1, 2, 1);   % 64k -> 128k
    Fs_up = Fs4;                 % 与你脚本一致（不要用 2*Fs 这种推断）

    % -----------------------
    % (4)(5) 计算 P4 raw（注意：截取范围用 band_guard，但 Fs 用 Fs_up）
    % -----------------------
    [p4_raw, f_raw, deltaF] = calc_PM_range_local(Fs, x, band_guard, M, parseflag);

    % -----------------------
    % (6) maxpool -> 1024
    % -----------------------
    p4_1024_max = downsample_peak_hold_local(p4_raw, 1024, 'max');
    f1024 = linspace(f_raw(1), f_raw(end), 1024);

    % -----------------------
    % (7) 224x224（tile）
    %   先 1024->224 再 tile，更稳
    % -----------------------
    p4_224_1d = resample_1d_local(p4_1024_max, 224);
    feat224   = repmat(p4_224_1d(:).', 224, 1);

    % meta
    meta = struct();
    meta.band_use   = band_use;
    meta.band_guard = band_guard;
    meta.parseflag  = parseflag;
    meta.FIR_ORDER  = FIR_ORDER;
    meta.GUARD_HZ   = GUARD_HZ;
    meta.M          = M;
    meta.Fs_in      = Fs;
    meta.deltaF     = deltaF;
    meta.raw_len    = numel(p4_raw);
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
    pM_raw = pM_raw ./ max(pM_raw + eps);

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