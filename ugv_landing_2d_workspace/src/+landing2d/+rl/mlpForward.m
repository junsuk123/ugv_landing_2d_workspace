function [y,cache] = mlpForward(net,X)
% MLPFORWARD  X는 (입력차원 x 표본수). 은닉층 tanh, 출력층 선형.
nLayer = numel(net.W);
cache = cell(nLayer+1,1);
cache{1} = X;
h = X;
for l = 1:nLayer
    z = net.W{l}*h+net.b{l};
    if l < nLayer
        h = tanh(z);
    else
        h = z;
    end
    cache{l+1} = h;
end
y = h;
end
