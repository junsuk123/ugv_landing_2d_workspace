function [g,cache] = encoderForward(params,spec,policyInput,head)
% ENCODERFORWARD  State representation -> Actor/Critic input.
%   policyInput : [stateDim x B]  12-D o_t (baseline) or the flattened node
%                 features X_t of the same o_t (an observation, not the
%                 environment state)
%   g           : [graphDim x B]  input of the policy/value MLP (graph
%                 embedding g_t for context_rgat, o_t itself for baseline)
% context_rgat, relation operators additive_v1: H = tanh(RGAT(X) + W0 X + b0)
% per node. typed_v1: the 'propagate' edges (and self) form the additive
% attention graph, the 'modulate' edges a second attention graph over the
% the W1/a1/E1 parameter bank registered by encoderInit, and
%   H = (1 + tanh(RGAT_mod(X))) .* tanh(RGAT_prop(X) + W0 X + b0),
% a gate in (0, 2) that is 1 for nodes without modulating edges and starts
% near 1. Then the grouped factorized readout
% g = tanh(sum_k (Wc H_k) .* Wn(:,k) + bg). HEAD ('policy' or 'value') is
% informational: Actor and Critic have separate encoders.
if nargin < 4 || isempty(head), head = 'policy'; end %#ok<NASGU>
if strcmp(spec.mode,'baseline')
    g = policyInput;
    cache = struct('mode',spec.mode);
    return;
end
if isfield(spec,'encoderVersion') && strcmp(spec.encoderVersion,'rgat_v2')
    [g,cache] = forwardV2(params,spec,policyInput);
    return;
end
B = size(policyInput,2); N = spec.nNodes; dh = spec.hiddenDim;
X = reshape(policyInput,spec.inDim,N,B);
Xf = reshape(X,spec.inDim,N*B);
local = reshape(params.W0*Xf+params.b0,dh,N,B);
typed = isfield(spec,'relationOperators') && strcmp(spec.relationOperators,'typed_v1');
if typed
    [Za,cacheAdd] = landing2d.rgat.relationForward(X,params.W1,params.a1, ...
        params.E1,spec.Tadd,[],spec.attentionMode);
    [Zm,cacheMod] = landing2d.rgat.relationForward(X,params.W1,params.a1, ...
        params.E1,spec.Tmod,[],spec.attentionMode);
    A = tanh(reshape(Za,dh,N,B)+local);
    M = tanh(reshape(Zm,dh,N,B));
    H = (1+M).*A;
    % Attention of every edge in spec.T order (diagnostics read cache1.alpha).
    alpha = zeros(spec.T.nEdges,B);
    alpha(spec.addEdges,:) = cacheAdd.alpha; alpha(spec.modEdges,:) = cacheMod.alpha;
    cache1 = struct('alpha',alpha);
else
    [Z1,cache1] = landing2d.rgat.relationForward(X,params.W1,params.a1, ...
        params.E1,spec.T,[],spec.attentionMode);
    H = tanh(reshape(Z1,dh,N,B)+local);
end
K = spec.groupCount;
grouped = zeros(dh,K,B);
channel = zeros(spec.graphDim,K,B);
for b = 1:B
    grouped(:,:,b) = H(:,:,b)*spec.groupMatrix';
    channel(:,:,b) = params.Wc*grouped(:,:,b);
end
g = tanh(reshape(sum(channel.*params.Wn,2),spec.graphDim,B)+params.bg);
cache = struct('mode',spec.mode,'B',B,'N',N,'dh',dh,'cache1',cache1, ...
    'Xf',Xf,'H',H,'grouped',grouped,'channel',channel,'g',g);
if typed
    cache.cacheAdd = cacheAdd; cache.cacheMod = cacheMod; cache.A = A; cache.M = M;
end
end

function [g,cache] = forwardV2(params,spec,policyInput)
% rgat_v2: H^l = tanh(sum_{j->i} alpha_ij W_r(ij) H^{l-1}_j + b_l), alpha
% normalized over every incoming edge of i (all relation types incl. self),
% W_r = sum_b C(r,b) V_b; then g = tanh(sum_k (Wc H^L_k) .* Wn(:,k) + bg).
B = size(policyInput,2); N = spec.nNodes; dh = spec.hiddenDim; L = spec.layers;
previous = reshape(policyInput,spec.inDim,N,B);
layerCaches = cell(1,L); layerH = cell(1,L);
for l = 1:L
    V = params.(sprintf('V%d',l)); C = params.(sprintf('C%d',l));
    W = landing2d.graphstate.basisWeights(V,C);
    [Z,layerCaches{l}] = landing2d.rgat.relationForward(previous,W, ...
        params.(sprintf('a%d',l)),params.(sprintf('E%d',l)),spec.T,[],spec.attentionMode);
    layerH{l} = tanh(reshape(Z,dh,N,B)+params.(sprintf('b%d',l)));
    previous = layerH{l};
end
H = previous;
K = spec.groupCount;
grouped = zeros(dh,K,B);
channel = zeros(spec.graphDim,K,B);
for b = 1:B
    grouped(:,:,b) = H(:,:,b)*spec.groupMatrix';
    channel(:,:,b) = params.Wc*grouped(:,:,b);
end
g = tanh(reshape(sum(channel.*params.Wn,2),spec.graphDim,B)+params.bg);
% cache1 = first layer (the attention diagnostics read cache1.alpha).
cache = struct('mode',spec.mode,'encoderVersion','rgat_v2','B',B,'N',N,'dh',dh, ...
    'cache1',layerCaches{1},'layerCaches',{layerCaches},'layerH',{layerH}, ...
    'Xf',reshape(policyInput,spec.inDim,N*B),'H',H,'grouped',grouped, ...
    'channel',channel,'g',g);
end
