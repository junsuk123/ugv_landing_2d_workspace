function [p,spec] = capacityEncoderInit(gs,rs,baseRs)
% CAPACITYENCODERINIT V5 residual actor with registered widths (C2, relational_residual_v7).
% The v5 construction (landing2d.residual_base_init.encoderInit, then the v5
% topology of landing2d.residual_context.encoderInit) with base width
% gs.basePolicyHiddenSizes (H), node width gs.hiddenDim (d) and MLP correction
% width gs.correctionHiddenSize (F): same draw order, fan-in gains, shared
% semantic initial W, zero correction (R drawn, then set to 0) and beta = -2.
% Widths 74/8/36 reproduce the v5 encoder exactly (landing2d.residual_capacity.selfTest).
if nargin<3, baseRs = rs; end
H = gs.basePolicyHiddenSizes; d = gs.hiddenDim; F = gs.correctionHiddenSize;
nodes = landing2d.residual_motion.schema();   % node observation indices of the v4/v5 draw
spec = struct('mode','residual_actor','encoderVersion','relational_residual_v5', ...
    'correctionType',gs.correctionType,'readout','all_nodes', ...
    'attentionMode','dynamic_joint_v1','inDim',10,'nNodes',4, ...
    'hiddenDim',d,'graphDim',2,'layers',2,'rawDim',10,'stateDim',10, ...
    'graphStateDim',10,'schema',[],'T',[],'graph',[], ...
    'criticRepresentation','raw_observation','correctionCoordinates','masked_own_vx_v1');
base = landing2d.rl.mlpInit([10 H 2],.1,baseRs);
p.B1 = base.W{1}; p.b1 = base.b{1}; p.B2 = base.W{2}; p.b2 = base.b{2};
if strcmp(gs.correctionType,'graph')
    p.P = zeros(d,10);
    for i = 1:4
        index = nodes.observationIndices{i};
        p.P(:,index) = randn(rs,d,numel(index))/sqrt(numel(index));
    end
    p.bp = zeros(d,4);
    p.W = randn(rs,d,d,3)/sqrt(d);
    common = (p.W(:,:,1)+p.W(:,:,2))/sqrt(2);
    p.W(:,:,1) = common; p.W(:,:,2) = common;
    p.a = [randn(rs,1,d)/sqrt(d),zeros(1,d+3)];
    p.W0 = randn(rs,d,d)/sqrt(d); p.b = zeros(d,1);
    p.R = .1*randn(rs,2,4*d)/sqrt(4*d);
    [schema,T] = landing2d.residual_context.schema();
    [schema,T,graph] = landing2d.rgat.applyRelationPerturbation(schema,T,gs);
    spec.schema = schema; spec.T = T; spec.graph = graph;
else
    assert(strcmp(gs.correctionType,'mlp'));
    p.F = randn(rs,F,10)/sqrt(10); p.bf = zeros(F,1);
    p.R = .1*randn(rs,2,F)/sqrt(F);
end
p.R(:) = 0; % Zero correction: the initial residual policy is exactly its raw base.
p.br = zeros(2,1); p.beta = -2;
end
