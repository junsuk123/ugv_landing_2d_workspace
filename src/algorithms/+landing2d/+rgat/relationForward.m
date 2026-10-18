function [Z,cache] = relationForward(H,W,a,E,T,diagnosticEdgeKeep,attentionMode)
% RELATIONFORWARD  관계별 사영 + 도착 노드 기준 정규화 주의 (R-GAT 한 계층).
%   H : [din x nNodes] 또는 [din x nNodes x B]
%   W : [dout x din x nRelations]
%   a : [1 x (2*dout+relationDim) x nRelations]
%   E : [relationDim x nRelations]
% attentionMode='input_dependent_v1'은 기존 노드 특징 의존 점수입니다.
% attentionMode='fixed_relation_v1'은 a/E에서 관계 유형별 고정 로짓을
% 학습합니다. 이 로짓과 alpha는 입력 H에 의존하지 않으며, 학습 완료 후
% 파라미터와 함께 동결됩니다. 두 모드는 같은 파라미터 수를 유지합니다.
% 점수는 leaky ReLU(기울기 0.2), 정규화는 분모 하한 1e-9의 softmax입니다.
% 원 저장소 rgat.relationLayer와 같은 연산이며 dlarray 없이 계산합니다.
% Optional live-only binary mask: zero selected messages AFTER softmax,
% without renormalizing the surviving edges. Never used for training.
if nargin<6, diagnosticEdgeKeep=[]; end
if nargin<7 || isempty(attentionMode), attentionMode='fixed_relation_v1'; end
assert(ismember(attentionMode,{'input_dependent_v1','fixed_relation_v1'}), ...
    'landing2d:RgatAttentionMode','Unknown relation attention mode %s.',attentionMode);
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
relationRaw = zeros(R,1);
for r = 1:R
    HWr = W(:,:,r)*Hf;
    HW(:,:,r) = HWr;
    if strcmp(attentionMode,'input_dependent_v1')
        an(r,:) = a(1,1:dout,r)*HWr;
        bn(r,:) = a(1,dout+1:2*dout,r)*HWr;
        sc(r) = a(1,2*dout+1:end,r)*E(:,r);
    else
        % Use every legacy attention parameter while producing one scalar
        % beta_r per relation. The mean term and relation-embedding bilinear
        % term are observation independent and preserve the 6,101-parameter
        % planar comparison contract.
        relationRaw(r) = mean(a(1,1:2*dout,r)) ...
            +a(1,2*dout+1:end,r)*E(:,r);
    end
end
HWall = zeros(dout,N*R,B);
for r = 1:R
    HWall(:,(r-1)*N+(1:N),:) = reshape(HW(:,:,r),dout,N,B);
end
if strcmp(attentionMode,'input_dependent_v1')
    raw = reshape(an,R*N,B);
    raw = raw(T.idxSrc,:);
    dstPart = reshape(bn,R*N,B);
    raw = raw+dstPart(T.idxDst,:)+reshape(sc(T.rel),nEdges,1);
else
    raw = repmat(reshape(relationRaw(T.rel),nEdges,1),1,B);
end
score = 0.6*raw+0.4*abs(raw);
expScore = exp(score);
denominator = T.Msel*expScore+1e-9;
alpha = expScore./denominator(T.dst,:);
if ~isempty(diagnosticEdgeKeep)
    validateattributes(diagnosticEdgeKeep,{'logical','numeric'}, ...
        {'vector','numel',nEdges,'binary','real','finite'});
    originalAlpha=alpha;
    alpha=alpha.*double(diagnosticEdgeKeep(:));
end
msgs = HWall(:,T.colIdx,:);
weighted = msgs.*reshape(alpha,1,nEdges,B);
Z = permute(reshape(T.Msel*reshape(permute(weighted,[2,1,3]),nEdges,dout*B), ...
    N,dout,B),[2,1,3]);
if B == 1
    Z = reshape(Z,dout,N);
end
cache = struct('H',H,'Hf',Hf,'W',W,'a',a,'E',E,'T',T,'HW',HW, ...
    'raw',raw,'alpha',alpha,'msgs',msgs,'din',din,'dout',dout, ...
    'N',N,'B',B,'R',R,'attentionMode',attentionMode, ...
    'relationRaw',relationRaw);
if ~isempty(diagnosticEdgeKeep)
    cache.diagnosticEdgeKeep=logical(diagnosticEdgeKeep(:));
    cache.originalAlpha=originalAlpha;
end
end
