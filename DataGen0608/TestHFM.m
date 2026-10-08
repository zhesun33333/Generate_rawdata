Fs = 16e3;
tau = 3;

start_freq_hz = 5000;
end_freq_hz = 7000;
[signal, band, B, Nb, s_code] = generate_hfm(Fs, tau, start_freq_hz, end_freq_hz);
STFT_2026 (signal, 0 ,1024,256,Fs,100,8e3);


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