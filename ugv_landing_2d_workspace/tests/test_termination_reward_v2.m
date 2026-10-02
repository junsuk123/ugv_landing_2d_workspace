function test_termination_reward_v2()
c = landing2d.config.primaryConfig(fileparts(fileparts(mfilename('fullpath'))));
p = landing2d.scenario.sampleParameters(c.experiment.scenario,4);
c.experiment.currentScenario = p;
pad0 = struct('x',0,'z',p.padHeight,'vx',0);
pad1 = pad0;
d = c.experiment.dynamics;
prev = struct('x',0,'z',p.padHeight+0.01,'vx',0,'vz',-0.1, ...
    'theta',0,'pitchRate',0,'collectiveThrust',d.mass*d.gravity);
next = prev; next.z=p.padHeight-0.01;
di = struct('hardEnvelopeViolation',false);
authorized = landing2d.environment.initialStatus();
authorized.landingInhibited=false;
ev1 = landing2d.environment.evaluateTermination(prev,next,pad0,pad1, ...
    authorized,1,0.1,c,di);
blocked = authorized; blocked.landingInhibited=true;
ev2 = landing2d.environment.evaluateTermination(prev,next,pad0,pad1, ...
    blocked,1,0.1,c,di);
assert(ev1.physicalContact && ev2.physicalContact);
assert(ev1.mechanicallySafe==ev2.mechanicallySafe);
assert(strcmp(ev1.reason,'SUCCESS') && strcmp(ev2.reason,'UNAUTHORIZED_CONTACT'));
assert(abs(ev1.preImpact.relativeVz-0.1)<1e-12);

truth = struct('ex',0,'h',0);
m = struct('detected',true,'bearingValid',true,'bearing',0);
[safe,comp] = landing2d.rl.computeReward(truth,truth,m,[0;0],0.1,ev1,c);
assert(abs(safe-c.experiment.reward.SUCCESS)<1e-12 && comp.goalCost==0 ...
    && comp.landingReadiness==1 && comp.readinessReward==0);
unsafeEvent=ev1; unsafeEvent.reason='UNSAFE_CONTACT';
unsafe=landing2d.rl.computeReward(truth,truth,m,[0;0],0.1,unsafeEvent,c);
assert(safe>unsafe);
far=struct('ex',3,'h',4); near=struct('ex',1,'h',1);
noEvent=ev1; noEvent.occurred=false; noEvent.reason='';
[progress,progressComp]=landing2d.rl.computeReward(far,near,m,[0;0],0.1,noEvent,c);
assert(progressComp.potentialShaping>0 && progress>0);
ready=struct('ex',0,'h',0.2,'relativeVx',0.05,'vz',-0.1, ...
    'theta',0,'pitchRate',0);
notReady=ready; notReady.relativeVx=2; notReady.vz=-1;
[~,readyComp]=landing2d.rl.computeReward(ready,ready,m,[0;0],0.1,noEvent,c);
[~,notReadyComp]=landing2d.rl.computeReward(notReady,notReady,m,[0;0],0.1,noEvent,c);
assert(readyComp.landingReadiness>notReadyComp.landingReadiness);
% Holding the same near-pad state must not farm readiness reward. Moving
% toward readiness is positive and moving back returns the same gain.
[~,towardComp]=landing2d.rl.computeReward(notReady,ready,m,[0;0],0.1,noEvent,c);
[~,awayComp]=landing2d.rl.computeReward(ready,notReady,m,[0;0],0.1,noEvent,c);
assert(towardComp.readinessReward>0 && awayComp.readinessReward<0);
assert(abs(towardComp.readinessReward+awayComp.readinessReward)<1e-12);
audit=landing2d.rl.rewardAudit(c);
R=audit.DiscountedReturn;
assert(all(R([1,2,10])>max(R([4,5]))));
assert(min(R([4,5]))>R(3));
assert(R(3)>max(R([6,7,8])));

% Checkpoint ordering must match the configured terminal ordering. A hover
% timeout may not outrank a bounded safe abort merely by lasting longer.
[abortScore,abortRates]=landing2d.rl.selectionScoreV2({'SAFE_ABORT'},-4);
[timeoutScore,timeoutRates]=landing2d.rl.selectionScoreV2({'TASK_TIMEOUT'},-12);
[successScore,~]=landing2d.rl.selectionScoreV2({'SUCCESS'},25);
[unsafeScore,~]=landing2d.rl.selectionScoreV2({'UNSAFE_CONTACT'},-40);
assert(successScore>abortScore && abortScore>timeoutScore ...
    && timeoutScore>unsafeScore);
assert(abortRates.safeAbort==1 && timeoutRates.timeout==1);

% Prolonged loss starts a bounded recovery maneuver; SAFE_ABORT is terminal
% only after the complete recovery window has elapsed without reacquisition.
backup=landing2d.environment.initialStatus();
backup.abortRequested=true; backup.abortRequestTime=1;
hold=prev; hold.z=p.padHeight+c.experiment.safety.abortHoldHeight;
hold.vz=0;
before=landing2d.environment.evaluateTermination(hold,hold,pad0,pad1, ...
    backup,1.1,0.1,c,di);
afterTime=1+c.experiment.safety.backupDurationLimit;
after=landing2d.environment.evaluateTermination(hold,hold,pad0,pad1, ...
    backup,afterTime,0.1,c,di);
assert(~before.occurred);
assert(after.occurred && strcmp(after.reason,'SAFE_ABORT'));

% Named task outcomes are true terminals: no bootstrap or GAE leakage.
traj=struct('count',1,'reward',1,'value',0.5,'bootstrap',999, ...
    'discount',0.99,'terminated',true,'truncated',false);
[adv,target]=landing2d.rl.computeAdvantage(traj,c.rl);
assert(abs(adv-0.5)<1e-12 && abs(target-1)<1e-12);

[env] = landing2d.environment.reset(c,8);
env.physicalState.z=env.pad.z+0.01; env.physicalState.vz=-0.1;
env.episodeStatus.landingInhibited=false;
[env,~,~,terminated] = landing2d.environment.step(env,[0;0]);
if terminated
    didThrow=false;
    try, landing2d.environment.step(env,[0;0]); catch, didThrow=true; end
    assert(didThrow);
end
end
