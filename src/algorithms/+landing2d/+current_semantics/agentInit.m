function agent = agentInit(rl,rs,gs)
% AGENTINIT Four actors with the unchanged raw 10->55->1 critic.
assert(rl.observationDim==10 && rl.actionDim==2,'landing2d:CurrentSemanticsDimensions', ...
    'The current-only experiment uses 10 observations and two actions.');
policyRs = RandStream('threefry','Seed',rl.seed+31001);
valueRs = RandStream('threefry','Seed',rl.seed+31002);
[p,spec] = landing2d.current_semantics.encoderInit(gs,rs,policyRs);
if strcmp(gs.encoderMode,'baseline')
    % The original v5 plain-PPO initialization and width are preserved.
    agent.policy.mean = landing2d.rl.mlpInit([10,110,2],.1,policyRs);
else
    % The new encoder returns the complete mean; this adapter is identity.
    agent.policy.mean = struct('W',{cell(0,1)},'b',{cell(0,1)});
end
agent.policy.logStd = rl.initialLogStd*ones(2,1);
agent.policy.encoder = p;
agent.value.net = landing2d.rl.mlpInit([10,55,1],.1,valueRs);
agent.value.encoder = struct();
agent.encoderSpec = spec; agent.rl = rl;
end
