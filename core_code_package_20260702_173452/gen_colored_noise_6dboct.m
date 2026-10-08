function [nf1, Pw1L, power, f_axis] = gen_colored_noise_6dboct(fs, T, SPL1K, p, isWhite, fc)
%GEN_COLORED_NOISE_6DBOCT 生成 300 Hz 平台 + 6 dB/oct 下降的连续谱噪声。
%
% 输入：
%   fs      采样率
%   T       时长，秒
%   SPL1K   1 kHz 处参考谱级，dB
%   p       AR模型阶数
%   isWhite 是否白噪声
%   fc      平台区频率上限，Hz，默认 300 Hz
%
% 输出：
%   nf1     时域连续谱噪声
%   Pw1L    单边谱级曲线，频率分辨率 1 Hz，单位 dB
%   power   时域方差
%   f_axis  Pw1L 对应频率轴

if nargin < 6
    fc = 300;
end

I0 = 0.67e-18;   % 声强级参考值
rho = 1.0e3;     % 水密度
c = 1.5e3;       % 水中声速
delta_f = 1;

N = round(fs * T);
f_axis = 0:delta_f:fs/2;

if isWhite
    coeff = zeros(size(f_axis));
else
    % 避免 log2(0)，并实现 fc 以下平台期。
    f_shape = max(f_axis, fc);
    coeff = -6 * log2(f_shape / 1000);
end

Pw1L = SPL1K + coeff;

% 平台期：fc 以下取 fc 处的谱级
SPL_fc = interp1(f_axis, Pw1L, fc, 'linear', 'extrap');
Pw1L(f_axis <= fc) = SPL_fc;

% 将谱级转换为声压功率谱。该写法保留你原始代码的物理量转换形式。
Pw11 = I0 * rho * c * 10.^(Pw1L / 10);

% 构造用于 AR 拟合的双边功率谱。
% 对 0:fs/2 的单边谱，镜像时去掉 DC 和 Nyquist，长度接近 fs。
Pw11_full = [Pw11, fliplr(Pw11(2:end-1))] / 2;
Pw1 = Pw11_full * fs;

% 自相关函数
rc1 = real(ifft(Pw1));

% 生成噪声。优先使用 AR 模型；如 levinson 不可用，则退化为频域塑形法。
if exist('levinson', 'file') == 2
    [A1, E1] = levinson(rc1, p);
    n1 = randn(1, N);
    nf1 = sqrt(E1) * filter(1, A1, n1);
else
    warning('levinson() not found. Falling back to FFT-shaping noise generation.');
    nf1 = gen_fft_shaped_noise(fs, N, Pw1L, f_axis);
end

nf1 = nf1(:);
power = var(nf1);

end
