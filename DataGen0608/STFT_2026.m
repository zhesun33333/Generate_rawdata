function [fcoordinate,tcoordinate,Mf]=STFT_2026 (Data, t_Start ,W_L,STEP,FS,fmin,fmax)
% fmin,fmax限制了显示的频率范围
Start=0;
%参数说明： 
% Data    待处理数据 
% t_Start 起始时间 
% W_L     窗长    
% STEP    步进 
% FS      采样频率
% Ch_Sel  选择的通道 
datach = Data;        % 提取需要处理的一段数据
L1 =length(datach);             % 待分析数据长度
K = fix((L1-W_L)/STEP)-1;       % 分段长度
Mf=zeros(K,ceil(W_L/2));
for k=1:K
    dataw = datach((k-1)*STEP+1:(k-1)*STEP+W_L);      % 提取一个窗长的数据
    fdata = abs(fft(dataw));
    Mf(k,:) = fdata(1:ceil(W_L/2));    
end
T=L1/FS;
% name1 = [SigType,'信号，窗长：',num2str(W_L/FS),'s，步进：',num2str(STEP/FS),'s'];
fcoordinate = 0:FS/W_L:FS/2-FS/W_L;
tcoordinate = (0:STEP/FS:(K-1)*STEP/FS)+t_Start+Start;
% fmax = 20e3;
% fmin = 300;
df = FS/W_L;
fmaxN = min(round(fmax/df+1),W_L/2);
fminN = max(round(fmin/df+1),1);
Mfmax = max(max(Mf(:,fminN:fmaxN)));
Mfmin = min(min(Mf(:,fminN:fmaxN)));
Mfu = (Mf-Mfmin)/(Mfmax-Mfmin);

imagesc(tcoordinate,fcoordinate(fminN:fmaxN),20*log10((Mfu(:,fminN:fmaxN)+1).'));
axis('xy')
xlabel('时间(s)');
ylabel('频率（Hz）')
colormap('jet')
colorbar;
end
