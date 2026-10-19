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
spec = agent.encoderSpec;
params = agent.policy.encoder;
[g,cache] = landing2d.graphstate.encoderForward(params,spec,policyInput,'policy');
[mu,mlpCache] = landing2d.rl.mlpForward(agent.policy.mean,g);
[value,valueCache] = landing2d.rl.valueForward(agent,policyInput);
N = spec.nNodes; dh = spec.hiddenDim; T = spec.T; nE = T.nEdges;
X = reshape(policyInput,spec.inDim,N);
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
end

function value = fieldOr(s,name,default)
value = default;
if isfield(s,name), value = s.(name); end
end
