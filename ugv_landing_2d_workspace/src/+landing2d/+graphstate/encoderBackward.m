function [grads,dS] = encoderBackward(params,spec,cache,dG)
% ENCODERBACKWARD  encoderForward의 역전파. PPO 손실의 기울기를 부호기까지 보냅니다.
%
%   dG : [graphDim x B]  g_t에 대한 손실 기울기
%
% 정확성은 tests/test_graph_state_encoder.m에서 중앙 차분과 비교해 확인합니다.
if ismember(spec.mode,{'baseline','semantic_flat'})
    grads = struct();
    dS = dG;
    return;
end
B = cache.B;
N = cache.N;
dh = cache.dh;
grads = struct();

% ---- 읽기 역전파. 평균은 모든 노드에 고르게, 최댓값은 argmax 노드에만.
switch spec.readout
    case 'meanmax'
        preOutput = dG.*(1-cache.g.^2);
        grads.Wg = preOutput*cache.readout';
        grads.bg = sum(preOutput,2);
        dReadout = params.Wg'*preOutput;
        dMean = dReadout(1:dh,:);
        dMax = dReadout(dh+1:end,:);
    case 'mean'
        dMean = dG;
        dMax = [];
end
dH = repmat(reshape(dMean/N,dh,1,B),1,N,1);
if ~isempty(dMax)
    rowIndex = repmat((1:dh)',1,B);
    batchIndex = repmat(1:B,dh,1);
    linear = sub2ind([dh,N,B],rowIndex,cache.argMax,batchIndex);
    dH(linear) = dH(linear)+dMax;
end

% ---- 부호기 본체 역전파.
switch spec.mode
    case 'node_pool'
        dZn = reshape(dH.*(1-cache.H.^2),dh,N*B);
        grads.Wn = dZn*cache.Xf';
        grads.bn = sum(dZn,2);
        dS = reshape(params.Wn'*dZn,spec.inDim*N,B);
    case {'gat','ontology_rgat'}
        % 두 번째 층 출력의 tanh와 잔차 연결. potentialBackward와 같은 구조입니다.
        preH2 = dH.*(1-cache.H.^2);
        [dH1FromLayer2,grads2] = landing2d.rgat.relationBackward(preH2,cache.cache2);
        dH1 = preH2+dH1FromLayer2;
        preH1 = dH1.*(1-cache.H1.^2);
        [dX,grads1] = landing2d.rgat.relationBackward(preH1,cache.cache1);
        grads.W1 = grads1.W; grads.a1 = grads1.a; grads.E1 = grads1.E;
        grads.W2 = grads2.W; grads.a2 = grads2.a; grads.E2 = grads2.E;
        dS = reshape(dX,spec.inDim*N,B);
end

% params와 같은 필드 순서를 유지해야 Adam이 짝을 맞출 수 있습니다.
grads = orderfields(grads,params);
end
