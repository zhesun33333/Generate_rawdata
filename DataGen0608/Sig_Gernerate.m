function [signal, band, B] = Sig_Gernerate(M, Fs, f0, Baud, tau, Band, H, type, rcosFlag, roll_factor, PNOrder)
    % SIG_GENERATE 生成信号函数
    %
    % 输入参数：
    %   M         - 信号的符号数或调制阶数                                     !!!(仅对FSK, PSK有效)!!!
    %   Fs        - 采样频率（Hz）
    %   f0        - 载波频率（Hz）
    %   Baud      - 波特率（符号速率，Hz）                                     !!!(仅对FSK, PSK有效)!!!
    %   tau       - 信号时长（秒）
    %   Band      - 信号带宽（Hz）                                             !!!(仅对LFM, OFDM有效)!!!
    %   H         - 调制指数 (大于等于0.5)                                     !!!(仅对FSK有效)!!!
    %   type      - 信号类型（1:FSK  2:PSK  3:OFDM  4:LFM  5:DSSS  6:CW）
    %   rcosFlag  - 是否使用根升余弦滤波器（0或1）                               !!!(仅对PSK有效)!!!
    %   roll_factor - 升余弦滤波器的滚降因子（0到1之间）                         !!!(仅在rcosFlag==1时有效)!!!
    %   PNOrder:  - 伪码阶数                                                   !!!(仅对DSSS有效)!!!
    % 输出参数：
    %   signal    - 生成的信号
    %   band      - 信号大致所处频带范围
    %   B         - 信号的真实带宽信息（用来给文件命名）
    %
    % 注意：
    %   请确保输入参数符合实际信号生成需求。

    band = zeros(1, 2);
    t=0:1/Fs:tau-1/Fs;
    
    if type == 1 % FSK
        df = H*Baud;
        B = (M-1)*df;
        Nb = round(tau*Baud);
        flag = 0;
        kk0 = 0;
        while flag == 0
            s_code = randi([0,M-1],1,Nb);
            for kk = 1:M
                id = find(s_code == kk-1);
                sumkk(kk) = length(id);
            end
            if max(sumkk)/min(sumkk)<2
                flag = 1;
            end
            kk0 = kk0+1;
        end
        % s_code = repmat([0 1 2 3],1,Nb);
        s_baseband = fskmod(s_code,M,df,round(Fs/Baud),Fs,'cont'); % 连续相位FSK %discont
        sfc = exp(1i*2*pi*f0*t+1i*pi/2);
        nLen = min(length(s_baseband),length(sfc));
        signal = real(s_baseband(1:nLen).*sfc(1:nLen));
        band = [f0 - B/2 - df/2, f0 + B/2 + df/2];
    elseif type == 2 % PSK
        B = 2*Baud;  % 信号带宽
        Nb = round(tau*Baud);
        s_code = randi([0,M-1],1,Nb);
        flag = 0;
        kk0 = 0;
        while flag == 0
            s_code = randi([0,M-1],1,Nb);
            for kk = 1:M
                id = find(s_code == kk-1);
                sumkk(kk) = length(id);
            end
            if max(sumkk)/min(sumkk)<1.5
                flag = 1;
            end
            kk0 = kk0+1;
        end
        msg_tx = pskmod(s_code,M,0);
        % %% 绘制恢复后的星座图
        % figure;
        % 
        % scatterplot(msg_tx);
        % axis equal; grid on;
        % xlabel('I分量'); ylabel('Q分量');
        % title('初始的星座图');
        nSamp = round(Fs/Baud);
        s_baseband = rectpulse(msg_tx,nSamp);
        if rcosFlag == 1
            rcos_fir = RootRaisedCosine_6(nSamp, roll_factor);
            s_baseband_I = filter(rcos_fir,1,real(s_baseband)); %滚降滤波
            s_baseband_Q = filter(rcos_fir,1,imag(s_baseband)); %滚降滤波
            s_baseband = s_baseband_I + 1i*s_baseband_Q;
        end
        sfc = exp(1i*2*pi*f0*t+1i*pi/4);
        nlen = min(length(s_baseband),length(sfc));
        signal = real(s_baseband(1:nlen).*sfc(1:nlen));
        band = [f0 - B/2 - Baud, f0 + B/2 + Baud];
    elseif type == 3 % OFDM
        NumSubcarrier = 1024;
        CP_Factor = 0;
        [signal,~] = OFDMGen(Fs, f0, Band,CP_Factor,NumSubcarrier,tau); %单个OFDM符号时长 NumSubcarrier/Band*(1+CP_Factor)
        band = [f0 - Band, f0 + Band];
        B = Band;
        % tau = length(signal)/Fs;
    elseif type == 4 % LFM
        f1 = f0 - Band/2;
        miu = Band/tau;
        signal = sin(2*pi*f1*t+pi*miu*t.^2);
        band = [f0 - Band, f0 + Band];
        B = Band;
    elseif type == 5 % DSSS
        % N = 6;%10, 9, 8, 7, 6
        % M = 7;%10, 9, 8, 7
        T = 0;
        % Tp = 0.001;
        waveNum_set = [4, 5, 8, 10];
        waveNum = waveNum_set(randi(4));
        Tp = waveNum / f0; % 伪码周期
        N = round(tau / (Tp * (2^PNOrder-1))); % 信码个数
        % Pwidth = Tp*(2^M-1)*N;
        % tp = Tp*(2^M-1);
        [signal,B] = func_COMgen_m_rand(1,Fs,f0,N,PNOrder,waveNum,T);
        band = [f0 - 1.2 * B, f0 + 1.2 * B];
    elseif type == 6 % CW
        signal = sin(2*pi*f0*t);
        B = 0;
        band = [0.9*f0, 1.1*f0];

    end


    



end