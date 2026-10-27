function [p,spec] = encoderInit(gs,rs,policyRs)
% ENCODERINIT Current-only actor encoder. Numeric learnables stay in P.
% Fixed schema, graph, constants and dimensions stay in SPEC.
% Graph actor: [raw observation; final LandingContext] -> tanh MLP -> mean.
% No action-residual gate, memory, previous action or auxiliary target exists.
if nargin < 3, policyRs = rs; end
landing2d.current_semantics.validateGraphConfig(gs);
spec = struct('mode','current_semantics_actor','encoderVersion','current_semantics_v1', ...
    'encoderMode',gs.encoderMode,'readout','raw_goal_concat','attentionMode','dynamic_joint_v1', ...
    'inDim',10,'rawDim',10,'stateDim',10,'graphStateDim',10,'graphDim',2, ...
    'nNodes',7,'inputFeatureDim',6,'featureDim',19,'hiddenDim',8,'layers',2,'goalNode',7, ...
    'schema',[],'T',[],'graph',[],'featureConstants',gs.featureConstants, ...
    'policyHiddenSize',gs.policyHiddenSizes,'criticRepresentation','raw_observation');
p = struct();
if strcmp(gs.encoderMode,'baseline')
    spec.mode = 'baseline'; spec.readout = 'raw_observation';
    spec.graphDim = 10; spec.graphStateDim = 0;
    spec.nNodes = 0; spec.hiddenDim = 0; spec.layers = 0;
    return;
end
if strcmp(gs.encoderMode,'semantic_mlp')
    inputWidth = spec.featureDim; spec.readout = 'flat_variable_features';
    spec.schema = landing2d.current_semantics.schema();
else
    [spec.schema,spec.T,spec.graph] = landing2d.current_semantics.schema(gs.encoderMode);
    d = spec.hiddenDim; R = spec.T.nRelations;
    p.P = randn(rs,d,spec.inputFeatureDim)/sqrt(spec.inputFeatureDim);
    p.bp = zeros(d,1);
    p.W = randn(rs,d,d,R)/sqrt(d);
    p.a = [randn(rs,1,d)/sqrt(d),zeros(1,d+R)];
    p.W0 = randn(rs,d,d)/sqrt(d); p.b = zeros(d,1);
    inputWidth = spec.rawDim+d;
end
head = landing2d.rl.mlpInit([inputWidth,gs.policyHiddenSizes,2],.1,policyRs);
p.A1 = head.W{1}; p.c1 = head.b{1}; p.A2 = head.W{2}; p.c2 = head.b{2};
end
