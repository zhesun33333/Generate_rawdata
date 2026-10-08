function x = rand_uniform(range)
%RAND_UNIFORM 在 [range(1), range(2)] 内均匀采样一个数。
x = range(1) + (range(2) - range(1)) * rand;
end
