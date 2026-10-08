function [Img224, AllocatedBand, img_u8] = STFT_featureExtraction_1s(data_1s, Fs, subbandnum, WinLen, psdflag, plotflag)
%STFT_FEATUREEXTRACTION_1S
% 输入:
%   data_1s    : 已截好的 1s 信号
%   Fs         : 采样率
%   subbandnum : 子带编号（1-based）
%   WinLen     : 窗长
%   psdflag    : 1 -> |Z|^2/WinLen ; 0 -> |Z|/WinLen ; else -> |Z|^2/WinLen
%   plotflag   : 是否显示
%   FREQSTART/FREQEND : 子带起止频率数组（Hz）
% 输出:
%   Img224        : single 224x224, 值域约 [0,1]
%   AllocatedBand : [Freqlow, Frequp]
%   img_u8        : uint8 224x224
    % FREQSTART = [150, 300, 500, 1500, 2500, 4000, 8000, 12000];
    % FREQEND   = [500, 1000, 2500, 4500, 7000, 12000, 18000, 25000];
    FREQSTART = [800, 1500, 2500, 4000, 6000, 9000, 13000, 19000];
    FREQEND   = [1500, 2500, 4000, 6000, 9000, 13000, 19000, 25000];

    if nargin < 6 || isempty(plotflag), plotflag = false; end

    data = data_1s(:);
    Step = floor(WinLen/4);
    noverlap = WinLen - Step;

    w = rectwin(WinLen);

    % MATLAB stft（较新版本）
    [S, F, ~] = stft(data, Fs, ...
        "Window", w, ...
        "OverlapLength", noverlap, ...
        "FFTLength", WinLen, ...
        "FrequencyRange", "onesided");

    Zabs = abs(S);
    if psdflag == 1
        psd = (Zabs.^2) / WinLen;
    elseif psdflag == 0
        psd = Zabs / WinLen;
    else
        psd = (Zabs.^2) / WinLen;
    end

    Freqlow = FREQSTART(subbandnum);
    Frequp  = FREQEND(subbandnum);
    AllocatedBand = [Freqlow, Frequp];

    % 用频率轴 F 直接截取（MATLAB 风格）
    idx = (F >= Freqlow) & (F <= Frequp);
    if ~any(idx)
        data_psd_cat = zeros(1, size(psd,2), 'like', psd);
    else
        data_psd_cat = psd(idx, :);
    end

    % min-max 归一化
    psd_min = min(data_psd_cat(:));
    psd_max = max(data_psd_cat(:));
    if psd_max == psd_min
        data_psd_cat = zeros(size(data_psd_cat), 'single');
    else
        data_psd_cat = (data_psd_cat - psd_min) / (psd_max - psd_min);
    end

    % 20log10(x+1) 再归一化
    data_psd_cat_log = 20 * log10(data_psd_cat + 1.0);

    log_min = min(data_psd_cat_log(:));
    log_max = max(data_psd_cat_log(:));
    if log_max == log_min
        normalized = zeros(size(data_psd_cat_log), 'single');
    else
        normalized = (data_psd_cat_log - log_min) / (log_max - log_min);
    end

    normalized = flipud(normalized);

    Img224 = imresize(normalized, [224, 224], "bicubic");

    % resize 后再次归一化
    img_min = min(Img224(:));
    img_max = max(Img224(:));
    if img_max == img_min
        Img224 = zeros(size(Img224), 'single');
    else
        Img224 = (Img224 - img_min) / (img_max - img_min);
    end
    Img224 = single(Img224);

    img_u8 = uint8(Img224 * 255);
    normalized_u8 = uint8(normalized * 255);
    if plotflag
        figure; imshow(img_u8); title("STFT 224x224");
        figure; imshow(normalized_u8);
    end
end