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
[safe,comp] = landing2d.rl.computeReward(truth,m,[0;0],0.1,ev1,c);
assert(abs(safe-c.experiment.reward.SUCCESS)<1e-12 && comp.goalCost==0);
unsafeEvent=ev1; unsafeEvent.reason='UNSAFE_CONTACT';
unsafe=landing2d.rl.computeReward(truth,m,[0;0],0.1,unsafeEvent,c);
assert(safe>unsafe);
audit=landing2d.rl.rewardAudit(c);
R=audit.DiscountedReturn;
assert(all(R([1,2,10])>max(R([4,5]))));
assert(min(R([4,5]))>R(3));
assert(R(3)>max(R([6,7,8])));

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
