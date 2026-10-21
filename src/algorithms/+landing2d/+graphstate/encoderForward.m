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
% g = tanh(sum_k (Wc H_k) .* Wn(:,k) + bg). rgat_v2 can instead use the
% registered node-shared mean form with one Wn column and a 1/K average.
% HEAD ('policy' or 'value') is informational: Actor and Critic have
% separate encoders.
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
if isfield(spec,'readoutParameterization') ...
        && strcmp(spec.readoutParameterization,'node_shared_mean_v1')
    readoutPreActivation = reshape(sum(channel.*params.Wn,2)/K,spec.graphDim,B)+params.bg;
else
    readoutPreActivation = reshape(sum(channel.*params.Wn,2),spec.graphDim,B)+params.bg;
end
g = tanh(readoutPreActivation);
cache = struct('mode',spec.mode,'B',B,'N',N,'dh',dh,'cache1',cache1, ...
    'Xf',Xf,'H',H,'grouped',grouped,'channel',channel,'g',g);
if typed
    cache.cacheAdd = cacheAdd; cache.cacheMod = cacheMod; cache.A = A; cache.M = M;
end
end

function [g,cache] = forwardV2(params,spec,policyInput)
% rgat_v2: F^l = tanh(Wroot_l H^{l-1}_i + sum_{j->i} alpha_ij W_r(ij) H^{l-1}_j
% + b_l), alpha normalized over every incoming edge of i (all relation types
% incl. self), W_r = sum_b C(r,b) V_b (R-GCN root weight + relational
% attention); H^1 = F^1 and, for l >= 2, H^l = (1-eta) H^{l-1} + eta F^l
% with the fixed spec.residualMix eta (eta = 0: H^l = F^l, v2.0/v2.1); then
% g = tanh(mean_k (Wc H^L_k) .* Wn + bg) for node_shared_mean_v1;
% layerF holds F^l, layerH H^l.
% v2Operators 'semantic_fixed_v1' (relational-policy-v2.4): the propagate
% edges with self (spec.Tadd) and the modulate edges (spec.Tmod) are two
% attention graphs with the same W_r/a/E, A_l = tanh(Z_prop + Wroot h + b_l),
% M_l = tanh(Z_mod), F^l = (1 + M_l) .* A_l (gate 1 where no modulate edge).
B = size(policyInput,2); N = spec.nNodes; dh = spec.hiddenDim; L = spec.layers;
eta = 0; if isfield(spec,'residualMix'), eta = spec.residualMix; end
[keep,mix] = residualWeights(spec,eta);
previous = reshape(policyInput,spec.inDim,N,B);
layerCaches = cell(1,L); layerH = cell(1,L); layerF = cell(1,L);
typed = isfield(spec,'v2Operators') ...
    && ismember(spec.v2Operators,{'semantic_fixed_v1','semantic_bottleneck_v1', ...
    'semantic_reliability_bottleneck_v1'});
operators = 'none'; if typed, operators = spec.v2Operators; end
layerAdd = cell(1,L); layerMod = cell(1,L); layerA = cell(1,L); layerM = cell(1,L);
for l = 1:L
    V = params.(sprintf('V%d',l));
    fixedCodebook = isfield(spec,'relationParameterization') ...
        && ismember(spec.relationParameterization, ...
        {'fixed_cyclic_codebook_v1','fixed_semantic_codebook_v1'});
    if fixedCodebook
        C = spec.fixedRelationCodebook;
        aShared = params.(sprintf('a%d',l));
        a = repmat(aShared,1,1,spec.parameterRelationCount);
        E = spec.fixedRelationEmbedding;
    else
        C = params.(sprintf('C%d',l));
        a = params.(sprintf('a%d',l)); E = params.(sprintf('E%d',l));
    end
    W = landing2d.graphstate.basisWeights(V,C);
    root = reshape(params.(sprintf('Wroot%d',l))*reshape(previous,size(previous,1),N*B),dh,N,B);
    if typed
        [Za,layerAdd{l}] = landing2d.rgat.relationForward(previous,W,a,E,spec.Tadd,[],spec.attentionMode);
        [Zm,layerMod{l}] = landing2d.rgat.relationForward(previous,W,a,E,spec.Tmod,[],spec.attentionMode);
        layerA{l} = tanh(reshape(Za,dh,N,B)+root+params.(sprintf('b%d',l)));
        layerM{l} = tanh(reshape(Zm,dh,N,B));
        layerF{l} = (1+layerM{l}).*layerA{l};
        % Attention of every edge in spec.T order (diagnostics read .alpha).
        alpha = zeros(spec.T.nEdges,B);
        alpha(spec.addEdges,:) = layerAdd{l}.alpha; alpha(spec.modEdges,:) = layerMod{l}.alpha;
        layerCaches{l} = struct('alpha',alpha);
    else
        [Z,layerCaches{l}] = landing2d.rgat.relationForward(previous,W,a,E,spec.T,[],spec.attentionMode);
        layerF{l} = tanh(reshape(Z,dh,N,B)+root+params.(sprintf('b%d',l)));
    end
    if l >= 2 && eta > 0
        layerH{l} = keep*previous+mix*layerF{l};
    else
        layerH{l} = layerF{l};
    end
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
if strcmp(spec.readoutParameterization,'node_shared_mean_v1')
    readoutPreActivation = reshape(sum(channel.*params.Wn,2)/K,spec.graphDim,B)+params.bg;
else
    readoutPreActivation = reshape(sum(channel.*params.Wn,2),spec.graphDim,B)+params.bg;
end
g = tanh(readoutPreActivation);
% cache1 = first layer (the attention diagnostics read cache1.alpha).
cache = struct('mode',spec.mode,'encoderVersion','rgat_v2','B',B,'N',N,'dh',dh, ...
    'cache1',layerCaches{1},'layerCaches',{layerCaches},'layerH',{layerH}, ...
    'layerF',{layerF},'residualMix',eta,'residualKeep',keep,'residualWeight',mix, ...
    'v2Operators',operators,'layerAdd',{layerAdd},'layerMod',{layerMod}, ...
    'layerA',{layerA},'layerM',{layerM}, ...
    'Xf',reshape(policyInput,spec.inDim,N*B),'H',H,'grouped',grouped, ...
    'channel',channel,'g',g);
end

function [keep,mix] = residualWeights(spec,eta)
% Weights of H^l = keep H^(l-1) + mix F^l (l >= 2).
keep = 1-eta; mix = eta;
if isfield(spec,'residualRule') && strcmp(spec.residualRule,'variance_preserving_v1')
    keep = sqrt(1-eta); mix = sqrt(eta);
end
end
