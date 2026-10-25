function [params,spec] = encoderInit(gs,observationDim,rs)
% ENCODERINIT Shared projection -> relational aggregation -> RelativeState.
assert(observationDim==10,'landing2d:MinimalObservation','Expected 10 observations.');
[schema,T] = landing2d.minimal.schema();
[schema,T,graph] = landing2d.rgat.applyRelationPerturbation(schema,T,gs);
d = gs.hiddenDim; R = schema.nRelations;
spec = struct('mode','context_rgat','encoderVersion','rgat_minimal_v1', ...
    'readout','relative_state','attentionMode','input_dependent_v1', ...
    'inDim',10,'nNodes',4,'hiddenDim',d,'graphDim',d,'layers',1, ...
    'rawDim',40,'stateDim',40,'graphStateDim',40, ...
    'schema',schema,'T',T,'graph',graph,'fixedRelationEmbedding',eye(R));
params.P = randn(rs,d,10)/sqrt(10);
params.bp = zeros(d,1);
params.W = randn(rs,d,d,R)/sqrt(d);
params.a = randn(rs,1,2*d+R)/sqrt(2*d+R);
params.W0 = randn(rs,d,d)/sqrt(d);
params.b = zeros(d,1);
if strcmp(gs.encoderVersion,'rgat_minimal_v2')
    spec.encoderVersion = gs.encoderVersion;
    spec.attentionMode = 'dynamic_joint_v1';
    spec.layers = 2; spec.weightSharing = 'across_hops';
    % Same 19 numbers, now score vector + joint bias + relation bias.
    % Preserve RNG draw order; the two graph arms start identically.
    params.a(1:d) = params.a(1:d)*sqrt((2*d+R)/d);
    params.a(d+1:end) = 0;
end
end
