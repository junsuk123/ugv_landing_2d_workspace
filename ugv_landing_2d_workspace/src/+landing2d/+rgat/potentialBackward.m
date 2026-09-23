function grads = potentialBackward(cache,dphi)
% POTENTIALBACKWARD  Phi(G)에 대한 손실 기울기를 전체 파라미터로 역전파.
dh = cache.dh;
N = cache.N;
B = cache.B;
preOutput = dphi.*(1-cache.phi.^2);
grads.wOut = preOutput*cache.goal';
grads.bOut = sum(preOutput);
dGoal = cache.wOut'*preOutput;
dH2 = zeros(dh,N,B);
dH2(:,cache.T.goalNode,:) = reshape(dGoal,dh,1,B);
% 두 번째 층 출력의 tanh와 잔차 연결
preH2 = dH2.*(1-cache.H2.^2);
[dH1FromLayer2,grads2] = landing2d.rgat.relationBackward(preH2,cache.cache2);
dH1 = preH2+dH1FromLayer2;
preH1 = dH1.*(1-cache.H1.^2);
[~,grads1] = landing2d.rgat.relationBackward(preH1,cache.cache1);
grads.W1 = grads1.W; grads.a1 = grads1.a; grads.E1 = grads1.E;
grads.W2 = grads2.W; grads.a2 = grads2.a; grads.E2 = grads2.E;
end
