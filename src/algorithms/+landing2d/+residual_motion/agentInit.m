function agent = agentInit(rl,rs,gs)
% AGENTINIT Complete mean in the actor encoder; common raw-vector critic.
policyRs = RandStream('threefry','Seed',rl.seed+31001);
valueRs = RandStream('threefry','Seed',rl.seed+31002);
if strcmp(gs.stateRepresentation,'baseline')
    [policyEncoder,spec] = landing2d.graphstate.encoderInit(gs,rl.observationDim,rs);
    agent.policy.mean = landing2d.rl.mlpInit([10,rl.baselinePolicyHiddenSizes,2],.1,policyRs);
    agent.policy.mean.W{end}(:) = 0;
else
    [policyEncoder,spec] = landing2d.residual_motion.encoderInit(gs,rs,policyRs);
    agent.policy.mean = struct('W',{cell(0,1)},'b',{cell(0,1)});
end
agent.policy.logStd = rl.initialLogStd*ones(rl.actionDim,1);
agent.policy.encoder = policyEncoder;
agent.value.net = landing2d.rl.mlpInit([10,rl.baselineValueHiddenSizes,1],.1,valueRs);
agent.value.encoder = struct();
agent.encoderSpec = spec; agent.rl = rl;
end
