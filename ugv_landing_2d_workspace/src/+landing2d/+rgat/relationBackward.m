function [dH,grads] = relationBackward(dZ,cache)
% RELATIONBACKWARD  relationForward의 역전파. 직접 구현한 기울기입니다.
% 정확성은 tests/test_rgat_gradients.m에서 중앙 차분과 비교해 확인합니다.
T = cache.T;
dout = cache.dout;
din = cache.din;
N = cache.N;
B = cache.B;
R = cache.R;
nEdges = T.nEdges;
if ndims(dZ) < 3
    dZ = reshape(dZ,dout,N,1);
end

% 1. 도착 노드 합산 -> 간선별 기여
dWeighted = dZ(:,T.dst,:);
% 2. 주의 가중치와 메시지로 분리
dAlpha = reshape(sum(dWeighted.*cache.msgs,1),nEdges,B);
dMsgs = dWeighted.*reshape(cache.alpha,1,nEdges,B);
% 3. 메시지를 (출발 노드, 관계) 열로 되돌림
dHWall = permute(reshape(T.Mcol*reshape(permute(dMsgs,[2,1,3]),nEdges,dout*B), ...
    N*R,dout,B),[2,1,3]);
% 4. 도착 노드 기준 softmax 역전파
weightedSum = T.Msel*(dAlpha.*cache.alpha);
dScore = cache.alpha.*(dAlpha-weightedSum(T.dst,:));
% 5. leaky ReLU
dRaw = dScore.*(0.6+0.4*sign(cache.raw));
% 6. 간선 점수 -> 노드/관계 축
dAall = T.Msrc*dRaw;
dBall = T.Mdst*dRaw;
dRelationScore = sum(T.Mrel*dRaw,2);

dan = reshape(dAall,R,N*B);
dbn = reshape(dBall,R,N*B);
grads.W = zeros(size(cache.W));
grads.a = zeros(size(cache.a));
grads.E = zeros(size(cache.E));
dHf = zeros(din,N*B);
for r = 1:R
    HWr = cache.HW(:,:,r);
    dHWr = reshape(dHWall(:,(r-1)*N+(1:N),:),dout,N*B);
    % 7. 주의 점수의 출발/도착 반쪽
    grads.a(1,1:dout,r) = dan(r,:)*HWr';
    grads.a(1,dout+1:2*dout,r) = dbn(r,:)*HWr';
    dHWr = dHWr+cache.a(1,1:dout,r)'*dan(r,:)+cache.a(1,dout+1:2*dout,r)'*dbn(r,:);
    % 8. 관계 임베딩 항
    grads.a(1,2*dout+1:end,r) = dRelationScore(r)*cache.E(:,r)';
    grads.E(:,r) = dRelationScore(r)*cache.a(1,2*dout+1:end,r)';
    % 9. 관계별 선형 사영
    grads.W(:,:,r) = dHWr*cache.Hf';
    dHf = dHf+cache.W(:,:,r)'*dHWr;
end
dH = reshape(dHf,din,N,B);
end
