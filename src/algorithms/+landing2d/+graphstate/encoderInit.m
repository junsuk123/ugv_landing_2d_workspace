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
% weights W_r = sum_b C(r,b) V_b, tanh node update with bias, then the
% grouped factorized readout. LeCun-normal initialization (variance 1/fan_in,
% the rule of landing2d.rl.mlpInit) for every weight; zero biases. No local
% bypass path, no gate and no hand-picked readout start.
N = schema.nNodes; R = schema.nRelations; Bb = gs.relationBases; dh = gs.hiddenDim;
attentionWidth = 2*dh+gs.relationDim;
spec.encoderVersion = 'rgat_v2';
spec.layers = gs.layers; spec.relationBases = Bb;
spec.inDim = schema.inDim; spec.nNodes = N; spec.hiddenDim = dh;
spec.graphStateDim = schema.inDim*N;
spec.rawDim = spec.graphStateDim; spec.stateDim = spec.graphStateDim;
spec.groupMatrix = schema.groupMatrix;
spec.groupNames = schema.groupNames;
spec.groupCount = size(schema.groupMatrix,1);
spec.graphDim = gs.graphDim;
spec.parameterRelationCount = R;
dims = [schema.inDim,repmat(dh,1,gs.layers)];
params = struct();
for l = 1:gs.layers
    name = layerNames(l);
    params.(name.V) = randn(rs,dh,dims(l),Bb)/sqrt(dims(l));
    params.(name.C) = randn(rs,R,Bb)/sqrt(Bb);
    params.(name.a) = randn(rs,1,attentionWidth,R)/sqrt(attentionWidth);
    params.(name.E) = randn(rs,gs.relationDim,R);
    params.(name.b) = zeros(dh,1);
end
params.Wc = randn(rs,gs.graphDim,dh)/sqrt(dh);
params.Wn = randn(rs,gs.graphDim,spec.groupCount)/sqrt(spec.groupCount);
params.bg = zeros(gs.graphDim,1);
end

function name = layerNames(l)
name = struct('V',sprintf('V%d',l),'C',sprintf('C%d',l),'a',sprintf('a%d',l), ...
    'E',sprintf('E%d',l),'b',sprintf('b%d',l));
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
