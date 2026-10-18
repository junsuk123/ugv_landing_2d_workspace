function [Z,cache] = relationForward(X,W,a,E,T,diagnosticEdgeKeep,attentionMode)
% RELATIONFORWARD  관계별 사영 + 도착 노드 기준 정규화 주의 (R-GAT 한 계층).
%   X : [din x nNodes] 또는 [din x nNodes x B]  노드 특징 (X_t, 학습된 노드 임베딩 아님)
%   W : [dout x din x nRelations]
%   a : [1 x (2*dout+relationDim) x nRelations]
%   E : [relationDim x nRelations]
%   Z : [dout x nNodes (x B)]  도착 노드별로 집계한 메시지 (활성화 이전)
% attentionMode='input_dependent_v1'은 기존 노드 특징 의존 점수입니다.
% attentionMode='fixed_relation_v1'은 a/E에서 관계 유형별 고정 사전 활성값을
% 학습합니다. 이 값과 alpha는 입력 X에 의존하지 않으며, 학습 완료 후
% 파라미터와 함께 동결됩니다. 두 모드는 같은 파라미터 수를 유지합니다.
% 단계: attentionPreActivation(leaky ReLU 이전) -> attentionScore(leaky ReLU
% 이후, softmax 입력) -> alpha(도착 노드 기준 softmax로 정규화한 attention 계수,
% 들어오는 간선 합 1). alpha는 집계 가중치이며 인과적 중요도가 아닙니다.
% 점수는 leaky ReLU(기울기 0.2), 정규화는 분모 하한 1e-9의 softmax입니다.
% 원 저장소 rgat.relationLayer와 같은 연산이며 dlarray 없이 계산합니다.
% Optional live-only binary mask: zero selected messages AFTER softmax,
% without renormalizing the surviving edges. Never used for training.
if nargin<6, diagnosticEdgeKeep=[]; end
if nargin<7 || isempty(attentionMode), attentionMode='fixed_relation_v1'; end
assert(ismember(attentionMode,{'input_dependent_v1','fixed_relation_v1'}), ...
    'landing2d:RgatAttentionMode','Unknown relation attention mode %s.',attentionMode);
if ndims(X) < 3
    X = reshape(X,size(X,1),size(X,2),1);
end
[din,N,B] = size(X);
dout = size(W,1);
R = size(W,3);
nEdges = T.nEdges;
if N ~= T.nNodes
    error('landing2d:RgatNodes','Feature matrix has %d nodes, graph has %d.',N,T.nNodes);
end
Xf = reshape(X,din,N*B);
projected = zeros(dout,N*B,R);
srcAttentionTerm = zeros(R,N*B);
dstAttentionTerm = zeros(R,N*B);
relationAttentionTerm = zeros(R,1);
fixedRelationPreActivation = zeros(R,1);
for r = 1:R
    projectedR = W(:,:,r)*Xf;
    projected(:,:,r) = projectedR;
    if strcmp(attentionMode,'input_dependent_v1')
        srcAttentionTerm(r,:) = a(1,1:dout,r)*projectedR;
        dstAttentionTerm(r,:) = a(1,dout+1:2*dout,r)*projectedR;
        relationAttentionTerm(r) = a(1,2*dout+1:end,r)*E(:,r);
    else
        % Use every legacy attention parameter while producing one scalar
        % beta_r per relation. The mean term and relation-embedding bilinear
        % term are observation independent and preserve the 6,101-parameter
        % planar comparison contract.
        fixedRelationPreActivation(r) = mean(a(1,1:2*dout,r)) ...
            +a(1,2*dout+1:end,r)*E(:,r);
    end
end
projectedAll = zeros(dout,N*R,B);
for r = 1:R
    projectedAll(:,(r-1)*N+(1:N),:) = reshape(projected(:,:,r),dout,N,B);
end
if strcmp(attentionMode,'input_dependent_v1')
    attentionPreActivation = reshape(srcAttentionTerm,R*N,B);
    attentionPreActivation = attentionPreActivation(T.idxSrc,:);
    dstTerm = reshape(dstAttentionTerm,R*N,B);
    attentionPreActivation = attentionPreActivation+dstTerm(T.idxDst,:) ...
        +reshape(relationAttentionTerm(T.rel),nEdges,1);
else
    attentionPreActivation = repmat(reshape(fixedRelationPreActivation(T.rel),nEdges,1),1,B);
end
attentionScore = 0.6*attentionPreActivation+0.4*abs(attentionPreActivation);
expScore = exp(attentionScore);
denominator = T.Msel*expScore+1e-9;
alpha = expScore./denominator(T.dst,:);
if ~isempty(diagnosticEdgeKeep)
    validateattributes(diagnosticEdgeKeep,{'logical','numeric'}, ...
        {'vector','numel',nEdges,'binary','real','finite'});
    originalAlpha=alpha;
    alpha=alpha.*double(diagnosticEdgeKeep(:));
end
edgeMessages = projectedAll(:,T.colIdx,:);
weightedMessages = edgeMessages.*reshape(alpha,1,nEdges,B);
Z = permute(reshape(T.Msel*reshape(permute(weightedMessages,[2,1,3]),nEdges,dout*B), ...
    N,dout,B),[2,1,3]);
if B == 1
    Z = reshape(Z,dout,N);
end
cache = struct('X',X,'Xf',Xf,'W',W,'a',a,'E',E,'T',T,'projected',projected, ...
    'attentionPreActivation',attentionPreActivation,'alpha',alpha, ...
    'edgeMessages',edgeMessages,'din',din,'dout',dout, ...
    'N',N,'B',B,'R',R,'attentionMode',attentionMode, ...
    'fixedRelationPreActivation',fixedRelationPreActivation);
if ~isempty(diagnosticEdgeKeep)
    cache.diagnosticEdgeKeep=logical(diagnosticEdgeKeep(:));
    cache.originalAlpha=originalAlpha;
end
end
