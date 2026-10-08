function [signal,time,OFDM_Symbol,s_code]= OFDMGen(fs,fc,B,CP_Factor,M,tau)
% M：子载波数； N：单帧符号数； tau：信号时长，根据M、 B、tau计算N
% M取 2048 1024 512 等2的次方，方便IFFT;
% rng(2025);

% 参数检查
if fs < B
    error('采样率 fs 必须大于带宽 B');
end
if mod(fs, B) ~= 0
    warning('fs/B 不是整数，建议采样率为带宽的整数倍');
end

% 每个OFDM符号时长
Tsym = M / B;  % 不包含CP
Tsym_cp = Tsym * (1 + CP_Factor);  % 包含CP后的时长

% 总共可以生成的符号数
N= floor(tau / Tsym_cp);
if N<1
    % warning('OFDM输入时间过短，至少输入%d秒',Tsym_cp)
    N = 1;
end
time = N*Tsym_cp; %输出信号时长
Modulation_Order = 2;   %QPSK调制
Total_Signal = [];
s_code = zeros(N, M);
OFDM_Symbol_All = complex(zeros(N, M));
for i = 1:N
    L_Data = M*Modulation_Order;  %比特数
    Transmit_BitAll = randi([0 1], L_Data);
    Transmit_Bit = Transmit_BitAll(1:L_Data);
    [Passband_Signal, OFDM_Symbol, symbol_code] = OFDM_Signal_Creator(Transmit_Bit, Modulation_Order, fs, fc, B, CP_Factor);
    s_code(i, :) = symbol_code(:).';
    OFDM_Symbol_All(i, :) = OFDM_Symbol(:).';
    Total_Signal = [Total_Signal;Passband_Signal];
end

Total_Signal = Total_Signal/max(abs(Total_Signal));
signal = Total_Signal';
OFDM_Symbol = OFDM_Symbol_All;

end
