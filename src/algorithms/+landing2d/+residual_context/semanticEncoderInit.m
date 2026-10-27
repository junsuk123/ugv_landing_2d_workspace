function [p,spec] = semanticEncoderInit(gs,rs,baseRs)
% SEMANTICENCODERINIT V8 residual actor with relation-typed operators (C3, correctionOperators = semantic_v1).
% Actor mean = base(o) + sigmoid(beta)*tanh(R*h_goal+br) with
%   base             10 -> gs.basePolicyHiddenSizes (77) -> 2, tanh (as v5)
%   graph correction landing2d.residual_context.semanticGraphForward: node
%                    width gs.hiddenDim (8), qualifiesEstimate = modulation,
%                    informsMotion and self = additive attention messages,
%                    readout of the RelativeState goal node only
%   MLP correction   10 -> gs.correctionHiddenSize (32) -> 2, tanh
%   beta             gs.betaInit (0): the correction starts with the base's step size
% W(:,:,1) is the qualifiesEstimate gate weight, W(:,:,2) the informsMotion and
% W(:,:,3) the self message weight. TOSM and Shuffled draw identical parameters;
% the relation shuffle moves the operators between edges, so their initial
% functions differ by the placement alone. R is drawn and then set to 0.
if nargin<3, baseRs = rs; end
H = gs.basePolicyHiddenSizes; d = gs.hiddenDim; F = gs.correctionHiddenSize;
nodes = landing2d.residual_motion.schema();   % node observation indices of the v4/v5 draw
spec = struct('mode','residual_actor','encoderVersion','relational_residual_v5', ...
    'correctionType',gs.correctionType,'readout','goal_node','correctionOperators','semantic_v1', ...
    'attentionMode','dynamic_joint_v1','inDim',10,'nNodes',4,'goalNode',4, ...
    'hiddenDim',d,'graphDim',2,'layers',2,'rawDim',10,'stateDim',10, ...
    'graphStateDim',10,'schema',[],'T',[],'graph',[],'Tadd',[],'additiveEdges',[],'qualifies',[], ...
    'gateRelation',1,'additiveRelations',[2 3], ...
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
    p.a = [randn(rs,1,d)/sqrt(d),zeros(1,d+2)];
    p.bq = zeros(d,1);
    p.W0 = randn(rs,d,d)/sqrt(d); p.b = zeros(d,1);
    p.R = .1*randn(rs,2,d)/sqrt(d);
    [schema,T] = landing2d.residual_context.schema();
    schema.variant = 'tosm4_context_semantic_v1';
    schema.relationOperators = {'modulate','propagate','propagate'};
    [schema,T,graph] = landing2d.rgat.applyRelationPerturbation(schema,T,gs);
    additive = find(schema.rel~=spec.gateRelation);
    spec.Tadd = landing2d.rgat.topology(struct('src',schema.src(additive),'dst',schema.dst(additive), ...
        'rel',schema.rel(additive)-1,'nNodes',4,'nRelations',2,'goalNode',4));
    spec.additiveEdges = additive;
    gates = find(schema.rel==spec.gateRelation);
    spec.qualifies = struct('src',schema.src(gates),'dst',schema.dst(gates));
    spec.schema = schema; spec.T = T; spec.graph = graph;
else
    assert(strcmp(gs.correctionType,'mlp'));
    spec.readout = 'mlp';
    p.F = randn(rs,F,10)/sqrt(10); p.bf = zeros(F,1);
    p.R = .1*randn(rs,2,F)/sqrt(F);
end
p.R(:) = 0; % Zero correction: the initial residual policy is exactly its raw base.
p.br = zeros(2,1); p.beta = gs.betaInit;
end
