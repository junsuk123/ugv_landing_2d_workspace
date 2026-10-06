function net = mlpInit(sizes,outputGain,rs)
% MLPINIT  tanh 은닉층 + 선형 출력층 다층 퍼셉트론 초기화.
% sizes = [입력, 은닉1, ..., 출력]. outputGain은 마지막 층 초기 가중치 배율.
% 별도 Toolbox 없이 셀 배열 가중치만 사용합니다.
nLayer = numel(sizes)-1;
net.W = cell(nLayer,1);
net.b = cell(nLayer,1);
for l = 1:nLayer
    gain = sqrt(1/sizes(l));
    if l == nLayer
        gain = gain*outputGain;
    end
    net.W{l} = gain*randn(rs,sizes(l+1),sizes(l));
    net.b{l} = zeros(sizes(l+1),1);
end
end
