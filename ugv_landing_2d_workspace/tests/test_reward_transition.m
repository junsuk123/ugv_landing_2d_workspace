function test_reward_transition()
% TEST_REWARD_TRANSITION  Rate reward uses consecutive action distances.
c = landing2d.config.defaultConfig();
rl = c.rl;
rl.distanceMode = 'rate';
dtAction = 0.1;

[~,closer] = landing2d.rl.distanceSignal(5.9,6.0,dtAction,rl);
[~,steady] = landing2d.rl.distanceSignal(6.0,6.0,dtAction,rl);
[~,farther] = landing2d.rl.distanceSignal(6.1,6.0,dtAction,rl);
assert(abs(closer.rate-2/3) < 1e-12);
assert(steady.rate == 0);
assert(abs(farther.rate+2/3) < 1e-12);

% Integration guard: a stationary relative geometry must yield zero rate
% reward.  The former zero-initialized history produced -1 at every step.
c.tEnd = 0.3;
c.segmentTimes = [0.1,0.2];
c.scenarioSpeeds = [1,1,1];
c.animate = false;
c.figureVisible = false;
c.saveResults = false;
c.rl.actionInterval = 10;
c.rl.captureWeight = 0;
c.rl.distanceWeight = 1;
c.rl.distanceMode = 'rate';
rs = RandStream('threefry','Seed',1);
agent = landing2d.rl.agentInit(c.rl,rs,c.graphState);
for i = 1:numel(agent.policy.mean.W)
    agent.policy.mean.W{i}(:) = 0;
    agent.policy.mean.b{i}(:) = 0;
end
[r,s] = landing2d.simulation.initializeCase(c,1);
opts = struct('deterministic',true,'collect',true,'rs',[], ...
    'traceGraph',false);
[~,traj] = landing2d.rl.rolloutEpisode(agent,r,s,c,opts);
assert(all(abs(traj.reward) < 1e-12), ...
    'Constant distance must not receive a saturated negative rate reward.');

signature = landing2d.rl.trainingSignature(c);
assert(strcmp(signature.algorithmVersion,landing2d.rl.algorithmVersion()));
end
