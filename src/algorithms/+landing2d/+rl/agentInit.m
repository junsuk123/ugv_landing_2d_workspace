function agent = agentInit(rl,rs,gs)
% AGENTINIT  Gaussian policy (mean MLP + log standard deviation) and value MLP.
%   agent = landing2d.rl.agentInit(rl,rs,gs)
% The policy outputs the pre-tanh command; the environment scales tanh(u) to
% the acceleration limits. Actor and Critic have separate encoders (identity
% for plain PPO, an R-GAT encoder each for the graph arms) of the same
% structure. The MLP initialization uses streams derived from rl.seed only, so
% the encoder size never changes the random policy initialization.
if nargin < 3 || isempty(gs), gs = landing2d.graphstate.defaultGraphStateConfig(); end
[policyEncoder,spec] = landing2d.graphstate.encoderInit(gs,rl.observationDim,rs);
valueEncoder = landing2d.graphstate.encoderInit(gs,rl.observationDim,rs);
policyHiddenSizes = [rl.hiddenSize,rl.hiddenSize];
valueHiddenSizes = [rl.hiddenSize,rl.hiddenSize];
if ~strcmp(spec.mode,'baseline')
    policyHiddenSizes = gs.policyHiddenSizes;
    valueHiddenSizes = gs.valueHiddenSizes;
    if isfield(spec,'encoderVersion') && strcmp(spec.encoderVersion,'rgat_v2')
        policyHiddenSizes = gs.v2PolicyHiddenSizes;
        valueHiddenSizes = gs.v2ValueHiddenSizes;
    elseif isfield(spec,'relationParameterSharing') ...
            && strcmp(spec.relationParameterSharing,'operator_shared_v1')
        policyHiddenSizes = gs.operatorSharedPolicyHiddenSizes;
        valueHiddenSizes = gs.operatorSharedValueHiddenSizes;
    end
end
policyRs = RandStream('threefry','Seed',rl.seed+31001);
valueRs = RandStream('threefry','Seed',rl.seed+31002);
agent.policy.mean = landing2d.rl.mlpInit([spec.graphDim,policyHiddenSizes,rl.actionDim], ...
    0.1,policyRs);
agent.policy.logStd = rl.initialLogStd*ones(rl.actionDim,1);
agent.policy.encoder = policyEncoder;
agent.value.net = landing2d.rl.mlpInit([spec.graphDim,valueHiddenSizes,1],0.1,valueRs);
agent.value.encoder = valueEncoder;
agent.encoderSpec = spec;
agent.rl = rl;
end
