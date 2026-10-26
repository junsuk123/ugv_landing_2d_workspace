function [p,spec] = accelerationEncoderInit(gs,rs,baseRs)
% ACCELERATIONENCODERINIT V5 residual actor on the 11-D H3 observation (tosm4_context_accel_v1).
% The v5 construction (landing2d.residual_base_init.encoderInit) with inDim 11:
% base 11 -> 74 -> 2, node projection P (8 x 11) with TargetMotion = [o4, o11],
% MLP correction 36 x 11; same draw order, gains, widths, zero correction and
% beta. Nodes, edges, relations and the relation shuffle are the v5 ones.
if nargin<3, baseRs = rs; end
n = 11;
[schema,T] = landing2d.residual_context.schema('tosm4_context_accel_v1');
spec = struct('mode','residual_actor','encoderVersion','relational_residual_v5', ...
    'correctionType',gs.correctionType,'readout','all_nodes', ...
    'attentionMode','dynamic_joint_v1','inDim',n,'nNodes',4, ...
    'hiddenDim',8,'graphDim',2,'layers',2,'rawDim',n,'stateDim',n, ...
    'graphStateDim',n,'schema',schema,'T',T,'graph',[], ...
    'criticRepresentation','raw_observation','correctionCoordinates','masked_own_vx_v1');
base =landing2d.rl.mlpInit([n 74 2],.1,baseRs);
p.B1 = base.W{1}; p.b1 = base.b{1}; p.B2 = base.W{2}; p.b2 = base.b{2};
if strcmp(gs.correctionType,'graph')
    p.P = zeros(8,n);
    for i = 1:4
        index = schema.observationIndices{i};
        p.P(:,index) = randn(rs,8,numel(index))/sqrt(numel(index));
    end
    p.bp = zeros(8,4);
    p.W = randn(rs,8,8,3)/sqrt(8);
    common = (p.W(:,:,1)+p.W(:,:,2))/sqrt(2);
    p.W(:,:,1) = common; p.W(:,:,2) = common;
    p.a = [randn(rs,1,8)/sqrt(8),zeros(1,11)];
    p.W0 = randn(rs,8,8)/sqrt(8); p.b = zeros(8,1);
    p.R = .1*randn(rs,2,32)/sqrt(32);
    [schema,T,graph] = landing2d.rgat.applyRelationPerturbation(schema,T,gs);
    spec.schema = schema; spec.T = T; spec.graph = graph;
else
    assert(strcmp(gs.correctionType,'mlp'));
    spec.schema = []; spec.T = []; spec.graph = [];
    p.F = randn(rs,36,n)/sqrt(n); p.bf = zeros(36,1);
    p.R = .1*randn(rs,2,36)/sqrt(36);
end
p.R(:) = 0; % Zero correction: the initial residual policy is exactly its raw base.
p.br = zeros(2,1); p.beta = -2;
end
