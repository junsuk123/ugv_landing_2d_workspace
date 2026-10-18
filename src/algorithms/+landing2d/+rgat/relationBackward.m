function [dX,grads] = relationBackward(dZ,cache)
% RELATIONBACKWARD  relationForward의 역전파. 직접 구현한 기울기입니다.
% dX는 입력 노드 특징 X에 대한 기울기입니다. 정확성은 selfTest의
% relation-attention 검사에서 중앙 차분과 비교해 확인합니다.
assert(~isfield(cache,'diagnosticEdgeKeep'),'landing2d:DiagnosticInferenceOnly', ...
    'Live edge interventions are inference-only; backpropagation is forbidden.');
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
dWeightedMessages = dZ(:,T.dst,:);
% 2. 주의 가중치와 메시지로 분리
dAlpha = reshape(sum(dWeightedMessages.*cache.edgeMessages,1),nEdges,B);
dEdgeMessages = dWeightedMessages.*reshape(cache.alpha,1,nEdges,B);
% 3. 메시지를 (출발 노드, 관계) 열로 되돌림
dProjectedAll = permute(reshape(T.Mcol*reshape(permute(dEdgeMessages,[2,1,3]),nEdges,dout*B), ...
    N*R,dout,B),[2,1,3]);
% 4. 도착 노드 기준 softmax 역전파
weightedSum = T.Msel*(dAlpha.*cache.alpha);
dAttentionScore = cache.alpha.*(dAlpha-weightedSum(T.dst,:));
% 5. leaky ReLU
dAttentionPreActivation = dAttentionScore.*(0.6+0.4*sign(cache.attentionPreActivation));
% 6. 간선 점수 -> 노드/관계 축
dRelationAttentionTerm = sum(T.Mrel*dAttentionPreActivation,2);
grads.W = zeros(size(cache.W));
grads.a = zeros(size(cache.a));
grads.E = zeros(size(cache.E));
dXf = zeros(din,N*B);
if strcmp(cache.attentionMode,'input_dependent_v1')
    dSrcAll = T.Msrc*dAttentionPreActivation;
    dDstAll = T.Mdst*dAttentionPreActivation;
    dSrcAttentionTerm = reshape(dSrcAll,R,N*B);
    dDstAttentionTerm = reshape(dDstAll,R,N*B);
    for r = 1:R
        projectedR = cache.projected(:,:,r);
        dProjectedR = reshape(dProjectedAll(:,(r-1)*N+(1:N),:),dout,N*B);
        % 7. 주의 점수의 출발/도착 반쪽
        grads.a(1,1:dout,r) = dSrcAttentionTerm(r,:)*projectedR';
        grads.a(1,dout+1:2*dout,r) = dDstAttentionTerm(r,:)*projectedR';
        dProjectedR = dProjectedR+cache.a(1,1:dout,r)'*dSrcAttentionTerm(r,:) ...
            +cache.a(1,dout+1:2*dout,r)'*dDstAttentionTerm(r,:);
        % 8. 관계 임베딩 항
        grads.a(1,2*dout+1:end,r) = dRelationAttentionTerm(r)*cache.E(:,r)';
        grads.E(:,r) = dRelationAttentionTerm(r)*cache.a(1,2*dout+1:end,r)';
        % 9. 관계별 선형 사영
        grads.W(:,:,r) = dProjectedR*cache.Xf';
        dXf = dXf+cache.W(:,:,r)'*dProjectedR;
    end
else
    for r = 1:R
        dProjectedR = reshape(dProjectedAll(:,(r-1)*N+(1:N),:),dout,N*B);
        % beta_r = mean(a_state_r) + a_relation_r * E_r. No gradient
        % reaches X through alpha because fixed_relation_v1 is input-free.
        grads.a(1,1:2*dout,r) = dRelationAttentionTerm(r)/(2*dout);
        grads.a(1,2*dout+1:end,r) = dRelationAttentionTerm(r)*cache.E(:,r)';
        grads.E(:,r) = dRelationAttentionTerm(r)*cache.a(1,2*dout+1:end,r)';
        grads.W(:,:,r) = dProjectedR*cache.Xf';
        dXf = dXf+cache.W(:,:,r)'*dProjectedR;
    end
end
dX = reshape(dXf,din,N,B);
end
