function [signal, band, B, Nb,s_code] = Sig_Gernerate_NEW(M, Fs, f0, Baud, tau, Band, H, type, rcosFlag, roll_factor, PNOrder,waveNum,NumSubcarrier,CP_Factor)
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
    Nb = 0;
    s_code = [];
    % For type 7 (HFM), signed Band preserves sweep direction around f0.
    if type == 1 % FSK
        df = H*Baud;
        B = (M-1)*df+Baud*2;
        Nb = round(tau*Baud);
        flag = 0;
        kk0 = 0;
        Nb = round(tau * Baud);  
        
        n_each = floor(Nb / M);

        n_rem  = mod(Nb, M);
        

        s_code = repelem(0:M-1, n_each);
        
        if n_rem > 0
            s_code = [s_code, 0:n_rem-1];
        end
        

        s_code = s_code(randperm(numel(s_code)));
        s_baseband = fskmod(s_code,M,df,round(Fs/Baud),Fs,'discont'); 

 
        Fadingflag = double(rand() <= 0.2); 
        Fadingflag = 0;
        if Fadingflag == 1
            nSamp = round(Fs/Baud);          % 
            s_baseband = s_baseband(:).';    %


            gains = ones(1, M);

            if M == 2
                idx_weak = randi(M);               
                a = 0.3 + (0.8 - 0.3) * rand;       
                gains(idx_weak) = a;

            elseif M == 4
                idx_weak = randi(M);                
                if rand < 0.6
                    a = 0.3 + (0.8 - 0.3) * rand;   
                else
                    a = 0.0;                         
                end

                gains(idx_weak) = a;
            end

            g_seq  = gains(s_code + 1);             
            g_samp = repelem(g_seq, nSamp);         

            g_samp = g_samp(1:min(length(g_samp), length(s_baseband)));
            if length(g_samp) < length(s_baseband)
                g_samp = [g_samp, ones(1, length(s_baseband) - length(g_samp))];
            end

            s_baseband = s_baseband .* g_samp;
        end
        sfc = exp(1i*2*pi*f0*t+1i*pi/2);
        nLen = min(length(s_baseband),length(sfc));
        signal = real(s_baseband(1:nLen).*sfc(1:nLen));
        band = [f0 - B/2, f0 + B/2];

    elseif type == 2 % PSK
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
        msg_tx = pskmod(s_code,M,pi/4);
        nSamp = round(Fs/Baud);
        Rs_eff=Fs/nSamp;    
        B = 2*Rs_eff;
        s_baseband = rectpulse(msg_tx,nSamp);
        if rcosFlag == 1
            rcos_fir = RootRaisedCosine_6(nSamp, roll_factor);
            rcos_fir = rcos_fir/sum (rcos_fir);
            n_rcos_fir = length (rcos_fir);
            if mod (n_rcos_fir,2) == 0
                nhalf_rcos_fir = n_rcos_fir/2;
            else
                nhalf_rcos_fir = (n_rcos_fir+1)/2;
            end
            tempfil = conv(rcos_fir, s_baseband); 
            s_baseband = tempfil (nhalf_rcos_fir:end-nhalf_rcos_fir+1);
        end
        sfc = exp(1i*2*pi*f0*t+1i*pi/4);
        nlen = min(length(s_baseband),length(sfc));
        signal = real(s_baseband(1:nlen).*sfc(1:nlen));
        band = [f0 - B/2, f0 + B/2];
    elseif type == 3 % OFDM
        [signal,~,~,s_code] = OFDMGen(Fs, f0, Band,CP_Factor,NumSubcarrier,tau);
        Nb = numel(s_code); % NumSubcarrier/Band*(1+CP_Factor)
        band = [f0 - Band/2, f0 + Band/2];
        B = Band;
    elseif type == 4 % LFM
        f1 = f0 - Band/2;
        miu = Band/tau;
        signal = sin(2*pi*f1*t+pi*miu*t.^2);
        band = [f0 - Band/2, f0 + Band/2];
        B = Band;
    elseif type == 5 % DSSS
        Tp = waveNum / f0; 
        Nb = round(tau / (Tp * (2^PNOrder-1))); 
        [signal,B] = func_COMgen_m_rand_NEW(1,Fs,f0,Nb,PNOrder,waveNum,rcosFlag,roll_factor);
        band = [f0 - 1.2 * B, f0 + 1.2 * B];
    elseif type == 6 % CW
        signal = sin(2*pi*f0*t);
        B = 0;
        band = [0.9*f0, 1.1*f0];
    elseif type == 7 % HFM
        f_start = f0 - Band / 2;
        f_end = f0 + Band / 2;
        [signal, band, B, Nb, s_code] = generate_hfm(Fs, tau, f_start, f_end);

    end
end

function [signal, band, B, Nb, s_code] = generate_hfm(Fs, tau, f_start, f_end)
    t = 0:1/Fs:tau - 1/Fs;
    phase0 = 2 * pi * rand();
    denom0 = f_end * tau;
    denom = f_end * tau + (f_start - f_end) .* t;
    coeff = 2 * pi * f_start * f_end * tau / (f_start - f_end);
    phase = coeff .* log(denom ./ denom0);
    signal = sin(phase + phase0);
    band = [min(f_start, f_end), max(f_start, f_end)];
    B = abs(f_end - f_start);
    Nb = 0;
    s_code = [];
end
