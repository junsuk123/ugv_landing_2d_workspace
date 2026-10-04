function [Z,cache] = relationForward(H,W,a,E,T)
% RELATIONFORWARD  관계별 사영 + 도착 노드 기준 정규화 주의 (R-GAT 한 계층).
%   H : [din x nNodes] 또는 [din x nNodes x B]
%   W : [dout x din x nRelations]
%   a : [1 x (2*dout+relationDim) x nRelations]
%   E : [relationDim x nRelations]
% 점수는 leaky ReLU(기울기 0.2), 정규화는 분모 하한 1e-9의 softmax입니다.
% 원 저장소 rgat.relationLayer와 같은 연산이며 dlarray 없이 계산합니다.
if ndims(H) < 3
    H = reshape(H,size(H,1),size(H,2),1);
end
[din,N,B] = size(H);
dout = size(W,1);
R = size(W,3);
nEdges = T.nEdges;
if N ~= T.nNodes
    error('landing2d:RgatNodes','Feature matrix has %d nodes, graph has %d.',N,T.nNodes);
end
Hf = reshape(H,din,N*B);
HW = zeros(dout,N*B,R);
an = zeros(R,N*B);
bn = zeros(R,N*B);
sc = zeros(R,1);
for r = 1:R
    HWr = W(:,:,r)*Hf;
    HW(:,:,r) = HWr;
    an(r,:) = a(1,1:dout,r)*HWr;
    bn(r,:) = a(1,dout+1:2*dout,r)*HWr;
    sc(r) = a(1,2*dout+1:end,r)*E(:,r);
end
HWall = zeros(dout,N*R,B);
for r = 1:R
    HWall(:,(r-1)*N+(1:N),:) = reshape(HW(:,:,r),dout,N,B);
end
raw = reshape(an,R*N,B);
raw = raw(T.idxSrc,:);
dstPart = reshape(bn,R*N,B);
raw = raw+dstPart(T.idxDst,:)+reshape(sc(T.rel),nEdges,1);
score = 0.6*raw+0.4*abs(raw);
expScore = exp(score);
denominator = T.Msel*expScore+1e-9;
alpha = expScore./denominator(T.dst,:);
msgs = HWall(:,T.colIdx,:);
weighted = msgs.*reshape(alpha,1,nEdges,B);
Z = permute(reshape(T.Msel*reshape(permute(weighted,[2,1,3]),nEdges,dout*B), ...
    N,dout,B),[2,1,3]);
if B == 1
    Z = reshape(Z,dout,N);
end
cache = struct('H',H,'Hf',Hf,'W',W,'a',a,'E',E,'T',T,'HW',HW, ...
    'raw',raw,'alpha',alpha,'msgs',msgs,'din',din,'dout',dout, ...
    'N',N,'B',B,'R',R);
end
