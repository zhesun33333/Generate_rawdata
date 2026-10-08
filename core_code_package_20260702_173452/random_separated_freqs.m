function freqs = random_separated_freqs(freqRange, num_lines, min_sep_hz)
%RANDOM_SEPARATED_FREQS 随机生成互相间隔至少 min_sep_hz 的线谱频率。

max_try = 10000;
freqs = [];

for i = 1:max_try
    f0 = rand_uniform(freqRange);

    if isempty(freqs)
        freqs = f0;
    else
        if all(abs(freqs - f0) >= min_sep_hz)
            freqs(end+1) = f0; %#ok<AGROW>
        end
    end

    if numel(freqs) >= num_lines
        break;
    end
end

if numel(freqs) < num_lines
    warning('Could not satisfy min frequency separation. Filling randomly.');
    while numel(freqs) < num_lines
        freqs(end+1) = rand_uniform(freqRange); %#ok<AGROW>
    end
end

freqs = sort(freqs);

end
