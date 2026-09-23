function [g,cache] = encoderForward(params,spec,S)
% ENCODERFORWARD  상태 표현 g_t = READOUT(R-GAT(G_t)).
%
%   S : [stateDim x B]   펴 놓은 노드 특징 행렬 X_t (baseline이면 관측 벡터)
%   g : [graphDim x B]   그래프 수준 표현 g_t
%
% 중간 결과 H_t는 [hiddenDim x nNodes x B]이며 모든 노드가 읽기에 들어갑니다.
% 특정 노드(예: 목표 노드)를 골라 쓰지 않습니다. 그 점이 보상 설계에 쓰는
% landing2d.rgat.potentialForward와 다릅니다.
if strcmp(spec.mode,'baseline')
    g = S;
    cache = struct('mode','baseline');
    return;
end
B = size(S,2);
N = spec.nNodes;
dh = spec.hiddenDim;
X = reshape(S,spec.inDim,N,B);
cache = struct('mode',spec.mode,'B',B,'N',N,'dh',dh);
switch spec.mode
    case 'node_pool'
        Xf = reshape(X,spec.inDim,N*B);
        H = tanh(reshape(params.Wn*Xf+params.bn,dh,N,B));
        cache.Xf = Xf;
    case {'gat','ontology_rgat'}
        [Z1,cache1] = landing2d.rgat.relationForward(X,params.W1,params.a1, ...
            params.E1,spec.T);
        H1 = tanh(reshape(Z1,dh,N,B));
        [Z2,cache2] = landing2d.rgat.relationForward(H1,params.W2,params.a2, ...
            params.E2,spec.T);
        H = tanh(reshape(Z2,dh,N,B)+H1);
        cache.cache1 = cache1;
        cache.cache2 = cache2;
        cache.H1 = H1;
    otherwise
        error('landing2d:UnknownStateRepresentation', ...
            'encoderForward does not handle stateRepresentation %s.',spec.mode);
end
cache.H = H;

% ---- 그래프 수준 읽기. 모든 노드에 대해 평균/최댓값을 취합니다.
hMean = reshape(mean(H,2),dh,B);
switch spec.readout
    case 'meanmax'
        [maxValue,argMax] = max(H,[],2);
        hMax = reshape(maxValue,dh,B);
        readout = [hMean;hMax];
        g = tanh(params.Wg*readout+params.bg);
        cache.readout = readout;
        cache.argMax = reshape(argMax,dh,B);
        cache.g = g;
    case 'mean'
        g = hMean;
    otherwise
        error('landing2d:UnknownReadout','Unknown readout: %s',spec.readout);
end
end
