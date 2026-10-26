function agent = agentInit(rl,rs,gs)
% AGENTINIT All four methods have the same raw-observation value network.
if strcmp(gs.stateRepresentation,'baseline')
    [policyEncoder,spec] = landing2d.graphstate.encoderInit(gs,rl.observationDim,rs);
    hidden = rl.baselinePolicyHiddenSizes;
else
    [policyEncoder,spec] = landing2d.residual.encoderInit(gs,rl.observationDim,rs);
    hidden = gs.policyHiddenSizes;
end
policyRs = RandStream('threefry','Seed',rl.seed+31001);
valueRs = RandStream('threefry','Seed',rl.seed+31002);
agent.policy.mean = landing2d.rl.mlpInit([spec.graphDim,hidden,rl.actionDim],.1,policyRs);
agent.policy.logStd = rl.initialLogStd*ones(rl.actionDim,1);
agent.policy.encoder = policyEncoder;
agent.value.net = landing2d.rl.mlpInit([rl.observationDim,rl.baselineValueHiddenSizes,1],.1,valueRs);
agent.value.encoder = struct();
agent.encoderSpec = spec; agent.rl = rl;
end
