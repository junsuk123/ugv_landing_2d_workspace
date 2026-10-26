function [params,spec] = encoderInit(gs,observationDim,rs)
% ENCODERINIT Raw-observation base plus a bounded, learned correction.
% Stage 1: unchanged ten observations; no quality gate or auxiliary loss.
assert(observationDim==10 && ismember(gs.correctionType,{'graph','mlp'}), ...
    'landing2d:ResidualConfig','Expected ten observations and graph/mlp correction.');
[schema,T] = landing2d.minimal.schema();
[schema,T,graph] = landing2d.rgat.applyRelationPerturbation(schema,T,gs);
d = 8; k = 16;
spec = struct('mode','residual_actor','encoderVersion','relational_residual_v1', ...
    'correctionType',gs.correctionType,'readout','all_nodes', ...
    'attentionMode','dynamic_joint_v1','inDim',10,'nNodes',4, ...
    'hiddenDim',d,'graphDim',k,'layers',2,'rawDim',10,'stateDim',10, ...
    'graphStateDim',10,'schema',schema,'T',T,'graph',graph, ...
    'criticRepresentation','raw_observation','layerNormEpsilon',1e-5);
% Draw the common base first: the graph and MLP corrections share it exactly.
params.Pb = randn(rs,k,10)/sqrt(10);
params.bb = zeros(k,1);
if strcmp(gs.correctionType,'graph')
    % A separate projection/bias for each declared node type. Every stored
    % coefficient is used; no padded trainable columns or node-id feature.
    params.P = zeros(d,10);
    for i = 1:4
        index = schema.observationIndices{i};
        params.P(:,index) = randn(rs,d,numel(index))/sqrt(numel(index));
    end
    params.bp = zeros(d,4);
    params.W = randn(rs,d,d,3)/sqrt(d);
    common = (params.W(:,:,1)+params.W(:,:,2))/sqrt(2);
    params.W(:,:,1) = common; params.W(:,:,2) = common;
    params.a = [randn(rs,1,d)/sqrt(d),zeros(1,d+3)];
    params.W0 = randn(rs,d,d)/sqrt(d);
    params.b = zeros(d,1);
    params.R = randn(rs,k,4*d)/sqrt(4*d);
else
    spec.schema = []; spec.T = []; spec.graph = [];
    params.F = randn(rs,34,10)/sqrt(10);
    params.bf = zeros(34,1);
    params.R = randn(rs,k,34)/sqrt(34);
end
params.br = zeros(k,1);
params.beta = -2;
params.lnScale = ones(k,1);
params.lnBias = zeros(k,1);
end
