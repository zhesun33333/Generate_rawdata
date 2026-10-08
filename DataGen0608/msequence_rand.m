% m序列的生成
function [c,a]=msequence_rand(N)

% 这里c的顺序为[c1 c2 …… cn]  例n=5时c=[0 1 0 0 1];
% a是n元初始向量，不全为0即可，例a=[0 0 0 0 1];
% n=length(c);
% a=a1;

if (N<3||N>12)
    disp('阶数必须在3~12之间!');
else
    a = ones(1,N);
    c_all = gfprimfd(N,'all');
    len_size=size(c_all,1);
    len_chose=round(rand(1,100)*(len_size-1))+1;
    a_chose=len_chose(50);
    c=c_all(a_chose,2:end);          
end
for i=N+1:2^N-1;
    a(i)=mod(sum(c.*a((i-1):-1:(i-N))),2);
end
a=(a-0.5)*2;     