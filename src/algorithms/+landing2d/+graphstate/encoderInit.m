function [params,spec] = encoderInit(gs,observationDim,rs)
% ENCODERINIT  Trainable parameters and fixed specification of the state encoder.
%   baseline      identity encoder: params is an empty struct and the MLP
%                 reads the 12-D o_t (Adam has nothing to update)
%   context_rgat  one relational graph-attention layer on the TOSM 7-node graph
%                 of the same o_t, a local node path W0 and the grouped
%                 factorized readout (node x channel) to a graphDim embedding
% params holds numeric arrays only (landing2d.util.adamInit/adamUpdate walk the
% struct); everything fixed (schema, typed topology, graph hash) is in spec.
mode = gs.stateRepresentation;
spec = struct('mode',mode,'readout',gs.readout,'attentionMode',gs.attentionMode);
if strcmp(mode,'baseline')
    params = struct();
    spec.inDim = 0; spec.nNodes = 0; spec.hiddenDim = 0;
    spec.rawDim = observationDim; spec.graphStateDim = 0;
    spec.stateDim = observationDim; spec.graphDim = observationDim;
    spec.schema = []; spec.T = []; spec.graph = [];
    return;
end
assert(strcmp(mode,'context_rgat') && strcmp(gs.readout,'grouped_factorized'), ...
    'landing2d:StateRepresentation', ...
    'Only baseline and context_rgat with the grouped_factorized readout are supported.');
[schema,T] = landing2d.graphstate.contextSchema(mode);
% v2.6 computational semantics: observation quality qualifies estimates;
% the other relations transport signed state/context evidence additively.
% Set this before relation perturbation so the shuffled-arm acceptance rule
% measures the computation that the encoder actually uses.
if isfield(gs,'v2Operators') ...
        && strcmp(gs.v2Operators,'semantic_reliability_bottleneck_v1')
    schema.relationOperators = {'modulate','propagate','propagate','propagate','propagate'};
end
% Relation shuffle (shuffled_rgat_ppo): one fixed edge-relation permutation
% per graph seed, applied once here, so PPO, evaluation and inference read the
% same typed topology from spec. graph.hash identifies the topology used.
[schema,T,graph] = landing2d.rgat.applyRelationPerturbation(schema,T,gs);
dh = gs.hiddenDim;
spec.schema = schema; spec.T = T; spec.graph = graph;
if isfield(gs,'encoderVersion') && strcmp(gs.encoderVersion,'rgat_v2')
    [params,spec] = initV2(gs,schema,spec,rs);
    return;
end
spec.encoderVersion = 'rgat_v1';
% Relation operators: additive_v1 = one attention layer over every edge;
% typed_v1 = the edges whose (possibly shuffled) relation type is a
% 'modulate' relation form a second attention graph whose message gates the
% destination state (landing2d.graphstate.encoderForward). The default
% operator_shared_v1 bank has one W1/a1/E1 set per operator class; the
% legacy relation_specific_v1 bank has one set per semantic relation.
spec.relationOperators = 'additive_v1';
if isfield(gs,'relationOperators'), spec.relationOperators = gs.relationOperators; end
spec.relationParameterSharing = 'relation_specific_v1';
if isfield(gs,'relationParameterSharing')
    spec.relationParameterSharing = gs.relationParameterSharing;
end
parameterRelations = schema.nRelations;
if strcmp(spec.relationOperators,'typed_v1')
    modulating = find(strcmp(schema.relationOperators,'modulate'));
    isMod = ismember(schema.rel,modulating);
    spec.modEdges = find(isMod); spec.addEdges = find(~isMod);
    if strcmp(spec.relationParameterSharing,'operator_shared_v1')
        % Parameter relation 1 = propagate, 2 = modulate. The ontology's
        % four semantic labels still determine which operator receives an
        % edge, but cannot become four independent capacity buckets that
        % relearn an arbitrary shuffled assignment.
        parameterRelations = 2;
        spec.Tadd = landing2d.rgat.topology(subgraph(schema,~isMod,1,2));
        spec.Tmod = landing2d.rgat.topology(subgraph(schema,isMod,2,2));
    else
        spec.Tadd = landing2d.rgat.topology(subgraph(schema,~isMod));
        spec.Tmod = landing2d.rgat.topology(subgraph(schema,isMod));
    end
end
spec.inDim = schema.inDim; spec.nNodes = schema.nNodes; spec.hiddenDim = dh;
spec.graphStateDim = schema.inDim*schema.nNodes;
spec.rawDim = spec.graphStateDim; spec.stateDim = spec.graphStateDim;
spec.groupMatrix = schema.groupMatrix;
spec.groupNames = schema.groupNames;
spec.groupCount = size(schema.groupMatrix,1);
spec.graphDim = gs.graphDim;
scale = gs.initScale;
R = parameterRelations;
spec.parameterRelationCount = R;
params.W1 = scale*randn(rs,dh,schema.inDim,R);       % relation messages
params.a1 = scale*randn(rs,1,2*dh+gs.relationDim,R); % attention vectors
params.E1 = scale*randn(rs,gs.relationDim,R);        % relation embeddings
params.W0 = scale*randn(rs,dh,schema.inDim);         % local node path
params.b0 = zeros(dh,1);
% The local path starts information preserving (identity on the first
% channels); relation messages and the readout remain fully trainable. The
% MLP still receives only the graph embedding (no raw-observation bypass).
params.W0(:) = 0;
d = min(dh,schema.inDim);
params.W0(1:d,1:d) = eye(d);
params.Wc = scale*randn(rs,gs.graphDim,dh);
params.Wn = scale*randn(rs,gs.graphDim,spec.groupCount);
params.bg = zeros(gs.graphDim,1);
% Deterministic readout start: row k of schema.readoutInit = [node,channel]
% begins as one explicit ontology coordinate.
if dh >= schema.inDim-1 && gs.graphDim >= size(schema.readoutInit,1)
    rows = size(schema.readoutInit,1);
    params.Wc(1:rows,:) = 0; params.Wn(1:rows,:) = 0;
    for row = 1:rows
        params.Wc(row,schema.readoutInit(row,2)) = 1;
        params.Wn(row,schema.readoutInit(row,1)) = 0.25;
    end
end
end

function [params,spec] = initV2(gs,schema,spec,rs)
% rgat_v2: L relational graph-attention layers over all 20 typed edges, one
% attention softmax per destination across relation types, relation-specific
% weights W_r = sum_b C(r,b) V_b, the R-GCN root (self-connection) weight
% Wroot_l of the canonical layer h_i' = tanh(Wroot h_i + sum alpha W_r h_j + b),
% then the grouped factorized readout. LeCun-normal initialization (variance
% 1/fan_in, the rule of landing2d.rl.mlpInit) for every weight; zero biases.
% No hand-picked (identity) start. v2Operators 'none' (v2.0-v2.3): one
% attention graph over all edges, no gate. 'semantic_fixed_v1' (v2.4): the
% edges of the 'modulate' relations form a second attention graph (spec.Tmod)
% whose aggregate gates the destination state; the rest and the self edges
% form the additive graph (spec.Tadd). Operator classes follow the possibly
% shuffled relation types. No extra parameters and no extra random draws.
% Node width v2HiddenDim (depth4_v1: 12) when set, otherwise hiddenDim (v2.0/v2.1:
% 16); residualMix (depth4_v1: 0.5) mixes layers 2..L, 0 = plain stacking.
N = schema.nNodes; R = schema.nRelations; Bb = gs.relationBases; dh = gs.hiddenDim;
if isfield(gs,'v2HiddenDim'), dh = gs.v2HiddenDim; end
attentionWidth = 2*dh+gs.relationDim;
spec.encoderVersion = 'rgat_v2';
spec.layers = gs.layers; spec.relationBases = Bb;
spec.residualMix = 0;
if isfield(gs,'residualMix'), spec.residualMix = gs.residualMix; end
% residualRule: 'convex_v1' H = (1-eta) H_prev + eta F; 'variance_preserving_v1'
% H = sqrt(1-eta) H_prev + sqrt(eta) F. initGain scales the LeCun weights that
% enter a tanh (V, Wroot): 1 = LeCun, 5/3 = the tanh gain.
spec.residualRule = 'convex_v1';
if isfield(gs,'residualRule'), spec.residualRule = gs.residualRule; end
gain = 1; if isfield(gs,'v2InitGain'), gain = gs.v2InitGain; end
spec.inDim = schema.inDim; spec.nNodes = N; spec.hiddenDim = dh;
spec.graphStateDim = schema.inDim*N;
spec.rawDim = spec.graphStateDim; spec.stateDim = spec.graphStateDim;
spec.groupMatrix = schema.groupMatrix;
spec.groupNames = schema.groupNames;
spec.groupCount = size(schema.groupMatrix,1);
spec.readoutParameterization = 'node_specific_v1';
if isfield(gs,'v2ReadoutParameterization')
    spec.readoutParameterization = gs.v2ReadoutParameterization;
end
spec.graphDim = gs.graphDim;
spec.parameterRelationCount = R;
spec.v2Operators = 'none';
if isfield(gs,'v2Operators'), spec.v2Operators = gs.v2Operators; end
spec.relationParameterization = 'trainable_basis_v1';
if isfield(gs,'v2RelationParameterization')
    spec.relationParameterization = gs.v2RelationParameterization;
end
typed = ismember(spec.v2Operators,{'semantic_fixed_v1','semantic_bottleneck_v1', ...
    'semantic_reliability_bottleneck_v1'});
if typed
    modulating = find(strcmp(schema.relationOperators,'modulate'));
    isMod = ismember(schema.rel,modulating);
    spec.modEdges = find(isMod); spec.addEdges = find(~isMod);
    if ismember(spec.v2Operators,{'semantic_bottleneck_v1', ...
            'semantic_reliability_bottleneck_v1'})
        % Parameter relation 1 = propagate, 2 = modulate. Semantic labels
        % select the fixed operation, but cannot own independent parameters
        % that relearn a shuffled label assignment.
        R = 2; spec.parameterRelationCount = R;
        spec.Tadd = landing2d.rgat.topology(subgraph(schema,~isMod,1,R));
        spec.Tmod = landing2d.rgat.topology(subgraph(schema,isMod,2,R));
        sink = schema.landingConditionNodes;
        assert(isscalar(sink),'landing2d:OntologySink', ...
            'semantic_bottleneck_v1 requires one LandingCondition sink.');
        spec.groupMatrix = zeros(1,N); spec.groupMatrix(sink) = 1;
        spec.groupNames = schema.nodeNames(sink); spec.groupCount = 1;
        spec.readoutTargetNodes = sink;
    else
        spec.Tadd = landing2d.rgat.topology(subgraph(schema,~isMod));
        spec.Tmod = landing2d.rgat.topology(subgraph(schema,isMod));
    end
end
dFixed = ismember(spec.relationParameterization, ...
    {'fixed_cyclic_codebook_v1','fixed_semantic_codebook_v1'});
if dFixed
    assert(~typed,'landing2d:RelationParameterization', ...
        'A fixed relation codebook uses the standard single attention graph.');
    assert(Bb==3 && R==5 && gs.relationDim==4,'landing2d:RelationParameterization', ...
        'A fixed relation codebook requires 5 relations, 3 bases and relationDim 4.');
    if strcmp(spec.relationParameterization,'fixed_cyclic_codebook_v1')
        theta = 2*pi*(0:R-1)'/R;
        spec.fixedRelationCodebook = ...
            [ones(R,1),sqrt(2)*cos(theta),sqrt(2)*sin(theta)]/sqrt(3);
        spec.fixedRelationEmbedding = regularSimplex(R);
    else
        [spec.fixedRelationCodebook,spec.fixedRelationEmbedding, ...
            spec.relationDescriptorNames] = semanticCodebook(schema.relationNames);
    end
end
dims = [schema.inDim,repmat(dh,1,gs.layers)];
params = struct();
for l = 1:gs.layers
    name = layerNames(l);
    params.(name.V) = gain*randn(rs,dh,dims(l),Bb)/sqrt(dims(l));
    if dFixed
        params.(name.a) = randn(rs,1,attentionWidth)/sqrt(attentionWidth);
    else
        params.(name.C) = randn(rs,R,Bb)/sqrt(Bb);
        params.(name.a) = randn(rs,1,attentionWidth,R)/sqrt(attentionWidth);
        params.(name.E) = randn(rs,gs.relationDim,R);
    end
    params.(name.root) = gain*randn(rs,dh,dims(l))/sqrt(dims(l));
    params.(name.b) = zeros(dh,1);
end
params.Wc = randn(rs,gs.graphDim,dh)/sqrt(dh);
if strcmp(spec.readoutParameterization,'node_shared_mean_v1')
    params.Wn = randn(rs,gs.graphDim,1);
else
    params.Wn = randn(rs,gs.graphDim,spec.groupCount)/sqrt(spec.groupCount);
end
params.bg = zeros(gs.graphDim,1);
end

function E = regularSimplex(R)
% Columns are the R equal-norm, equal-angle vertices of an (R-1)-simplex.
E = zeros(R-1,R);
for k = 1:R-1
    E(k,1:k) = 1/sqrt(k*(k+1));
    E(k,k+1) = -k/sqrt(k*(k+1));
end
E = sqrt(R/(R-1))*E;
end

function [C,E,names] = semanticCodebook(relationNames)
% Fixed descriptors from the declared ontology roles, not learned labels.
% Message coefficients: [shared, target abstraction depth, evidence role].
% Estimate-producing relations are depth -1, visibility context is 0 and
% the landing-condition relation is +1. Observation quality is evidence
% role +1, ordinary propagation is 0 and self-retention is -1. Every row is
% normalized so no relation receives a larger message solely from its code.
expected = {'qualifiesEstimate','informsMotion','affectsVisibility', ...
    'conditionsLanding','self'};
assert(numel(relationNames)==numel(expected) ...
    && all(ismember(expected,relationNames)),'landing2d:RelationParameterization', ...
    'fixed_semantic_codebook_v1 requires the five tosm7 relation names.');
rawByMeaning = [1,-1, 1; ... % observation quality -> estimated state
                1,-1, 0; ... % motion evidence -> estimated state
                1, 0, 0; ... % state/motion -> visibility context
                1, 1, 0; ... % state/context -> landing condition
                1, 0,-1];    % retain local node evidence
C = zeros(numel(relationNames),3);
selfIndicator = zeros(1,numel(relationNames));
for k = 1:numel(expected)
    r = find(strcmp(relationNames,expected{k}));
    C(r,:) = rawByMeaning(k,:)/sqrt(sum(rawByMeaning(k,:).^2));
    selfIndicator(r) = strcmp(expected{k},'self');
end
% Attention uses the same three descriptors plus an explicit self flag.
% Columns are normalized because relationForward consumes E(:,r).
E = [C';selfIndicator];
E = E./sqrt(sum(E.^2,1));
names = {'sharedEvidence','targetAbstractionDepth','evidenceRole','selfRetention'};
end

function name = layerNames(l)
name = struct('V',sprintf('V%d',l),'C',sprintf('C%d',l),'a',sprintf('a%d',l), ...
    'E',sprintf('E%d',l),'root',sprintf('Wroot%d',l),'b',sprintf('b%d',l));
end

function s = subgraph(schema,keep,relationId,nRelations)
% The same nodes and relation ids with only the KEEP edges.
s = schema;
s.src = schema.src(keep); s.dst = schema.dst(keep); s.rel = schema.rel(keep);
if nargin >= 3
    s.rel = relationId*ones(size(s.rel));
    s.nRelations = nRelations;
end
end
