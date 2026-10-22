function F = actorForward(agent,policyInput)
% ACTORFORWARD  Numeric intermediates of one Actor (and Critic) forward pass, read-only.
%   F = landing2d.trace.actorForward(agent,policyInput)
% Calls the same pure functions the policy uses (encoderForward, mlpForward,
% valueForward) on the same frozen parameters and returns their caches; no
% parameter, random stream or environment is touched. landing2d.trace.
% recordEpisode asserts that F.mu equals the mean returned by
% landing2d.rl.policyAction bit for bit, so every number shown is the number
% of the actual decision.
% Per edge e = 1..20 in encoderSpec.T order:
%   attentionPreActivation  a'[W h_i || W h_j || E_r] before the leaky ReLU
%   attentionScore          e_ij = leaky ReLU (softmax input, 어텐션 점수)
%   alpha                   alpha_ij, softmax over the incoming edges of the
%                           destination inside the edge's operator pool
%                           (propagate incl. self / modulate) (어텐션 계수)
%   projectedMessageNorm    |W_r x_i|
%   weightedMessageNorm     |alpha_ij W_r x_i|
% typed_v1:  Zprop = sum of weighted propagate messages, Zmod = sum of
% weighted modulate messages, local = W0 X + b0, A = tanh(Zprop + local),
% gate = 1 + tanh(Zmod) (exactly 1 at nodes without modulating edges), H =
% gate .* A. The gate is not alpha. Readout g = tanh(sum_k (Wc H_k) .* Wn(:,k)
% + bg); readoutTermNorm(k) = |(Wc H_k) .* Wn(:,k)| is the size of node k's
% additive term in the readout pre-activation, not an action attribution.
% rgat_v2 shared readouts use the same Wn column. The displayed node terms
% include their registered pooling scale or fixed node-role code.
spec = agent.encoderSpec;
params = agent.policy.encoder;
[g,cache] = landing2d.graphstate.encoderForward(params,spec,policyInput,'policy');
[mu,mlpCache] = landing2d.rl.mlpForward(agent.policy.mean,g);
[value,valueCache] = landing2d.rl.valueForward(agent,policyInput);
N = spec.nNodes; dh = spec.hiddenDim; T = spec.T; nE = T.nEdges;
X = reshape(policyInput,spec.inDim,N);
if isfield(spec,'encoderVersion') && strcmp(spec.encoderVersion,'rgat_v2')
    if isfield(spec,'v2Operators') && ~strcmp(spec.v2Operators,'none')
        error('landing2d:TraceSchema', ['The decision trace does not yet expand the ' ...
            'v2Operators = %s layer (relational-policy-v2.4).'],spec.v2Operators);
    end
    F = forwardV2(params,spec,cache,X,g,mu,mlpCache,value,valueCache,agent);
    return;
end
local = params.W0*X+params.b0;
typed = isfield(spec,'relationOperators') && strcmp(spec.relationOperators,'typed_v1');
pre = zeros(nE,1); alpha = zeros(nE,1); projected = zeros(dh,nE);
if typed
    pools = {spec.addEdges(:),spec.modEdges(:)}; caches = {cache.cacheAdd,cache.cacheMod};
    topologies = {spec.Tadd,spec.Tmod};
else
    pools = {(1:nE)'}; caches = {cache.cache1}; topologies = {T};
end
Zpool = cell(1,numel(pools));
for p = 1:numel(pools)
    edges = pools{p}; pc = caches{p};
    pre(edges) = pc.attentionPreActivation(:,1);
    alpha(edges) = pc.alpha(:,1);
    projected(:,edges) = reshape(pc.edgeMessages,dh,[]);
    weighted = reshape(pc.edgeMessages,dh,[]).*reshape(pc.alpha(:,1),1,[]);
    Zpool{p} = weighted*topologies{p}.Msel';      % [dh x N] sum per destination
end
% Same leaky ReLU (slope 0.2) as landing2d.rgat.relationForward; the
% softmax of these scores reproduces alpha (checked in landing2d.trace.selfTest).
score = 0.6*pre+0.4*abs(pre);
if typed
    Zprop = Zpool{1}; Zmod = Zpool{2};
    A = cache.A; M = cache.M; gate = 1+M;
else
    Zprop = Zpool{1}; Zmod = zeros(dh,N);
    A = cache.H; M = zeros(dh,N); gate = ones(dh,N);
end
H = cache.H;
readoutTerm = params.Wc*H.*params.Wn;             % [graphDim x N]
F = struct('X',X,'local',local,'Zprop',Zprop,'Zmod',Zmod,'A',A,'gate',gate,'H',H);
F.attentionPreActivation = pre;
F.attentionScore = score;
F.alpha = alpha;
F.projectedMessageNorm = vecnorm(projected,2,1)';
F.weightedMessageNorm = vecnorm(projected.*alpha.',2,1)';
F.readoutTermNorm = vecnorm(readoutTerm,2,1);
F.g = g;
F.mlpHidden = mlpCache(2:end-1).';
F.mu = mu;
F.logStd = agent.policy.logStd;
F.criticG = valueCache.g;
F.value = value;
F.relationOperators = char(fieldOr(spec,'relationOperators','additive_v1'));
F.consistency = struct('propagateTanh',max(abs(tanh(Zprop+local)-A),[],'all'), ...
    'modulateTanh',max(abs(tanh(Zmod)-M),[],'all'), ...
    'embedding',max(abs(gate.*A-H),[],'all'));
% One layer: the per-layer views equal the fields above.
F.layers = 1; F.encoderVersion = 'rgat_v1';
F.alphaLayers = alpha; F.attentionScoreLayers = score;
F.projectedMessageNormLayers = F.projectedMessageNorm;
F.weightedMessageNormLayers = F.weightedMessageNorm;
F.layerH = {H}; F.layerZ = {Zprop};
end

function F = forwardV2(params,spec,cache,X,g,mu,mlpCache,value,valueCache,agent)
% rgat_v2: per layer l the attention pre-activation, score e_ij, coefficient
% alpha_ij (one softmax per destination over all incoming edges), message
% sizes |W_r h_j| and |alpha W_r h_j|, the aggregate Z_l, the root
% (self-connection) term Wroot_l h_i, F_l = tanh(Z_l + Wroot_l h + b_l) and
% H_l = F_l (l = 1 or no residual) or (1-eta) H_{l-1} + eta F_l (depth4_v1).
% There is no gate (gate = ones); local holds the last layer's root term.
L = spec.layers; dh = spec.hiddenDim; N = spec.nNodes; nE = spec.T.nEdges;
eta = 0; if isfield(cache,'residualMix'), eta = cache.residualMix; end
layerF = cache.layerH; if isfield(cache,'layerF'), layerF = cache.layerF; end
pre = zeros(nE,L); alpha = zeros(nE,L); projectedNorm = zeros(nE,L); weightedNorm = zeros(nE,L);
layerZ = cell(1,L); rootTerm = cell(1,L); consistency = 0; previous = X;
for l = 1:L
    c = cache.layerCaches{l};
    messages = reshape(c.edgeMessages,dh,[]);
    pre(:,l) = c.attentionPreActivation(:,1);
    alpha(:,l) = c.alpha(:,1);
    projectedNorm(:,l) = vecnorm(messages,2,1)';
    weighted = messages.*alpha(:,l)';
    weightedNorm(:,l) = vecnorm(weighted,2,1)';
    layerZ{l} = weighted*spec.T.Msel';
    rootTerm{l} = params.(sprintf('Wroot%d',l))*previous;
    consistency = max(consistency,max(abs(tanh(layerZ{l}+rootTerm{l}+params.(sprintf('b%d',l))) ...
        -layerF{l}),[],'all'));
    mixed = layerF{l};
    if l >= 2 && eta > 0, mixed = cache.residualKeep*previous+cache.residualWeight*layerF{l}; end
    consistency = max(consistency,max(abs(mixed-cache.layerH{l}),[],'all'));
    previous = cache.layerH{l};
end
score = 0.6*pre+0.4*abs(pre);       % leaky ReLU of landing2d.rgat.relationForward
H = cache.H;
if isfield(spec,'readoutParameterization') ...
        && strcmp(spec.readoutParameterization,'node_shared_mean_v1')
    readoutTerm = (params.Wc*H).*params.Wn/spec.groupCount;
elseif isfield(spec,'readoutParameterization') ...
        && strcmp(spec.readoutParameterization,'node_shared_variance_v1')
    readoutTerm = (params.Wc*H).*params.Wn/sqrt(spec.groupCount);
elseif isfield(spec,'readoutParameterization') ...
        && strcmp(spec.readoutParameterization,'fixed_node_codebook_v1')
    readoutTerm = (params.Wc*H).*spec.fixedNodeReadoutCodebook.*params.Wn;
elseif isfield(spec,'readoutParameterization') ...
        && strcmp(spec.readoutParameterization,'landing_sink_v1')
    readoutTerm = (params.Wc*H).*params.Wn.*spec.groupMatrix;   % zero except the sink
else
    readoutTerm = params.Wc*H.*params.Wn;
end
F = struct('X',X,'local',rootTerm{L},'Zprop',layerZ{L},'Zmod',zeros(dh,N),'A',H, ...
    'gate',ones(dh,N),'H',H);
F.attentionPreActivation = pre(:,1);
F.attentionScore = score(:,1);
F.alpha = alpha(:,1);
F.projectedMessageNorm = projectedNorm(:,1);
F.weightedMessageNorm = weightedNorm(:,1);
F.readoutTermNorm = vecnorm(readoutTerm,2,1);
F.g = g;
F.mlpHidden = mlpCache(2:end-1).';
F.mu = mu;
F.logStd = agent.policy.logStd;
F.criticG = valueCache.g;
F.value = value;
F.relationOperators = 'none';
F.consistency = struct('propagateTanh',consistency,'modulateTanh',0,'embedding',0);
F.layers = L; F.encoderVersion = 'rgat_v2';
F.alphaLayers = alpha; F.attentionScoreLayers = score;
F.projectedMessageNormLayers = projectedNorm;
F.weightedMessageNormLayers = weightedNorm;
F.layerH = cache.layerH; F.layerZ = layerZ; F.layerF = layerF; F.residualMix = eta;
end

function value = fieldOr(s,name,default)
value = default;
if isfield(s,name), value = s.(name); end
end
