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
spec.inDim = schema.inDim; spec.nNodes = schema.nNodes; spec.hiddenDim = dh;
spec.graphStateDim = schema.inDim*schema.nNodes;
spec.rawDim = spec.graphStateDim; spec.stateDim = spec.graphStateDim;
spec.groupMatrix = schema.groupMatrix;
spec.groupNames = schema.groupNames;
spec.groupCount = size(schema.groupMatrix,1);
spec.graphDim = gs.graphDim;
scale = gs.initScale;
R = schema.nRelations;
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
