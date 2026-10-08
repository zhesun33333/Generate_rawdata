

%% BPSK
clc; clear; close all;
savepath = 'D:\20251029晚测试信号使用\SigADD\测向测试数据2kHz';
[signal1, band, B, Nb,s_code1] = Sig_Gernerate_NEW(2, 64e3, 2000, 250, 4, 500, 0, 2, 1, 0.8, 0,4,512,0);
[signal2, band, B, Nb,s_code2] = Sig_Gernerate_NEW(2, 64e3, 2000, 250, 4, 500, 0, 2, 1, 0.8, 0,4,512,0);
[signal3, band, B, Nb,s_code3] = Sig_Gernerate_NEW(2, 64e3, 2000, 250, 4, 500, 0, 2, 1, 0.8, 0,4,512,0);

fs = 64e3; gaptime = 3; gaplength = gaptime*fs;
fc = 2e3; type = 'BPSK'; Baud = 250; roll_factor = 0.8;
pulseWidth = length(signal1)/fs;
frameConut = 3;
totalDuration = 3*(pulseWidth+gaptime);
matName = "WZZ"+'_'+ type+'_fs'+num2str(fs)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_cos'+...
    roll_factor+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.mat' ;
binName0 = "WZZ"+'_'+ type+'_fs'+num2str(fs)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_cos'+...
    roll_factor+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.bin' ;
binName1 = "WZZ"+'_'+ type+'_fs'+num2str(fs/2)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_cos'+...
    roll_factor+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.bin' ;
x0 = [signal1,zeros(1,gaplength),signal2,zeros(1,gaplength),signal3,zeros(1,gaplength)];
STFT_2025(x0, 0 ,2048,512,64000,0,20e3,99);
x1 =resample(x0,1,2);
s_code = [s_code1,s_code2,s_code3];
save(fullfile(savepath,matName),'x0','band','B','Nb','s_code','fs');
fid0 = fopen(fullfile(savepath,binName0),'wb');
fwrite(fid0,x0,'float32');
fclose(fid0);
fid1 = fopen(fullfile(savepath,binName1),'wb');
fwrite(fid1,x1,'float32');
fclose(fid1);
%% QPSK
clc; clear; close all;
savepath = 'D:\20251029晚测试信号使用\SigADD\测向测试数据2kHz';
[signal1, band, B, Nb,s_code1] = Sig_Gernerate_NEW(4, 64e3, 2000, 250, 4, 1000, 0, 2, 1, 0.8, 0,4,512,0);
[signal2, band, B, Nb,s_code2] = Sig_Gernerate_NEW(4, 64e3, 2000, 250, 4, 1000, 0, 2, 1, 0.8, 0,4,512,0);
[signal3, band, B, Nb,s_code3] = Sig_Gernerate_NEW(4, 64e3, 2000, 250, 4, 1000, 0, 2, 1, 0.8, 0,4,512,0);
fs = 64e3; gaptime = 3; gaplength = gaptime*fs;
fc = 2e3; type = 'QPSK'; Baud = 250; roll_factor = 0.8;
pulseWidth = length(signal1)/fs;
frameConut = 3;
totalDuration = 3*(pulseWidth+gaptime);
matName = "WZZ"+'_'+ type+'_fs'+num2str(fs)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_cos'+...
    roll_factor+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.mat' ;
binName0 = "WZZ"+'_'+ type+'_fs'+num2str(fs)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_cos'+...
    roll_factor+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.bin' ;
binName1 = "WZZ"+'_'+ type+'_fs'+num2str(fs/2)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_cos'+...
    roll_factor+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.bin' ;
x0 = [signal1,zeros(1,gaplength),signal2,zeros(1,gaplength),signal3,zeros(1,gaplength)];
STFT_2025(x0, 0 ,2048,512,64000,0,20e3,99);
x1 =resample(x0,1,2);
s_code = [s_code1,s_code2,s_code3];
save(fullfile(savepath,matName),'x0','band','B','Nb','s_code','fs');
fid0 = fopen(fullfile(savepath,binName0),'wb');
fwrite(fid0,x0,'float32');
fclose(fid0);
fid1 = fopen(fullfile(savepath,binName1),'wb');
fwrite(fid1,x1,'float32');
fclose(fid1);

%% 2FSK
clc; clear; close all;
savepath = 'D:\20251029晚测试信号使用\SigADD\测向测试数据2kHz';
[signal1, band, B, Nb,s_code1] = Sig_Gernerate_NEW(2, 64e3, 2000, 100, 4, 1000, 4, 1, 0, 0.8, 0,4,512,0);
[signal2, band, B, Nb,s_code2] = Sig_Gernerate_NEW(2, 64e3, 2000, 100, 4, 1000, 4, 1, 0, 0.8, 0,4,512,0);
[signal3, band, B, Nb,s_code3] = Sig_Gernerate_NEW(2, 64e3, 2000, 100, 4, 1000, 4, 1, 0, 0.8, 0,4,512,0);

fs = 64e3; gaptime = 3; gaplength = gaptime*fs;
fc = 2e3; type = '2FSK'; Baud = 100; H = 4;
pulseWidth = length(signal1)/fs;
frameConut = 3;
totalDuration = 3*(pulseWidth+gaptime);
matName = "WZZ"+'_'+ type+'_fs'+num2str(fs)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_h'+...
    H+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.mat' ;
binName0 = "WZZ"+'_'+ type+'_fs'+num2str(fs)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_h'+...
    H+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.bin' ;
binName1 = "WZZ"+'_'+ type+'_fs'+num2str(fs/2)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_h'+...
    H+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.bin' ;
x0 = [signal1,zeros(1,gaplength),signal2,zeros(1,gaplength),signal3,zeros(1,gaplength)];
STFT_2025(x0, 0 ,2048,512,64000,0,20e3,99);
x1 =resample(x0,1,2);
s_code = [s_code1,s_code2,s_code3];
save(fullfile(savepath,matName),'x0','band','B','Nb','s_code','fs','H');
fid0 = fopen(fullfile(savepath,binName0),'wb');
fwrite(fid0,x0,'float32');
fclose(fid0);
fid1 = fopen(fullfile(savepath,binName1),'wb');
fwrite(fid1,x1,'float32');
fclose(fid1);
%% 4FSK
clc; clear; close all;
savepath = 'D:\20251029晚测试信号使用\SigADD\测向测试数据2kHz';                                           
[signal1, band, B, Nb,s_code1] = Sig_Gernerate_NEW(4, 64e3, 2000, 75, 4, 1000, 2, 1, 0, 0.8, 0,4,512,0);
[signal2, band, B, Nb,s_code2] = Sig_Gernerate_NEW(4, 64e3, 2000, 75, 4, 1000, 2, 1, 0, 0.8, 0,4,512,0);
[signal3, band, B, Nb,s_code3] = Sig_Gernerate_NEW(4, 64e3, 2000, 75, 4, 1000, 2, 1, 0, 0.8, 0,4,512,0);

fs = 64e3; gaptime = 3; gaplength = gaptime*fs;
fc = 2e3; type = '4FSK'; Baud = 75; H = 2;
pulseWidth = length(signal1)/fs;
frameConut = 3;
totalDuration = 3*(pulseWidth+gaptime);
matName = "WZZ"+'_'+ type+'_fs'+num2str(fs)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_h'+...
    H+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.mat' ;
binName0 = "WZZ"+'_'+ type+'_fs'+num2str(fs)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_h'+...
    H+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.bin' ;
binName1 = "WZZ"+'_'+ type+'_fs'+num2str(fs/2)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_h'+...
    H+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.bin' ;
x0 = [signal1,zeros(1,gaplength),signal2,zeros(1,gaplength),signal3,zeros(1,gaplength)];
STFT_2025(x0, 0 ,2048,512,64000,0,20e3,99);
x1 =resample(x0,1,2);
s_code = [s_code1,s_code2,s_code3];
save(fullfile(savepath,matName),'x0','band','B','Nb','s_code','fs','H');
fid0 = fopen(fullfile(savepath,binName0),'wb');
fwrite(fid0,x0,'float32');
fclose(fid0);
fid1 = fopen(fullfile(savepath,binName1),'wb');
fwrite(fid1,x1,'float32');
fclose(fid1);

%% DSSS
clc; clear; close all;
savepath = 'D:\20251029晚测试信号使用\SigADD\测向测试数据2kHz';
[signal1, band, B, Nb,s_code1]  = Sig_Gernerate_NEW(2, 64e3, 2000, 0, 8, 500, 0, 5, 1, 0.8, 7, 8, 512, 0);
[signal2, band, B, Nb,s_code2]  = Sig_Gernerate_NEW(2, 64e3, 2000, 0, 8, 500, 0, 5, 1, 0.8, 7, 8, 512, 0);
[signal3, band, B, Nb,s_code3]  = Sig_Gernerate_NEW(2, 64e3, 2000, 0, 8, 500, 0, 5, 1, 0.8, 7, 8, 512, 0);
fs = 64e3; gaptime = 3; gaplength = gaptime*fs;
fc = 2e3; type = 'DSSS'; roll_factor = 0.8;PNorder = 7; WavNum = 8;
pulseWidth = length(signal1)/fs;Baud = Nb/pulseWidth;
frameConut = 3;
totalDuration = 3*(pulseWidth+gaptime);
matName = "WZZ"+'_'+ type+'_fs'+num2str(fs)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_cos'+...
    roll_factor+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.mat' ;
binName0 = "WZZ"+'_'+ type+'_fs'+num2str(fs)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_cos'+...
    roll_factor+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.bin' ;
binName1 = "WZZ"+'_'+ type+'_fs'+num2str(fs/2)+'_fc'+num2str(fc)+'_B'+num2str(B)+'_Baud'+Baud+ '_cos'+...
    roll_factor+'_tau'+num2str(pulseWidth)+'s_Num'+num2str(frameConut)+'_t'+totalDuration+'s.bin' ;
x0 = [signal1,zeros(1,gaplength),signal2,zeros(1,gaplength),signal3,zeros(1,gaplength)];
STFT_2025(x0, 0 ,2048,512,64000,0,20e3,99);
x1 =resample(x0,1,2);
s_code = [s_code1,s_code2,s_code3];
save(fullfile(savepath,matName),'x0','band','B','Nb','s_code','fs','PNorder','WavNum');
fid0 = fopen(fullfile(savepath,binName0),'wb');
fwrite(fid0,x0,'float32');
fclose(fid0);
fid1 = fopen(fullfile(savepath,binName1),'wb');
fwrite(fid1,x1,'float32');
fclose(fid1);
