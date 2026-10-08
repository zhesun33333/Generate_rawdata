function [s_modu,B] = func_COMgen_m_rand(type,fs,fc,N,M,waveNum,T) 
% === INPUT ===
% type:     信号类型，0：无信码，1：有信码
% fs:       采样频率
% fc:       载频
% M:        伪码阶数
% N：       信码个数
% waveNum： 一个码片内的载波周期数
% T：       脉冲周期，如果为零，则只输出脉宽长度的数据
% === OUTPUT ===
% s_modu:   已调DSSS-BPSK信号
% s_baseband: 基带信号
% pn：       伪码序列（一个周期）
% pm：       信码序列
% ---------------------------------------------------------
% 系数c的设定，根据本院多项式设定
% 逆多项式,本原多项式为f(x)，则逆多项式定义为f~(x) = x^nf(1/x)
% 例如 f(x) = 1+x+x^4，则f~(x) = x^4(1+x^-1+x^-4) = 1+x^3+x^4


B = round(fc/waveNum*2);           % 信号带宽
if B/2>fc 
    error('半带宽超过载波频率，可能阶数M或波数waveNum设定太大，请重新设定带宽')
end
if fc+B/2>fs/2
    error('欠采样，可能阶数M或波数waveNum设定太大，请重新设定参数')
end
[c,pn]=msequence_rand(M);
% pn = mSequenceGen(c);           % 产生m序列
% c1 = [0 0 0 1 1 1 1];
% c2 = [0 0 1 1 1 0 1];
% m1 = mSequenceGen(c1);
% m2 = mSequenceGen(c2);
% m1 = (m1+1)/2;
% m2 = (m2+1)/2;
% pn = mod(m1+m2,2);
% pn = (pn-0.5)*2;
% --- 通信码率
Tp = 1/(fc/waveNum);  % 码片时间 
% Tm = Tp*(2^M-1);
if type %有信码
    pm = randsrc(1,N);
else
    pm = ones(1,N);
end
% load('pm.mat');
% pm = s1_pm;
% --- 码片时间决定脉宽

Pwidth = Tp*(2^M-1)*N; %一个伪码周期对应多个信息码
if Pwidth>T && T>0
    error('脉宽大于脉冲周期，请重新设定！')
end

%disp(['脉宽：',num2str(round(Pwidth*1e4)/1e4),'s; 带宽:',num2str(B/1e3),'KHz;']);

Lw = round(Pwidth*fs);

% t=0:1/fs:T-1/fs;
t=0:1/fs:Pwidth;
L = 2^M-1;          % m序列长度
nPn = 1;
nPm = 1;
pn_s = zeros(1,Lw);
m = 0;
for i = 0:Lw-1
    if i/fs<=nPn*Tp+m*L*Tp
        if i/fs<=nPm*Tp*L
            pn_s(i+1) = pn(nPn)*pm(nPm);
        else
            nPm = nPm+1;
            pn_s(i+1) = pn(nPn)*pm(nPm);
        end
    else
        if nPn<L
            nPn = nPn+1;
            if i/fs<=nPm*Tp*L
                pn_s(i+1) = pn(nPn)*pm(nPm);
            else
                nPm = nPm+1;
                pn_s(i+1) = pn(nPn)*pm(nPm);
            end
        else
            nPn = 1;
            if i/fs<=nPm*Tp*L
                pn_s(i+1) = pn(nPn)*pm(nPm);
            else
                nPm = nPm+1;
                pn_s(i+1) = pn(nPn)*pm(nPm);
            end
            m = m+1;
        end
    end
end

sc = sin(2*pi*fc*t(1:length(pn_s)));
% s_modu = pn_s.*sc;           % 信号生成
s_modu = pn_s.*sc;  % [pn_s.*sc;pn_s];           % 信号生成
s_baseband = pn_s;
if T > 0        % T>0给出整个周期的信号，否则只给出信号存在部分
    s_modu = [zeros(1,(round(T*fs)-length(s_modu))/2),s_modu,zeros(1,(round(T*fs)-length(s_modu))/2)];
    s_baseband = [s_baseband,zeros(1,round(T*fs)-length(s_modu))];
end




