function x = rand_uniform_vec(range, n)
%RAND_UNIFORM_VEC 在 [range(1), range(2)] 内均匀采样 n 个数。
x = range(1) + (range(2) - range(1)) * rand(1, n);
end
