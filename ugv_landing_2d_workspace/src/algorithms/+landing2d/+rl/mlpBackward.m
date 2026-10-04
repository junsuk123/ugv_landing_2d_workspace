function [grads,dX] = mlpBackward(net,cache,dY)
% MLPBACKWARD  출력 기울기 dY로부터 가중치 기울기 계산. tanh 미분은 1-a^2.
% 두 번째 출력 dX는 입력에 대한 기울기입니다. 그래프 부호기를 정책/가치망 앞에
% 붙였을 때 PPO 손실을 부호기까지 이어서 흘려보내는 데 씁니다.
% 가중치 기울기 grads는 이 출력을 추가하기 전과 완전히 같습니다.
nLayer = numel(net.W);
grads.W = cell(nLayer,1);
grads.b = cell(nLayer,1);
delta = dY;
for l = nLayer:-1:1
    grads.W{l} = delta*cache{l}';
    grads.b{l} = sum(delta,2);
    delta = net.W{l}'*delta;
    if l > 1
        delta = delta.*(1-cache{l}.^2);
    end
end
dX = delta;
end
