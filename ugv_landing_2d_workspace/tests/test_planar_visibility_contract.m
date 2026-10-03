function test_planar_visibility_contract()
% Scenario, dynamics, camera, packet and RNG contracts.
c = landing2d.config.primaryConfig(fileparts(fileparts(mfilename('fullpath'))));
landing2d.config.validateConfig(c);
assert(c.rl.actionDim==2 && c.rl.observationDim==26);
assert(c.experiment.validationEpisodeCount==100);
assert(c.experiment.testEpisodeCount==100);
assert(c.experiment.manifest.testSeeds(1)==3001);
assert(isempty(intersect(c.experiment.manifest.testSeeds, ...
    c.experiment.manifest.validationSeeds)));
% The independently constructed final-test configuration must have the
% same signature as the full-training configuration.
fullMode=c;
fullMode.experiment.validationEpisodeCount=100;
fullMode.experiment.testEpisodeCount=100;
assert(isequal(landing2d.rl.trainingSignature(c), ...
    landing2d.rl.trainingSignature(fullMode)));
legacy=landing2d.config.defaultConfig(fileparts(fileparts(mfilename('fullpath'))));
assert(~isequal(landing2d.rl.trainingSignature(c), ...
    landing2d.rl.trainingSignature(legacy)));
p = landing2d.scenario.sampleParameters(c.experiment.scenario,123);
assert(abs(p.v3-(p.v1+p.a2*p.T2))<1e-12);
epsTime = 1e-8;
[xl,vl] = landing2d.scenario.evaluateTrajectory(p,p.T1-epsTime);
[xr,vr] = landing2d.scenario.evaluateTrajectory(p,p.T1+epsTime);
assert(abs(xl-xr)<1e-6 && abs(vl-vr)<1e-6);
[xl,vl] = landing2d.scenario.evaluateTrajectory(p,p.T1+p.T2-epsTime);
[xr,vr] = landing2d.scenario.evaluateTrajectory(p,p.T1+p.T2+epsTime);
assert(abs(xl-xr)<1e-6 && abs(vl-vr)<1e-6);
[~,~,a1,ph1] = landing2d.scenario.evaluateTrajectory(p,p.T1/2);
[~,~,a2,ph2] = landing2d.scenario.evaluateTrajectory(p,p.T1+p.T2/2);
[~,~,a3,ph3] = landing2d.scenario.evaluateTrajectory(p,p.deadline);
assert(a1==0 && a2==p.a2 && a3==0 && isequal([ph1 ph2 ph3],[1 2 3]));
distanceScenario=c.experiment.scenario;
distanceScenario.parameterization='distance';
distanceScenario.a2Range=[0,0];
distanceScenario.L1Range=[1,1]; distanceScenario.L2Range=[2,2];
distanceScenario.L3Range=[3,3];
pd=landing2d.scenario.sampleParameters(distanceScenario,321);
assert(abs(pd.v3-pd.v1)<1e-12 && abs(pd.T2-2/pd.v1)<1e-12);

d = c.experiment.dynamics;
[thetaSp,thrustSp] = landing2d.dynamics.accelerationToThrustPitch([1;0],d);
assert(thetaSp>0 && thrustSp>d.mass*d.gravity);
s = struct('x',0,'z',5,'vx',0,'vz',0,'theta',0,'pitchRate',0, ...
    'collectiveThrust',d.mass*d.gravity);
[s2,di] = landing2d.dynamics.stepPlanar(s,[0;0],c.dt,d,0);
assert(abs(s2.vx)<1e-12 && abs(s2.vz)<1e-12);
assert(all(abs(di.actualAcceleration)<1e-12));
assert(~isfield(s2,'y') && ~isfield(s2,'roll') && ~isfield(s2,'yaw'));

pad = struct('x',1,'z',0);
s.theta = 0;
q0 = landing2d.sensing.projectPad(s,pad,c.experiment.sensor);
s.theta = deg2rad(5);
q1 = landing2d.sensing.projectPad(s,pad,c.experiment.sensor);
assert(q1.bearing>q0.bearing);
s.theta = 0; h=s.z-pad.z;
pad.x = h*tan(c.experiment.sensor.fov/2);
qb = landing2d.sensing.projectPad(s,pad,c.experiment.sensor);
assert(~qb.visible);
pad.x = 0; qn = landing2d.sensing.projectPad(s,pad,c.experiment.sensor);
assert(abs(qn.bearing)<1e-12 && qn.visible && qn.depth>0);
s.theta=pi; qBehind=landing2d.sensing.projectPad(s,pad,c.experiment.sensor);
assert(~qBehind.visible && qBehind.depth<0);

[e1,o1] = landing2d.environment.reset(c,77);
policyRs = RandStream('threefry','Seed',999); rand(policyRs,100,1);
[e2,o2] = landing2d.environment.reset(c,77);
assert(isequaln(e1.scenario,e2.scenario) && isequal(o1,o2));
end
