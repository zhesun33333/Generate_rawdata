function [line_freqs, line_sources, line_harmonic_orders] = gen_physically_coupled_line_freqs( ...
    cfg, num_lines, shaft_freq_hz, blade_freq_hz, blade_num, min_sep_hz)
%GEN_PHYSICALLY_COUPLED_LINE_FREQS 生成与轴频/叶频/桨叶数关联的线谱频率。
%
% 设计原则：
%   1) 每条样本总线谱数仍为 3-10 根；
%   2) 优先生成 1-3 根与机械结构相关的线谱：
%        shaft harmonics: h * f_shaft
%        blade harmonics: h * f_blade = h * blade_num * f_shaft
%   3) 其余线谱作为随机机械线谱，在指定频率范围内随机生成；
%   4) 所有线谱之间尽量保持 min_sep_hz 间隔；
%   5) 对机械相关线谱加入很小频率抖动，避免所有样本完全落在整数谐波上。

freqRange = cfg.lineFreqRange;
line_freqs = [];
line_sources = {};
line_harmonic_orders = [];

% 机械相关线谱数量：总线谱少时至少 1 根，总线谱多时最多 3 根。
num_forced = min(3, max(1, floor(num_lines / 3)));

% 构造候选机械线谱池。
cand_freqs = [];
cand_sources = {};
cand_orders = [];

% 轴频谐波候选。为了避免低于 10 Hz，允许使用高阶轴频谐波。
max_shaft_order = max(1, floor(freqRange(2) / shaft_freq_hz));
for h = 1:max_shaft_order
    f0 = h * shaft_freq_hz;
    if f0 >= freqRange(1) && f0 <= freqRange(2)
        cand_freqs(end+1) = f0; %#ok<AGROW>
        cand_sources{end+1} = 'shaft_harmonic'; %#ok<AGROW>
        cand_orders(end+1) = h; %#ok<AGROW>
    end
end

% 叶频及其谐波候选。
max_blade_order = max(1, floor(freqRange(2) / blade_freq_hz));
for h = 1:max_blade_order
    f0 = h * blade_freq_hz;
    if f0 >= freqRange(1) && f0 <= freqRange(2)
        cand_freqs(end+1) = f0; %#ok<AGROW>
        cand_sources{end+1} = 'blade_harmonic'; %#ok<AGROW>
        cand_orders(end+1) = h; %#ok<AGROW>
    end
end

% 打乱候选池，避免总是选最低阶。
if ~isempty(cand_freqs)
    order = randperm(numel(cand_freqs));
    cand_freqs = cand_freqs(order);
    cand_sources = cand_sources(order);
    cand_orders = cand_orders(order);
end

% 从候选池中挑选机械相关线谱。
for i = 1:numel(cand_freqs)
    if numel(line_freqs) >= num_forced
        break;
    end

    % 小抖动：机械线谱并非严格定频，保留物理关联但增加样本多样性。
    jitter_hz = rand_uniform([-0.3, 0.3]);
    f_try = cand_freqs(i) + jitter_hz;
    f_try = min(max(f_try, freqRange(1)), freqRange(2));

    if can_add_freq(f_try, line_freqs, min_sep_hz)
        line_freqs(end+1) = f_try; %#ok<AGROW>
        line_sources{end+1} = cand_sources{i}; %#ok<AGROW>
        line_harmonic_orders(end+1) = cand_orders(i); %#ok<AGROW>
    end
end

% 如果候选不足，用随机机械线谱补齐 forced 部分。
while numel(line_freqs) < num_forced
    f_try = rand_uniform(freqRange);
    if can_add_freq(f_try, line_freqs, min_sep_hz)
        line_freqs(end+1) = f_try; %#ok<AGROW>
        line_sources{end+1} = 'random_mechanical'; %#ok<AGROW>
        line_harmonic_orders(end+1) = 0; %#ok<AGROW>
    end
end

% 其余频率随机生成。
max_try = 10000;
try_count = 0;
while numel(line_freqs) < num_lines && try_count < max_try
    try_count = try_count + 1;
    f_try = rand_uniform(freqRange);
    if can_add_freq(f_try, line_freqs, min_sep_hz)
        line_freqs(end+1) = f_try; %#ok<AGROW>
        line_sources{end+1} = 'random_mechanical'; %#ok<AGROW>
        line_harmonic_orders(end+1) = 0; %#ok<AGROW>
    end
end

% 极端情况下如果间隔约束无法满足，就放宽补齐。
while numel(line_freqs) < num_lines
    f_try = rand_uniform(freqRange);
    line_freqs(end+1) = f_try; %#ok<AGROW>
    line_sources{end+1} = 'random_mechanical_relaxed_sep'; %#ok<AGROW>
    line_harmonic_orders(end+1) = 0; %#ok<AGROW>
end

% 按频率排序，同时保持来源信息同步。
[line_freqs, sort_idx] = sort(line_freqs);
line_sources = line_sources(sort_idx);
line_harmonic_orders = line_harmonic_orders(sort_idx);

% 转成列向量/行 cell，便于后续写 json。
line_freqs = line_freqs(:)';
line_harmonic_orders = line_harmonic_orders(:)';

% 附加桨叶数信息仅用于说明，具体数值通过 meta.propeller.blade_number 记录。
if blade_num <= 0
    warning('Invalid blade number.');
end

end

function ok = can_add_freq(f_try, existing_freqs, min_sep_hz)
if isempty(existing_freqs)
    ok = true;
else
    ok = all(abs(existing_freqs - f_try) >= min_sep_hz);
end
end
