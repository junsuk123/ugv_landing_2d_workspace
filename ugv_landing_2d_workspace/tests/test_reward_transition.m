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

% The capture term must preserve ordering outside FOV instead of clipping
% every out-of-view state to -1.
sCapture = struct('mode',1,'x',0);
obsCapture = struct('visible',true,'halfWidth',1);
q = [0,1,2,4];
capture = zeros(size(q));
for k = 1:numel(q)
    capture(k) = landing2d.rl.captureSignal(sCapture,obsCapture,q(k),rl);
end
assert(abs(capture(1)-1) < 1e-12);
assert(abs(capture(2)-rl.captureBoundaryValue) < 1e-12);
assert(all(diff(capture) < 0) && capture(end) > -1, ...
    'Capture reward must retain a bounded gradient outside FOV.');

% Terminal outcome must be distinguished inside the same two reward terms.
failed = sCapture; failed.mode = 4;
landed = sCapture; landed.mode = 3;
assert(landing2d.rl.captureSignal(failed,obsCapture,0,rl) == -1);
assert(landing2d.rl.captureSignal(landed,obsCapture,0,rl) == 1);
assert(landing2d.rl.distanceSignal(0,0.1,dtAction,rl,4) == -1);
assert(landing2d.rl.distanceSignal(0,0.1,dtAction,rl,3) == 1);

% A terminal state must not create transitions for the remainder of tEnd.
[rTerminal,sTerminal] = landing2d.simulation.initializeCase(c,1);
sTerminal.h = 0;
sTerminal.vz = 0;
sTerminal.x = rTerminal.xUgv(1);
[~,terminalTrajectory] = landing2d.rl.rolloutEpisode(agent,rTerminal, ...
    sTerminal,c,opts);
assert(terminalTrajectory.count == 0 && terminalTrajectory.bootstrap == 0, ...
    'Terminal rollout must stop reward collection and value bootstrapping.');

% A policy that dives into the ground must receive the discounted absorbing
% failure outcome on its final valid transition. This prevents early failure
% from avoiding the remaining finite-horizon cost.
cFail = landing2d.config.defaultConfig();
cFail.tEnd = 10;
cFail.segmentTimes = [3,7];
cFail.scenarioSpeeds = [1,4,1.5];
cFail.animate = false;
cFail.figureVisible = false;
cFail.saveResults = false;
cFail.rl.parallelEpisodes = false;
rs = RandStream('threefry','Seed',2);
diver = landing2d.rl.agentInit(cFail.rl,rs,cFail.graphState);
for i = 1:numel(diver.policy.mean.W)
    diver.policy.mean.W{i}(:) = 0;
    diver.policy.mean.b{i}(:) = 0;
end
diver.policy.mean.b{end}(2) = -5;
[rFail,sFail] = landing2d.simulation.initializeCase(cFail,1);
[rFail,failTrajectory] = landing2d.rl.rolloutEpisode(diver,rFail,sFail, ...
    cFail,opts);
assert(isfinite(rFail.failureTime) && failTrajectory.bootstrap == 0);
assert(failTrajectory.reward(end) < -(cFail.rl.captureWeight ...
    +cFail.rl.distanceWeight), ...
    'Unsafe contact must include the remaining absorbing failure return.');

assert(c.rl.scratch.initialHeightRange(1) >= 0.8, ...
    'Scratch episodes must predominantly reach the t=3 s acceleration event.');

signature = landing2d.rl.trainingSignature(c);
assert(strcmp(signature.algorithmVersion,landing2d.rl.algorithmVersion()));
end
