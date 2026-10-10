function report = selfTest()
% SELFTEST  Compact final-contract regression suite.
checks={@checkContract,@checkCausalBoundary,@checkScenarioDynamics, ...
    @checkTermination,@checkContextGraph,@checkPpoSmoke, ...
    @checkRelationGuard,@checkPaperScenarios,@checkSpatial3d, ...
    @checkCommonObservation,@checkRelationShuffle,@checkProbeReplay, ...
    @checkBehaviorValidity};
names={"contract","causal-boundary","scenario-dynamics","termination", ...
    "context-graph","ppo-smoke","direct-rgat","paper-scenarios", ...
    "spatial-3d","common-observation","relation-shuffle","probe-replay", ...
    "behavior-validity"};
passed=false(numel(checks),1); messages=strings(numel(checks),1);
for i=1:numel(checks)
    try
        checks{i}(); passed(i)=true; messages(i)="PASS";
    catch err
        messages(i)=string(getReport(err,'basic','hyperlinks','off'));
    end
    fprintf('  self-test [%d/%d] %-20s %s\n', ...
        i,numel(checks),names{i},messages(i));
end
report=table(names',passed,messages, ...
    'VariableNames',{'Check','Passed','Message'});
assert(all(passed),'landing2d:SelfTestFailed', ...
    '%d final-contract self-test(s) failed.',sum(~passed));
end

function checkContract()
% Planar policy observation = minimal 12-D common observation; two methods
% methods sharing one task contract with separate checkpoints and signatures;
% the relation-shuffle ablation shares the contract but is not official.
c=baseConfig();
landing2d.config.validateConfig(c);
schema=c.experiment.observationSchema;
assert(c.rl.actionDim==2 && c.rl.observationDim==schema.dimension ...
    && schema.dimension==12 && strcmp(schema.version,c.experiment.commonObservation.schemaVersion));
assert(c.experiment.validationEpisodeCount==100 ...
    && c.experiment.testEpisodeCount==100);
% Planar reward_v5: camera-aim goal, approach-manifold velocity potential,
% and a pseudo-Huber running goal cost. At the
% aim point with matched speed the potential is the altitude term only, and
% flying over the pad at altitude (aim -> e_x = 0) lowers the potential.
r=c.experiment.reward;
assert(r.goalCameraAim && r.potentialWeight==4 && r.velocityPotentialWeight==4 ...
    && r.velocityLength==1 && r.approachPositionRate==0.35 ...
    && r.targetRelativeSpeed==1 && r.verticalPotentialWeight==4 ...
    && r.verticalSpeedLength==0.5 && r.targetDescentSpeed==0.4 ...
    && r.verticalPositionRate==0.8 ...
    && strcmp(r.goalRunningCost,'pseudo_huber_v1') && r.goalHuberDelta==1);
h=6; aim=h*tan(-c.experiment.sensor.cameraPitchOffset);
truth=@(ex,rvx)struct('ex',ex,'h',h,'relativeVx',rvx,'vz',0,'theta',0,'pitchRate',0);
noEvent=struct('occurred',false,'reason','');
m=struct('detected',false,'bearingValid',false);
[~,onAim]=landing2d.rl.computeReward(truth(aim,0),truth(aim,0),m,[0;0],0.1,noEvent,c);
[~,overPad]=landing2d.rl.computeReward(truth(aim,0),truth(0,0),m,[0;0],0.1,noEvent,c);
[~,lagging]=landing2d.rl.computeReward(truth(aim,0),truth(aim,1),m,[0;0],0.1,noEvent,c);
[~,far1]=landing2d.rl.computeReward(truth(aim+10*r.goalLengthX,0), ...
    truth(aim+10*r.goalLengthX,0),m,[0;0],0.1,noEvent,c);
[~,far2]=landing2d.rl.computeReward(truth(aim+20*r.goalLengthX,0), ...
    truth(aim+20*r.goalLengthX,0),m,[0;0],0.1,noEvent,c);
q=@(u)u^2/(1+u^2);
assert(abs(onAim.goalCost-(1-r.goalHorizontalShare)*q(h/r.goalLengthH))<1e-12 ...
    && onAim.trackCost==0 && overPad.potentialShaping<-0.5 ...
    && abs(lagging.trackCost-0.5)<1e-12 && lagging.potentialShaping<-1.9);
% The bounded potential saturates far away, whereas the running cost retains
% an approximately linear restoring slope.
assert(far2.goalCost-far1.goalCost<0.01 ...
    && far2.runningGoalCost-far1.runningGoalCost>10);
assert(strcmp(c.rl.trainingRegime,'direct_ppo_v1') ...
    && strcmp(c.experiment.actionApplication,'direct_policy_v1') ...
    && ~c.graphState.pretrain.enabled && ~c.graphState.freezeStaticBackbone ...
    && strcmp(c.graphState.readout,'grouped_factorized') ...
    && ~c.graphState.preserveRawPolicyDuringGraphAdaptation ...
    && c.graphState.graphAdaptationWarmupFraction==0 ...
    && c.rl.ppoIterations==750 && c.rl.episodesPerIteration==6 ...
    && ~c.rl.inputNormalization.enabled ...
    && c.graphState.hiddenDim==16 && c.graphState.graphDim==16 ...
    && isequal(c.graphState.policyHiddenSizes,[38,37]) ...
    && isequal(c.graphState.valueHiddenSizes,[35,34]));
assert(landing2d.rl.checkpointEligible(c.rl,NaN));
assert(isempty(intersect(c.experiment.manifest.validationSeeds, ...
    c.experiment.manifest.testSeeds)));
registry=landing2d.config.methodRegistry();
assert(isequal({registry.methods.id},{'ppo','onto_rgat_ppo'}) ...
    && isequal({registry.ablations.id},{'shuffled_rgat_ppo'}) ...
    && ~ismember('context_flat',{registry.methods.representation}));
arms=landing2d.config.comparisonArms(c);
assert(numel(arms)==2);
configs=[{arms.config},{landing2d.config.applyMethod(c,'shuffled_rgat_ppo',1,1)}];
fingerprints=strings(1,3); files=strings(1,3); signatures=cell(1,3);
for i=1:3
    fingerprints(i)=string(landing2d.environment.taskFingerprint(configs{i}));
    files(i)=string(configs{i}.rl.policyFile);
    signatures{i}=landing2d.rl.trainingSignature(configs{i});
end
assert(all(fingerprints==fingerprints(1)) && numel(unique(files))==3);
assert(~isequal(signatures{2},signatures{3}));
second=landing2d.config.comparisonArms(c,struct('trainSeed',2,'graphSeed',2));
assert(second(1).config.rl.seed==arms(1).config.rl.seed+1 ...
    && ~any(ismember(string(arrayfun(@(a)a.config.rl.policyFile,second,'UniformOutput',false)),files)));
% Execution-only parallel settings do not make a checkpoint incompatible;
% a different training seed does.
worker=arms(1).config; worker.rl.parallelWorkers=3; worker.rl.parallelEpisodes=false;
assert(landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(worker),arms(1).config) ...
    && ~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(second(1).config), ...
    arms(1).config));
end

function checkCausalBoundary()
c=baseConfig();
[~,observation,info]=landing2d.environment.reset(c,5);
O=info.commonObservation; G=info.observationContext;
assert(numel(observation)==c.experiment.observationSchema.dimension ...
    && isequal(observation,landing2d.observation.toVector(O,G)));
for name={'phase','truePadAcceleration','terminalReason','futurePadX', ...
        'landingInhibited','abortRequested','remainingMissionTime'}
    assert(~isfield(O,name{1}) && ~isfield(O.ugv,name{1}) && ~isfield(O.drone,name{1}));
end
arm=landing2d.config.applyMethod(c,'onto_rgat_ppo');
bad=O; bad.futurePadX=0;
assertThrows(@()landing2d.graphstate.observationGraph(bad,G,arm), ...
    'landing2d:InformationLeakage');
packetArm=arm; packetArm.graphState=rmfield(arm.graphState,{'observationSource','observationFeatures'});
badPacket=info.packet; badPacket.futurePadX=0;
assertThrows(@()landing2d.graphstate.contextGraph(badPacket,packetArm), ...
    'landing2d:InformationLeakage');
end

function checkScenarioDynamics()
c=baseConfig(); p=landing2d.scenario.sampleParameters(c.experiment.scenario,123);
assert(abs(p.v3-(p.v1+p.a2*p.T2))<1e-12);
for boundary=[p.T1,p.T1+p.T2]
    [xl,vl]=landing2d.scenario.evaluateTrajectory(p,boundary-1e-8);
    [xr,vr]=landing2d.scenario.evaluateTrajectory(p,boundary+1e-8);
    assert(abs(xl-xr)<1e-6 && abs(vl-vr)<1e-6);
end
end

function checkTermination()
c=baseConfig(); p=landing2d.scenario.sampleParameters(c.experiment.scenario,4);
c.experiment.currentScenario=p; d=c.experiment.dynamics;
pad=struct('x',0,'z',p.padHeight,'vx',0);
above=struct('x',0,'z',p.padHeight+c.experiment.safety.touchdownHeight+0.005, ...
    'vx',0,'vz',-0.1,'theta',0,'pitchRate',0, ...
    'collectiveThrust',d.mass*d.gravity);
below=above; below.z=p.padHeight+c.experiment.safety.touchdownHeight-0.005;
status=landing2d.environment.initialStatus(); status.landingInhibited=false;
di=struct('hardEnvelopeViolation',false);
event=landing2d.environment.evaluateTermination(above,below,pad,pad, ...
    status,1,0.1,c,di);
assert(event.physicalContact && strcmp(event.reason,'SUCCESS'));
status.landingInhibited=true;
blocked=landing2d.environment.evaluateTermination(above,below,pad,pad, ...
    status,1,0.1,c,di);
% Planar direct-policy contact has no authorization guard; the identical
% mechanically safe contact remains SUCCESS even after a perception loss.
assert(strcmp(blocked.reason,'SUCCESS') && blocked.authorized);
end

function checkContextGraph()
% Planar graph: built from the common observation only (no packet), same
% nodes/relations/edges/groups/12 channels; node features do not depend on
% the relation assignment (canonical, shuffled and flat inputs coincide).
c=landing2d.config.applyMethod(baseConfig(),'onto_rgat_ppo');
env=landing2d.environment.reset(c,9);
noPacket=env; noPacket.packet=[];
[state,detail]=landing2d.graphstate.environmentGraph(noPacket,c);
schema=detail.schema;
assert(schema.nNodes==7 && schema.nRelations==4 && numel(schema.src)==16 ...
    && schema.inDim==6 ...
    && strcmp(schema.variant,'minimal_observation_rgat_v3'));
assert(numel(state)==schema.inDim*schema.nNodes ...
    && all(abs(state)<=1));
assert(isequal(state,landing2d.graphstate.environmentGraph(noPacket,c, ...
    detail.observationVector)));
[~,spec]=landing2d.graphstate.encoderInit(c.graphState,c.rl.observationDim, ...
    RandStream('threefry','Seed',17));
assert(strcmp(spec.schema.variant,'minimal_observation_rgat_v3') ...
    && isequal(spec.groupMatrix,eye(7)));
flat=landing2d.graphstate.applyStateRepresentation(c,'context_flat');
shuffled=landing2d.config.applyMethod(baseConfig(),'shuffled_rgat_ppo',1,1);
flatState=landing2d.graphstate.environmentGraph(env,flat);
assert(isequal(state,flatState) ...
    && isequal(state,landing2d.graphstate.environmentGraph(env,shuffled)));
% Node features are a deterministic function of the registered 12-D vector.
[~,~,info]=landing2d.environment.reset(c,9);
O=info.commonObservation; G=info.observationContext;
O.ugv.estimateInitialized=true; O.ugv.visionUpdated=false; O.ugv.visionAge=1.0;
A=landing2d.graphstate.observationGraph(O,G,c);
changed=c; changed.experiment.safety.prolongedLoss=12;
B=landing2d.graphstate.observationGraph(O,G,changed);
assert(isequal(A,B));
end

function checkPpoSmoke()
cBaseline=landing2d.config.applyMethod(baseConfig(),'ppo');
baselineAgent=landing2d.rl.agentInit(cBaseline.rl, ...
    RandStream('threefry','Seed',1233),cBaseline.graphState);
assert(~isfield(baselineAgent,'inputNorm'));
c=landing2d.config.applyMethod(baseConfig(),'onto_rgat_ppo');
c.rl.ppoIterations=1; c.rl.episodesPerIteration=1; c.rl.ppoEpochs=1;
c.rl.miniBatch=64; c.rl.evaluateEvery=1; c.rl.valueWarmup=0;
c.rl.parallelEpisodes=false; c.rl.verbose=false;
c.experiment.validationEpisodeCount=1;
rs=RandStream('threefry','Seed',1234);
agent=landing2d.rl.agentInit(c.rl,rs,c.graphState);
assert(strcmp(agent.encoderSpec.readout,'grouped_factorized') ...
    && ~isfield(agent.policy,'relation') && ~isfield(agent,'inputNorm'));
baselineProfile=landing2d.rl.profileAgent(baselineAgent,cBaseline,1,1);
graphProfile=landing2d.rl.profileAgent(agent,c,1,1);
assert(baselineProfile.parameterCount==6101 ...
    && graphProfile.parameterCount==6101 ...
    && abs(graphProfile.parameterCount/baselineProfile.parameterCount-1)<1e-3);
[trained,history,last]=landing2d.rl.ppoTrain(agent,c,rs);
assert(numel(history)>=2 && all(isfinite([history.score])));
assert(~isfield(trained.policy,'relation') && ~isfield(last.value,'relation'));
end

function checkRelationGuard()
c=landing2d.graphstate.applyStateRepresentation(baseConfig(),'context_rgat');
agent=landing2d.rl.agentInit(c.rl,RandStream('threefry','Seed',77),c.graphState);
assert(strcmp(agent.encoderSpec.readout,'grouped_factorized') ...
    && agent.encoderSpec.graphDim==c.graphState.graphDim ...
    && ~isfield(agent.policy,'relation') && ~isfield(agent.value,'relation') ...
    && ~isempty(agent.policy.encoder.W1) && ~isempty(agent.policy.encoder.Wc) ...
    && ~isempty(agent.policy.encoder.Wn));
end

function checkPaperScenarios()
c=baseConfig(); specs=landing2d.paper.representativeScenarios(c);
assert(isequal(string({specs.id}),["S1","S2","S3"]));
feasible=arrayfun(@(x)landing2d.paper.scenarioFeasibility(x,c).PhysicalFeasible, ...
    specs);
assert(all(feasible));
assert(strcmp(specs(3).sensorEvents.dropoutKind,'short'));
end

function checkSpatial3d()
% 3D option: planar reduction, shared task contract, causal packet, graph,
% three-axis policy, lateral contact footprint.
c2=baseConfig(); c=landing2d.config.applySpatialDimension(c2,3);
landing2d.config.validateConfig(c);
assert(c.rl.actionDim==3 && c.rl.observationDim==37);
d=c.experiment.dynamics;
s2=struct('x',0,'z',5,'vx',1,'vz',-0.2,'theta',0.05,'pitchRate',0.1, ...
    'collectiveThrust',d.mass*d.gravity);
s3=s2; s3.y=0; s3.vy=0; s3.roll=0; s3.rollRate=0;
for k=1:50
    a=[1.5*sin(k/10);-0.6*cos(k/7)];
    s2=landing2d.dynamics.stepPlanar(s2,a,0.01,d,0);
    s3=landing2d.dynamics.stepSpatial(s3,[a(1);0;a(2)],0.01,d,0);
end
for name=fieldnames(s2)'
    assert(isequal(s2.(name{1}),s3.(name{1})),'Planar reduction differs: %s',name{1});
end
assert(s3.y==0 && s3.roll==0);
modes={'baseline','context_flat','context_rgat'}; fingerprints=strings(size(modes));
for i=1:numel(modes)
    arm=landing2d.graphstate.applyStateRepresentation(c,modes{i});
    fingerprints(i)=string(landing2d.environment.taskFingerprint(arm));
end
assert(all(fingerprints==fingerprints(1)));
assert(fingerprints(1)~=string(landing2d.environment.taskFingerprint(c2)));
[env,observation,info]=landing2d.environment.reset(c,5);
assert(numel(observation)==37 && info.packet.trackInitialized && isfield(env.pad,'y'));
arm=landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
[state,detail]=landing2d.graphstate.contextGraph(info.packet,arm);
assert(detail.schema.inDim==14 && numel(state)==14*detail.schema.nNodes);
rs=RandStream('threefry','Seed',31);
agent=landing2d.rl.agentInit(arm.rl,rs,arm.graphState);
u=landing2d.rl.policyAction(agent,state,rs,true);
assert(numel(u)==3);
% 3D-only training settings: lateral exploration noise and a touchdown
% attitude curriculum that returns exactly to the nominal envelope.
assert(agent.policy.logStd(2)==c.rl.lateralInitialLogStd && ...
    agent.policy.logStd(1)==c.rl.initialLogStd);
assert(~isfield(c2.rl,'lateralInitialLogStd') && ...
    ~isfield(c2.rl,'touchdownAttitudeCurriculumScale') && ...
    ~isfield(c2.rl,'trackAuthorizationCurriculumScale'));
easy=landing2d.rl.trainingEpisodeConfig(c,1,0);
nominal=landing2d.rl.trainingEpisodeConfig(c,1,1);
s0=c.experiment.safety;
assert(abs(easy.experiment.safety.touchdownPitchRateTolerance- ...
    c.rl.touchdownAttitudeCurriculumScale*s0.touchdownPitchRateTolerance)<1e-12);
assert(nominal.experiment.safety.touchdownPitchTolerance==s0.touchdownPitchTolerance ...
    && nominal.experiment.safety.touchdownPitchRateTolerance==s0.touchdownPitchRateTolerance);
assert(abs(easy.experiment.safety.recentTrackGrace- ...
    c.rl.trackAuthorizationCurriculumScale*s0.recentTrackGrace)<1e-12);
assert(nominal.experiment.safety.recentTrackGrace==s0.recentTrackGrace ...
    && nominal.experiment.safety.minimumTrackConfidence==s0.minimumTrackConfidence);
% Final-descent phase: authorization survives losing the pad center inside
% the low band, expires after its duration or above the exit height, and is
% absent from a planar tracker-based contract (the planar marker-camera
% supervisor configures its own band, see checkCommonObservation).
sp=c.experiment.spatial; zPad=c.experiment.scenario.padHeight;
track=landing2d.sensing.initialPadTrack(c.experiment.sensor,true);
track.initialized=true; track.timeSinceLastDetection=0; track.lastConfidence=0.9;
low=struct('z',zPad+0.5*sp.finalDescentHeight);
st=landing2d.environment.updateDecisionContext(landing2d.environment.initialStatus(3), ...
    track,10,c,low);
assert(st.finalDescentActive && ~st.landingInhibited);
blind=track; blind.timeSinceLastDetection=1.0; blind.lastConfidence=0;
st=landing2d.environment.updateDecisionContext(st,blind,11,c,low);
assert(st.finalDescentActive && ~st.landingInhibited);
expired=landing2d.environment.updateDecisionContext(st,blind, ...
    10+sp.finalDescentMaxDuration+0.1,c,low);
assert(~expired.finalDescentActive && expired.landingInhibited);
high=landing2d.environment.updateDecisionContext(st,blind,11.5,c, ...
    struct('z',zPad+sp.finalDescentExitHeight+0.05));
assert(~high.finalDescentActive && high.landingInhibited);
trackerPlanar=c2; trackerPlanar.experiment=rmfield(c2.experiment,'commonObservation');
planar=landing2d.environment.updateDecisionContext(landing2d.environment.initialStatus(), ...
    track,10,trackerPlanar,low);
assert(~isfield(planar,'finalDescentActive'));
assert(c.experiment.reward.actionChangeWeight>0 ...
    && ~isfield(c2.experiment.reward,'actionChangeWeight'));
% The 3D option keeps reward_v2 and the episode-level curriculum contract
% without input standardization (planar reward_v5 / PPO fields removed).
assert(c.experiment.reward.potentialWeight==2 && ~any(isfield(c.experiment.reward, ...
    {'goalCameraAim','goalRunningCost','goalHuberDelta', ...
    'velocityPotentialWeight','velocityLength', ...
    'approachPositionRate','targetRelativeSpeed', ...
    'verticalPotentialWeight','verticalSpeedLength','targetDescentSpeed', ...
    'verticalPositionRate'})) ...
    && ~any(isfield(c.rl,{'inputNormalization','curriculumReplayContract'})));
[env,~,~,~,~,stepInfo]=landing2d.environment.step(env,tanh(u));
assert(numel(stepInfo.appliedAccelerationIntervalMean)==3 && isfield(env.physicalState,'roll'));
p=landing2d.scenario.sampleParameters(c.experiment.scenario,123);
for boundary=[p.T1,p.T1+p.T2]
    left=landing2d.scenario.padState(p,boundary-1e-8);
    right=landing2d.scenario.padState(p,boundary+1e-8);
    assert(abs(left.y-right.y)<1e-6 && abs(left.vy-right.vy)<1e-6);
end
c.experiment.currentScenario=p;
pad=struct('x',0,'y',0,'z',p.padHeight,'vx',0,'vy',0);
above=struct('x',0,'y',0,'z',p.padHeight+c.experiment.safety.touchdownHeight+0.005, ...
    'vx',0,'vy',0,'vz',-0.1,'theta',0,'pitchRate',0,'roll',0,'rollRate',0, ...
    'collectiveThrust',d.mass*d.gravity);
below=above; below.z=p.padHeight+c.experiment.safety.touchdownHeight-0.005;
status=landing2d.environment.initialStatus(3); status.landingInhibited=false;
di=struct('hardEnvelopeViolation',false);
event=landing2d.environment.evaluateTermination(above,below,pad,pad,status,1,0.1,c,di);
assert(strcmp(event.reason,'SUCCESS'));
offset=above; offset.y=c.experiment.spatial.padHalfWidth+0.1;
offsetBelow=offset; offsetBelow.z=below.z;
missed=landing2d.environment.evaluateTermination(offset,offsetBelow,pad,pad, ...
    status,1,0.1,c,di);
assert(strcmp(missed.reason,'MISSED_PAD_CONTACT'));
end

function checkCommonObservation()
% o_t = [G;D;H] (24-D): UGV state from corners -> planar PnP -> KF, drone
% navigation with the paper noise, previous-decision motion record; Gamma
% stays out of o_t; capture accepts only detections and navigation; prediction
% (never truth) while unseen; one planar camera (tracker geometry = marker
% camera); start with the pad on the optical axis; marker perception drives
% landing authorization (with the blind final-descent latch) and the safety
% supervisor; the 3D option keeps its downward camera and tracker supervisor.
c=baseConfig(); co=c.experiment.commonObservation;
[env,~,info]=landing2d.environment.reset(c,5);
G=info.observationContext; O=info.commonObservation;
schema=landing2d.observation.vectorSchema(G);
assert(schema.dimension==12 && numel(unique(schema.names))==12);
assert(isequal(fieldnames(O)',{'schemaVersion','decisionTime','ugv','drone','history'}));
assert(isequal(fieldnames(O.ugv)',{'positionXZ','velocityXZ','visionUpdated', ...
    'visionAge','estimateInitialized','visionStamp'}));
assert(isequal(fieldnames(O.drone)',{'positionXZ','velocityXZ','pitchSinCos', ...
    'pitchRate','navigationValid','navigationAge','navigationStamp'}));
assert(isequal(fieldnames(O.history)',{'ugvPositionXZ','ugvVelocityXZ', ...
    'dronePositionXZ','droneVelocityXZ','ugvInitialized','valid'}) && ~O.history.valid);
assert(isequal(fieldnames(G)',{'version','camera','pad','ugv','estimator','frames', ...
    'history','normalization'}) && ~isfield(G,'detector') && ~isfield(G,'navigation'));
% Paper camera: 512x320, horizontal FOV 90 deg, optical axis 60 deg below
% forward; the planar tracker uses the same x-z geometry.
K=G.camera.intrinsicMatrix; W=G.camera.imageSize(1); sensor=c.experiment.sensor;
assert(isequal(G.camera.imageSize,[512,320]) && abs(K(1,1)*tand(45)-(W-1)/2)<1e-9);
assert(norm(G.camera.bodyToCamera(1:3,3)-[cosd(60);0;-sind(60)])<1e-12);
assert(abs(sensor.cameraPitchOffset+deg2rad(30))<1e-12 ...
    && abs(sensor.fov-2*atan(K(2,3)/K(2,2)))<1e-12 ...
    && abs(c.cameraFovDeg-rad2deg(sensor.fov))<1e-12);
% Start with the pad center on the optical axis (behind the pad), seen and
% authorized from the first frame.
h0=env.physicalState.z-env.pad.z;
assert(abs(env.physicalState.x-(env.pad.x+h0*tan(sensor.cameraPitchOffset)))<1e-12 ...
    && env.physicalState.x<env.pad.x && info.packet.trackInitialized);
assert(O.ugv.estimateInitialized && O.ugv.visionUpdated && ~env.episodeStatus.landingInhibited);
% Vector: x relative to the current drone x (drone_x = 0), z/velocity scaled.
x=landing2d.observation.toVector(O,G);
named=@(v,name)v(strcmp(schema.names,name));
assert(numel(x)==12 && all(isfinite(x)));
dx=O.ugv.positionXZ(1)-O.drone.positionXZ(1);
assert(abs(named(x,'relative_x')-dx/(abs(dx)+G.normalization.relativePosition))<1e-12);
% capture has no input path for truth or derived estimates.
noiseFree=co; noiseFree.detector.pixelNoiseStd=0;
frame=struct('dropout',false,'frameCaptured',true);
exact=struct('velocityNoiseStd',0,'attitudeNoiseStd',0);
see=@(s,p,t,cfg,ev)landing2d.sensing.detectMarkers(s,p,t,sensor,cfg,[],ev);
fix=@(s,t)landing2d.sensing.navigationEstimate(s,t,exact,[]);
pad=struct('x',20,'z',c.experiment.scenario.padHeight,'vx',3);
state=struct('x',pad.x-1,'z',pad.z+2,'vx',3,'vz',0,'theta',0.05,'pitchRate',0);
leaky=fix(state,0); leaky.padX=pad.x;
assertThrows(@()landing2d.observation.capture(landing2d.observation.initialMemory(), ...
    see(state,pad,0,noiseFree,frame),leaky,0,G),'landing2d:InformationLeakage');
% Noise-free corners recover the UGV reference point through
% WT_G = WT_B BT_C CT_P PT_G, from several markers or a single marker, in any
% detection order; unregistered IDs are ignored; lens distortion is undone.
truthUgv=[pad.x;pad.z]-G.ugv.padOffset;
det=see(state,pad,0,noiseFree,frame);
assert(numel(det.ids)>=2);
measure=@(d,g)landing2d.observation.ugvPositionMeasurement( ...
    landing2d.observation.estimatePadPose(d,g),fix(state,0),g);
assert(norm(measure(det,G)-truthUgv)<1e-9);
single=det; single.ids=det.ids(1); single.corners=det.corners(1,:,:);
assert(norm(measure(single,G)-truthUgv)<1e-9);
shuffled=det; order=numel(det.ids):-1:1;
shuffled.ids=[det.ids(order);999]; shuffled.corners=cat(1,det.corners(order,:,:),zeros(1,4,2));
assert(norm(measure(shuffled,G)-measure(det,G))<1e-12);
lens=[-0.12,0.03,1e-3,-5e-4,-0.004];
xy=[-0.4,-0.1,0.2,0.35;0.3,-0.25,0.05,-0.3];
distorted=K(1:2,:)*[landing2d.sensing.distortPoints(xy,lens);ones(1,4)];
assert(max(abs(landing2d.sensing.undistortPoints(distorted,K,lens)-K(1:2,:)*[xy;ones(1,4)]), ...
    [],'all')<1e-6);
barrel=noiseFree; barrel.camera.distortion=lens;
cBarrel=c; cBarrel.experiment.commonObservation=barrel;
rawBarrel=see(state,pad,0,barrel,frame);
[~,ia,ib]=intersect(det.ids,rawBarrel.ids);
assert(~isempty(ia) && max(abs(rawBarrel.corners(ib,:,:)-det.corners(ia,:,:)),[],'all')>0.3);
assert(norm(measure(rawBarrel,landing2d.observation.staticContext(cBarrel))-truthUgv)<1e-8);
% BT_C drives the projection: a forward camera offset equals moving the pad
% back, and a pitched mount equals pitching the drone.
shifted=noiseFree; shifted.camera.bodyToCamera(1:3,4)=[0.1;0;0];
level=state; level.theta=0; padBack=pad; padBack.x=pad.x-0.1;
assert(max(abs(see(level,pad,0,shifted,frame).corners ...
    -see(level,padBack,0,noiseFree,frame).corners),[],'all')<1e-9);
tilted=noiseFree; phi=0.03;
tilted.camera.bodyToCamera(1:3,1:3)=[cos(phi),0,sin(phi);0,1,0;-sin(phi),0,cos(phi)] ...
    *noiseFree.camera.bodyToCamera(1:3,1:3);
pitched=state; pitched.theta=state.theta+phi;
assert(max(abs(see(state,pad,0,tilted,frame).corners ...
    -see(pitched,pad,0,noiseFree,frame).corners),[],'all')<1e-9);
% Kalman filter: never-initialized state is flagged (age Inf -> 1, zeros), a
% seen constant-velocity UGV is tracked, unseen frames are predicted (never
% truth), and the previous-decision record is the last reported motion.
memory=landing2d.observation.initialMemory();
dark=struct('dropout',true,'frameCaptured',true);
[On,memory]=landing2d.observation.capture(memory,see(state,pad,0,noiseFree,dark), ...
    fix(state,0),0,G);
xn=landing2d.observation.toVector(On,G);
assert(~On.ugv.estimateInitialized && isinf(On.ugv.visionAge) && ~any(On.ugv.positionXZ) ...
    && named(xn,'ugv_visionAge')==1 && ~any(xn(1:4)));
for k=1:30
    t=0.1*k; padK=pad; padK.x=pad.x+pad.vx*t; stateK=state; stateK.x=state.x+pad.vx*t;
    [Ok,memory]=landing2d.observation.capture(memory,see(stateK,padK,t,noiseFree,frame), ...
        fix(stateK,t),t,G);
end
assert(Ok.ugv.visionUpdated && Ok.ugv.visionAge==0 && Ok.history.valid ...
    && norm(Ok.ugv.positionXZ-([padK.x;padK.z]-G.ugv.padOffset))<1e-6 ...
    && norm(Ok.ugv.velocityXZ-[pad.vx;0])<1e-6);
for k=31:35
    t=0.1*k; stateK=state; stateK.x=state.x+pad.vx*t;
    [Op,memory]=landing2d.observation.capture(memory,see(stateK,padK,t,noiseFree,dark), ...
        fix(stateK,t),t,G);
end
assert(~Op.ugv.visionUpdated && abs(Op.ugv.visionAge-0.5)<1e-9 ...
    && abs(Op.ugv.positionXZ(1)-(Ok.ugv.positionXZ(1)+0.5*Ok.ugv.velocityXZ(1)))<1e-6);
[Oq,~]=landing2d.observation.capture(memory,see(stateK,padK,3.6,noiseFree, ...
    struct('dropout',false,'frameCaptured',false)),fix(stateK,3.6),3.6,G);
assert(~Oq.ugv.visionUpdated && isequal(Oq.history.ugvPositionXZ,Op.ugv.positionXZ) ...
    && isequal(Oq.history.droneVelocityXZ,Op.drone.velocityXZ) && Oq.history.ugvInitialized);
% Paper navigation noise: 1-sigma pitch 0.5 deg added to the angle before
% sin/cos, body-frame velocity 0.05 m/s; position and pitch rate exact.
rs=RandStream('threefry','Seed',11); n=4000; dTheta=zeros(1,n); dBody=zeros(2,n);
moving=struct('x',3,'z',5,'vx',4,'vz',-0.5,'theta',0.1,'pitchRate',0.2);
toBody=@(a)[cos(a),-sin(a);sin(a),cos(a)];
for k=1:n
    nav=landing2d.sensing.navigationEstimate(moving,0,co.navigation,rs);
    th=atan2(nav.pitchSinCos(1),nav.pitchSinCos(2)); dTheta(k)=th-moving.theta;
    dBody(:,k)=toBody(th)*nav.velocityXZ-toBody(moving.theta)*[moving.vx;moving.vz];
    assert(isequal(nav.positionXZ,[moving.x;moving.z]) && nav.pitchRate==moving.pitchRate);
end
assert(abs(std(dTheta)/co.navigation.attitudeNoiseStd-1)<0.05 ...
    && all(abs(std(dBody,0,2)/co.navigation.velocityNoiseStd-1)<0.05));
% Perception-driven decision context and supervisor input: recent vision
% authorizes landing, stale vision inhibits it, prolonged loss requests the
% backup; the blind final-descent latch keeps authorization below enterHeight
% until it expires or the drone climbs above exitHeight.
fd=co.finalDescent; s0=c.experiment.safety; zPad=c.experiment.scenario.padHeight;
status0=landing2d.environment.initialStatus();
seen=Ok; seen.decisionTime=10; seen.ugv.visionAge=0.2;
high=struct('x',padK.x-1,'z',zPad+2,'vx',3,'vz',0);
[view,track]=landing2d.environment.perceptionView(seen,high,status0,10.05, ...
    struct('padHeight',zPad),c);
st=landing2d.environment.updateDecisionContext(status0,track,10,c,high);
assert(~st.landingInhibited && ~st.abortRequested && view.trackInitialized ...
    && abs(view.exEstimate-(seen.ugv.positionXZ(1)+0.05*seen.ugv.velocityXZ(1) ...
    +G.ugv.padOffset(1)-high.x))<1e-12 && abs(view.h-2)<1e-12);
stale=seen; stale.ugv.visionAge=s0.recentTrackGrace+0.1;
[~,track]=landing2d.environment.perceptionView(stale,high,st,10,struct('padHeight',zPad),c);
assert(landing2d.environment.updateDecisionContext(st,track,10,c,high).landingInhibited);
lost=seen; lost.ugv.visionAge=s0.prolongedLoss;
[~,track]=landing2d.environment.perceptionView(lost,high,st,10,struct('padHeight',zPad),c);
assert(landing2d.environment.updateDecisionContext(st,track,10,c,high).abortRequested);
low=struct('x',padK.x,'z',zPad+0.5*fd.enterHeight,'vx',3,'vz',-0.2);
[~,track]=landing2d.environment.perceptionView(seen,low,st,20,struct('padHeight',zPad),c);
latched=landing2d.environment.updateDecisionContext(st,track,20,c,low);
assert(latched.finalDescentActive && ~latched.landingInhibited);
blind=seen; blind.ugv.visionAge=1.0;
[~,track]=landing2d.environment.perceptionView(blind,low,latched,21,struct('padHeight',zPad),c);
kept=landing2d.environment.updateDecisionContext(latched,track,21,c,low);
assert(kept.finalDescentActive && ~kept.landingInhibited);
expired=landing2d.environment.updateDecisionContext(kept,track,20+fd.maxDuration+0.1,c,low);
assert(~expired.finalDescentActive && expired.landingInhibited);
climbed=landing2d.environment.updateDecisionContext(kept,track,21.5,c, ...
    struct('z',zPad+fd.exitHeight+0.05));
assert(~climbed.finalDescentActive && climbed.landingInhibited);
% The perception settings are task contract: they change the fingerprint and
% the training signature, and all three arms share them.
legacy=c; legacy.experiment=rmfield(legacy.experiment,'commonObservation');
envLegacy=landing2d.environment.reset(legacy,5);
assert(isempty(envLegacy.commonObservation) && isempty(envLegacy.observationContext));
assert(~isequal(landing2d.environment.taskFingerprint(c), ...
    landing2d.environment.taskFingerprint(legacy)));
arm=landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
assert(isfield(landing2d.rl.trainingSignature(arm).experiment,'commonObservation'));
[env,~,~,~,~,stepInfo]=landing2d.environment.step(env,[0.3;-0.2]);
H=env.commonObservation.history;
assert(H.valid && H.ugvInitialized && isequal(H.dronePositionXZ,O.drone.positionXZ) ...
    && isequal(H.ugvPositionXZ,O.ugv.positionXZ) && isfield(stepInfo.perceptionError,'position'));
% The 3D option drops the planar perception: downward cone camera, start
% above the pad, tracker-based supervisor.
c3=landing2d.config.applySpatialDimension(c,3);
assert(~isfield(c3.experiment,'commonObservation') && c3.experiment.sensor.cameraPitchOffset==0 ...
    && abs(c3.experiment.sensor.fov-deg2rad(50))<1e-12 && c3.cameraFovDeg==50);
env3=landing2d.environment.reset(c3,5);
assert(isempty(env3.commonObservation) && isempty(env3.observationContext) ...
    && env3.physicalState.x==env3.pad.x);
% Curriculum start heights: the lowest planar start of the first training
% iteration is seen by the forward-down camera at reset; the 3D option keeps
% its downward-camera start.
[~,heights]=landing2d.rl.trainingEpisodeConfig(c,1,0);
for seed=1:5
    [~,~,low]=landing2d.environment.reset(c,seed,struct('scenarioHeightRange',heights([1,1])));
    assert(low.commonObservation.ugv.estimateInitialized);
end
assert(isequal(c3.rl.initialHeightRange,[0.025,1.00]) && c3.rl.curriculumStartHeight==0.05);
% Planar performance curriculum: promotion after 3 windows at >= 30% current-
% level landings, demotion after 2 consecutive windows below 10% (a window in
% between resets the count); 3D keeps 10% promotion without demotion.
assert(c.rl.curriculumLandingThreshold==0.30 && c3.rl.curriculumLandingThreshold==0.10 ...
    && ~isfield(c3.rl,'curriculumDemotionThreshold'));
level=0.5; streak=0;
for rate=[0.3,0.3,0.3]
    [level,streak]=landing2d.rl.advanceCurriculumLevel(c.rl,level,rate,streak);
end
assert(abs(level-0.6)<1e-12 && streak==0);
for rate=[0.05,0.2,0.05,0.05]
    [level,streak]=landing2d.rl.advanceCurriculumLevel(c.rl,level,rate,streak);
end
assert(abs(level-0.5)<1e-12 && streak==0);
level3=0.5; streak3=0;
for rate=[0.05,0.05,0.05]
    [level3,streak3]=landing2d.rl.advanceCurriculumLevel(c3.rl,level3,rate,streak3);
end
assert(level3==0.5 && streak3==0);
% Descent-prefix curriculum (planar training only): the reference driver flies
% down to the handover height; the policy's first decision starts there with
% an initialized estimate and an engaged final-descent latch, and the prefix
% decisions are not policy transitions. The 3D option has no prefix fields and
% no separate training-episode stream (planar only).
planarOnly={'descentPrefixProbability','descentPrefixMinProbability', ...
    'descentPrefixMaxTimeRange','episodeStreamSeedOffset'};
assert(all(isfield(c.rl,planarOnly)) && ~any(isfield(c3.rl,planarOnly)));
[episode,heights]=landing2d.rl.trainingEpisodeConfig(c,1,0);
agent=landing2d.rl.agentInit(c.rl,RandStream('threefry','Seed',4),c.graphState);
[result,traj]=landing2d.rl.rolloutEpisodeV2(agent,episode,11,struct('deterministic',true, ...
    'scenarioHeightRange',heights,'maxDecisions',3, ...
    'descentPrefix',struct('handoverHeight',0.2,'maxTime',10)));
ageIndex=strcmp(c.experiment.observationSchema.names,'ugv_visionAge');
assert(result.prefixDecisions>0 && traj.count<=3 && result.time(1)>0 ...
    && result.zDrone(1)-c.experiment.scenario.padHeight<=0.2 ...
    && traj.observation(ageIndex,1)<1 && ~traj.landingInhibited(1));
[plain,plainTraj]=landing2d.rl.rolloutEpisodeV2(agent,episode,11,struct('deterministic',true, ...
    'scenarioHeightRange',heights,'maxDecisions',3));
assert(plain.prefixDecisions==0 && plain.time(1)==0 && plainTraj.count==3);
end

function checkRelationShuffle()
% Fixed edge-relation shuffle: same nodes/src/dst/counts/per-relation counts,
% self edges protected, never the canonical assignment or its supports<->
% inhibits renaming, reproducible per graph seed, distinct hashes, identical
% initial weights, the stored graph used from pretraining through PPO and
% inference, and checkpoints that cannot be swapped between graphs.
base=baseConfig();
onto=landing2d.config.applyMethod(base,'onto_rgat_ppo');
[paramsO,specO]=landing2d.graphstate.encoderInit(onto.graphState, ...
    onto.rl.observationDim,RandStream('threefry','Seed',1));
canonical=specO.T.rel; selfId=find(strcmp(specO.schema.relationNames,'self'));
counts=@(rel)accumarray(rel(:),1,[specO.schema.nRelations,1]);
hashes=strings(1,3);
for g=1:3
    sh=landing2d.config.applyMethod(base,'shuffled_rgat_ppo',1,g);
    [paramsS,specS]=landing2d.graphstate.encoderInit(sh.graphState, ...
        sh.rl.observationDim,RandStream('threefry','Seed',1));
    rel=specS.T.rel;
    assert(isequal(specS.T.src,specO.T.src) && isequal(specS.T.dst,specO.T.dst) ...
        && isequal(specS.schema.nodeNames,specO.schema.nodeNames) ...
        && isequal(counts(rel),counts(canonical)) && all(rel(canonical==selfId)==selfId));
    assert(~isequal(rel,canonical));
    assert(isequal(paramsS,paramsO) && ~strcmp(specS.graph.hash,specO.graph.hash));
    [~,again]=landing2d.graphstate.encoderInit(sh.graphState,sh.rl.observationDim, ...
        RandStream('threefry','Seed',2));
    assert(isequal(again.T.rel,rel) && strcmp(again.graph.hash,specS.graph.hash));
    hashes(g)=string(specS.graph.hash);
end
assert(numel(unique(hashes))==3);
schema=landing2d.graphstate.contextSchema('context_rgat',2,'commonObservation');
T=landing2d.rgat.topology(schema);
for g=4:60
    gs=struct('relationPerturbation',struct('type','edge_relation_shuffle','graphSeed',g));
    [~,Tg]=landing2d.rgat.applyRelationPerturbation(schema,T,gs);
    assert(~isequal(Tg.rel,canonical));
end
% The typed graph changes the encoder computation for the same input.
sh=landing2d.config.applyMethod(base,'shuffled_rgat_ppo',1,1);
[paramsS,specS]=landing2d.graphstate.encoderInit(sh.graphState,sh.rl.observationDim, ...
    RandStream('threefry','Seed',1));
env=landing2d.environment.reset(onto,9);
state=landing2d.graphstate.environmentGraph(env,onto);
if isfield(paramsO,'Wg')
    paramsO.Wg=0.1*ones(size(paramsO.Wg)); paramsS.Wg=paramsO.Wg;
end
gO=landing2d.graphstate.encoderForward(paramsO,specO,state,'policy');
gS=landing2d.graphstate.encoderForward(paramsS,specS,state,'policy');
assert(~isequal(gO,gS));
% Pretraining and PPO keep the configured graph; checkpoints are bound to it.
sh.graphState.pretrain.episodes=1; sh.graphState.pretrain.maxDecisions=5;
sh.graphState.pretrain.epochs=1; sh.graphState.pretrain.batchSize=16;
sh.rl.ppoIterations=1; sh.rl.episodesPerIteration=1; sh.rl.ppoEpochs=1;
sh.rl.miniBatch=64; sh.rl.evaluateEvery=1; sh.rl.valueWarmup=0;
sh.rl.parallelEpisodes=false; sh.rl.verbose=false;
sh.experiment.validationEpisodeCount=1; sh.showLiveDashboard=false;
trained=landing2d.rl.trainAgent(sh,@landing2d.rl.ppoTrain);
assert(strcmp(trained.encoderSpec.graph.hash,specS.graph.hash) ...
    && isequal(trained.encoderSpec.T.rel,specS.T.rel));
landing2d.rl.verifyCheckpointGraph(trained,sh);
assertThrows(@()landing2d.rl.verifyCheckpointGraph(trained,onto),'landing2d:CheckpointGraph');
run=landing2d.rl.runIdentity(trained,sh);
assert(strcmp(run.MethodId,'shuffled_rgat_ppo') && run.GraphSeed==1 ...
    && strcmp(run.GraphHash,specS.graph.hash));
end

function checkProbeReplay()
% Time-indexed sensor noise shared by every policy, the observation-error
% scale, the exogenous manifest, fixed-probe replay (same reachable states and
% causal measurement histories, errors applied at the measurement stage,
% context changes separated), probe actions without feedback, and the
% closed-loop command log (pre-tanh mean, requested, applied per physics step,
% supervisor reasons, actual acceleration as separate evaluation truth).
c=baseConfig(); co=c.experiment.commonObservation; sensor=c.experiment.sensor;
% Consistency settings are evaluation-only: outside the task fingerprint and
% the training signature.
alt=c; alt.consistency.noiseScales=[0,1,3]; alt.consistency.probe.stride=7;
assert(strcmp(landing2d.environment.taskFingerprint(alt),landing2d.environment.taskFingerprint(c)) ...
    && isequal(landing2d.rl.trainingSignature(alt),landing2d.rl.trainingSignature(c)));
% Noise tables depend only on the seed and the scale; a decision's marker
% noise is the table entry whatever the detection history or policy was.
[envA,~,infoA]=landing2d.environment.reset(c,7);
[envB,~]=landing2d.environment.reset(c,7);
assert(isequal(envA.noise,envB.noise) && strcmp(envA.noise.indexing,'time_indexed_v1') ...
    && infoA.provenance.markerNoiseSeed==envA.noise.seeds.marker);
for k=1:3
    envA=landing2d.environment.step(envA,[0.8;-0.5]);
    envB=landing2d.environment.step(envB,[-0.8;0.6]);
end
assert(isequal(envA.noise,envB.noise) && envA.stepCount==3);
frame=struct('dropout',false,'frameCaptured',true);
noiseFree=co; noiseFree.detector.pixelNoiseStd=0;
state=envA.initialPhysicalState; pad=infoA.pad;
block=envA.noise.marker(:,:,:,1);
exact=landing2d.sensing.detectMarkers(state,pad,0,sensor,noiseFree,[],frame);
noisy=landing2d.sensing.detectMarkers(state,pad,0,sensor,co,block,frame);
[common,ia,ib]=intersect(exact.ids,noisy.ids);
assert(~isempty(common));
for j=1:numel(common)
    slot=find(co.pad.markerIds==common(j));
    delta=reshape(noisy.corners(ib(j),:,:)-exact.corners(ia(j),:,:),4,2)';
    assert(max(abs(delta-co.detector.pixelNoiseStd*block(:,:,slot)),[],'all')<1e-9);
end
% Detection is decided on the noisy observed corners, which stay inside the
% image border: a corner pushed out of the image drops only that marker.
W=co.camera.imageSize(1); H=co.camera.imageSize(2); b=co.detector.borderPixels;
assert(all(noisy.corners(:,:,1)>=b & noisy.corners(:,:,1)<=W-1-b ...
    & noisy.corners(:,:,2)>=b & noisy.corners(:,:,2)<=H-1-b,'all'));
pushed=block; first=find(co.pad.markerIds==noisy.ids(1));
pushed(1,1,first)=W/co.detector.pixelNoiseStd;
dropped=landing2d.sensing.detectMarkers(state,pad,0,sensor,co,pushed,frame);
assert(isequal(reshape(dropped.ids,1,[]),reshape(noisy.ids(2:end),1,[])));
% Observation-error scale: same standard normals times the scale (covariance
% scale^2); scale 0 is noise free; the 3D option keeps its sequential stream.
zero=landing2d.environment.reset(c,7,struct('sensorNoiseScale',0));
double2=landing2d.environment.reset(c,7,struct('sensorNoiseScale',2));
assert(~any(zero.noise.marker(:)) && ~any(zero.noise.navigation(:)) ...
    && isequal(double2.noise.marker,2*envB.noise.marker) ...
    && isequal(double2.noise.tracker,2*envB.noise.tracker));
assertThrows(@()landing2d.environment.reset(landing2d.config.applySpatialDimension(c,3),5, ...
    struct('sensorNoiseScale',2)),'landing2d:NoiseScale');
% Exogenous manifest: shared by every method for one seed and scale.
m7=landing2d.environment.exogenousManifest(landing2d.environment.reset(c,7));
assert(strcmp(m7.hash,landing2d.environment.exogenousManifest( ...
        landing2d.environment.reset(c,7)).hash) ...
    && ~strcmp(m7.hash,landing2d.environment.exogenousManifest(zero).hash) ...
    && ~strcmp(m7.hash,landing2d.environment.exogenousManifest( ...
        landing2d.environment.reset(c,8)).hash));
assertThrows(@()landing2d.environment.exogenousManifest(envA),'landing2d:ExogenousManifest');
% Replay: the nominal sensing replay of a reference trajectory reproduces the
% environment's observations and decision context bit for bit; the noise
% scale changes measurements, not the physical states.
record=landing2d.probe.recordReference(c,2001,struct('maxDecisions',40));
nominal=landing2d.probe.replaySensing(record,c,1);
clean=landing2d.probe.replaySensing(record,c,0);
assert(record.decisions==40 && isequal(nominal.observation,record.observation) ...
    && isequal(nominal.flags.landingInhibited,record.landingInhibited) ...
    && isequal(nominal.flags.abortRequested,record.abortRequested) ...
    && isequal(nominal.flags.finalDescentActive,record.finalDescentActive));
[~,x0]=landing2d.environment.reset(c,2001,struct('sensorNoiseScale',0));
assert(isequal(clean.observation(:,1),x0) ...
    && ~isequal(clean.observation,nominal.observation));
% Probe bank: policy input separated from context and truth; the reference
% scale is its own context; an extreme scale changes PnP acceptance and the
% decision context, and those probes are separated from same-context ones.
% Degenerate corner sets at the extreme scale are rejected without solver
% warnings (landing2d.observation.estimatePadPose).
lastwarn('');
bank=landing2d.probe.buildBank(c,'validation',struct('seeds',2001,'scales',[0,1,10], ...
    'stride',3));
[~,warningId]=lastwarn;
assert(~ismember(warningId,{'MATLAB:rankDeficientMatrix','MATLAB:singularMatrix', ...
    'MATLAB:nearlySingularMatrix'}));
P=bank.meta.probeCount;
assert(isequal(fieldnames(bank.policyInput)',{'vector','graph'}) ...
    && isequal(size(bank.policyInput.vector),[12,P,3]) ...
    && isequal(size(bank.policyInput.graph),[42,P,3]) && P==numel(bank.truth.drone(1,:)));
assert(all(bank.context.sameContext(:,1)) && ~all(bank.context.sameContext(:,3)) ...
    && isequal(bank.context.sameContext,bank.context.sameConfidence & bank.context.sameSafety));
assertThrows(@()landing2d.probe.buildBank(c,'train',struct('count',1)),'landing2d:ProbeSplit');
% Probe actions: deterministic, no feedback into the bank, requested =
% limits .* tanh(pre-tanh mean); recurrent policies are refused.
arms=landing2d.config.comparisonArms(c);
before=bank;
limits=landing2d.environment.actionLimits(c);
for i=1:numel(arms)
    agent=landing2d.rl.agentInit(arms(i).config.rl,RandStream('threefry','Seed',3), ...
        arms(i).config.graphState);
    out=landing2d.rl.probeActions(agent,bank,arms(i).config);
    assert(isequal(size(out.actorMean),[2,P,3]) ...
        && isequal(out.requestedAcceleration,limits.*tanh(out.actorMean)) ...
        && all(abs(out.requestedAcceleration)<=limits,'all'));
end
assert(isequaln(before,bank));   % NaN: estimate error before initialization
agent.encoderSpec.recurrent=true;
assertThrows(@()landing2d.rl.probeActions(agent,bank,arms(end).config),'landing2d:RecurrentProbe');
% Command log: sections kept apart, physics steps sum to the decision time,
% the interval mean is the dt-weighted applied command, supervisor flags and
% reasons match the applied-vs-requested difference, actual acceleration is
% logged as truth and differs from the command (lagged dynamics).
arm=arms(1).config;
agent=landing2d.rl.agentInit(arm.rl,RandStream('threefry','Seed',3),arm.graphState);
[result,traj]=landing2d.rl.rolloutEpisodeV2(agent,arm,7,struct('deterministic',true, ...
    'maxDecisions',15,'commandLog',true,'run',landing2d.rl.runIdentity(agent,arm)));
L=result.commandLog;
assert(isequal(fieldnames(L)',{'identity','policy','decision','physics','truth', ...
    'exogenous','outcome','labels'}) && isequal(fieldnames(L.policy)',{'time', ...
    'observation','actorMean','command','normalizedAction','requestedAcceleration'}));
assert(strcmp(L.exogenous.hash,m7.hash) && strcmp(L.identity.run.MethodId,'ppo') ...
    && isequal(L.policy.actorMean,traj.command) && isequal(L.policy.time,traj.time) ...
    && isequal(L.policy.requestedAcceleration,limits.*tanh(traj.command)));
assert(abs(sum(L.physics.dt)-sum(L.decision.dt))<1e-12 && issorted(L.physics.time));
for k=1:L.outcome.decisions
    in=L.physics.decisionIndex==k;
    dt=L.physics.dt(in);
    applied=L.physics.appliedAcceleration(:,in);
    assert(norm(applied*dt'/sum(dt)-L.decision.appliedAccelerationIntervalMean(:,k))<1e-12);
    differs=any(abs(applied-L.policy.requestedAcceleration(:,k))>1e-12,1);
    assert(isequal(differs,L.physics.supervisorIntervened(in)) ...
        && L.decision.supervisorIntervened(k)==any(differs));
    codes=unique(L.physics.supervisorReasonCode(in));
    codes=codes(codes>0);
    named=L.physics.reasonNames(codes);
    assert(isequal(sort(L.decision.supervisorReasons{k}(:)'),sort(named(:)')));
end
assert(isequal(size(L.truth.actualAcceleration),size(L.physics.appliedAcceleration)) ...
    && ~isequal(L.truth.actualAcceleration,L.physics.appliedAcceleration));
plain=landing2d.rl.rolloutEpisodeV2(agent,arm,7,struct('deterministic',true,'maxDecisions',3));
assert(isempty(plain.commandLog));
end

function checkBehaviorValidity()
% Independent validity judge: a set of admissible commands from a short
% fixed-command prediction with the existing dynamics, context-dependent task
% rules without a forced direction, non-applicability with a reason; C_valid,
% D_obs, D_seed and J_policy formulas and aggregation; validation-only freezing.
c=baseConfig(); limits=landing2d.environment.actionLimits(c);
d=c.experiment.dynamics; padZ=c.experiment.scenario.padHeight;
off=c.experiment.sensor.cameraPitchOffset;
config=struct('c',c,'horizon',0.5,'kappa',0.5,'gridPoints',5);
flags=@(fresh,inhibited,abort)struct('visionUpdated',fresh,'estimateInitialized',true, ...
    'visionAge',double(~fresh),'landingInhibited',inhibited,'abortRequested',abort, ...
    'finalDescentActive',false);
probe=@(h,vz,ctx)struct('drone',[h*tan(off);padZ+h;2;vz;0;0;d.mass*d.gravity], ...
    'pad',[0;padZ;2;0],'context',ctx,'admissible',[]);
judge=@(p,a)landing2d.metrics.behaviorValidity(p,a,config);
% Backup recovery overrides the policy: not applicable, with the reason.
out=judge(probe(5,0,flags(true,false,true)),[0;0]);
assert(~out.applicable && isequal(out.reason_codes,{'supervisor_override'}));
% Authorized approach, recent vision, steady tracking: a set, not one command.
high=probe(5,0,flags(true,false,false));
adm=landing2d.metrics.admissibleActions(high,config);
assert(adm.anySafe && adm.admissibleFraction>0.05 && adm.admissibleFraction<0.95 ...
    && adm.rules.horizontalActive && adm.rules.verticalActive);
climb=judge(high,[0;limits(2)]); forward=judge(high,[limits(1);0]);
assert(climb.applicable && ~climb.valid && ismember('approach_regression',climb.reason_codes));
assert(~forward.valid && ismember('tracking_regression',forward.reason_codes));
assert(judge(high,[0;-0.5]).valid && strcmp(climb.context_id,'fresh/high/authorized') ...
    && strcmp(climb.context_id,forward.context_id));
% Landing inhibited with stale vision at height: holding and climbing are both
% admissible (no direction forced); close to the pad and descending fast,
% continuing the descent is not, braking up is.
inhibited=probe(5,0,flags(false,true,false));
assert(judge(inhibited,[0;limits(2)]).valid && judge(inhibited,[0;0]).valid);
low=probe(0.4,-0.8,flags(false,true,false));
dive=judge(low,[0;-limits(2)]);
assert(dive.applicable && ~dive.valid && any(ismember({'braking_margin', ...
    'unauthorized_contact','unsafe_contact'},dive.reason_codes)) ...
    && judge(low,[0;limits(2)]).valid);
% Bank metrics: a wrong constant command is not rated good because its
% D_obs is 0; D_obs follows the normalized-command formula.
bank=landing2d.probe.buildBank(c,'validation',struct('seeds',2001,'scales',[0,1],'stride',4));
grid=landing2d.consistency.validityGrid(bank,c,struct('horizons',0.5,'kappas',0.5));
assertThrows(@()landing2d.consistency.calibrateValidity( ...
    landing2d.probe.buildBank(c,'test',struct('count',1,'stride',40)),grid,c), ...
    'landing2d:ValidityCalibration');
frozen=struct('schemaVersion','validity_frozen_v1','horizon',0.5,'kappa',0.5, ...
    'gridPoints',grid.gridPoints,'hash','selftest');
P=bank.meta.probeCount;
constant=@(a)struct('run',struct(),'requestedAcceleration',repmat(a,1,P,2));
c.consistency.validity.minimumContextSamples=1;
score=@(actions)landing2d.consistency.probeMetrics(bank,actions, ...
    landing2d.consistency.probeValidity(bank,actions,frozen,grid,c),c);
climbing=score(constant([0;limits(2)]));
driver=struct('run',struct(),'requestedAcceleration',repmat(bank.truth.driverMeanAcceleration,1,1,2));
reference=score(driver);
assert(all(climbing.D_obs_mean==0) && climbing.C_valid(2)<reference.C_valid(2));
perturbed=driver; perturbed.requestedAcceleration(:,:,2)=perturbed.requestedAcceleration(:,:,2)+[0.5;0];
m=score(perturbed); u=@(a)(a+limits)./(2*limits);
expected=norm(u(perturbed.requestedAcceleration(:,1,2))-u(driver.requestedAcceleration(:,1,1)))/sqrt(2);
same=bank.context.sameContext(:,2);
distance=vecnorm(u(perturbed.requestedAcceleration(:,:,2))-u(driver.requestedAcceleration(:,:,1)),2,1)/sqrt(2);
assert(abs(distance(1)-expected)<1e-12 && abs(m.D_obs_mean(2)-mean(distance(same)))<1e-12);
% D_seed: NaN with one seed, 0 for identical seeds, jackknife needs >= 3 seeds.
one=landing2d.consistency.seedDivergence({driver},bank);
two=landing2d.consistency.seedDivergence({driver,driver},bank);
three=landing2d.consistency.seedDivergence({driver,driver,perturbed},bank);
assert(all(isnan(one.D_seed)) && all(two.D_seed==0) && all(isnan(two.jackknifeSE)) ...
    && three.D_seed(2)>0 && isfinite(three.jackknifeSE(2)));
% J_policy: rates only inside steady windows from the exogenous schedule;
% separate windows are not joined.
t=0:0.1:12;
log=struct('policy',struct('time',t,'requestedAcceleration',[0.2*t;zeros(size(t))]), ...
    'physics',struct('time',t+0.1,'dt',0.1*ones(size(t)), ...
        'appliedAcceleration',[0.2*t;zeros(size(t))]), ...
    'truth',struct('time',[t,12.1]), ...
    'exogenous',struct('scenario',struct('T1',4,'T2',2), ...
        'sensorEvents',struct('dropoutStart',Inf,'dropoutEnd',-Inf,'pitchStart',Inf,'pitchEnd',-Inf)));
jerk=landing2d.consistency.policyJerk(log,c.consistency.jerk);
assert(abs(jerk.J_policy-0.2)<1e-9 && isequal(size(jerk.windows),[2,2]) ...
    && abs(jerk.windows(1,2)-4)<1e-12 && abs(jerk.windows(2,1)-8)<1e-12 ...
    && jerk.policySamples>=60 && abs(jerk.policyWeight-0.1*jerk.policySamples)<1e-9);
end

function c=baseConfig()
c=landing2d.config.primaryConfig(landing2d.orchestration.projectRoot());
end

function info=mockGuardInfo(agent,fullNorm)
scale=norm(agent.policy.encoder.Wg,'fro')/fullNorm;
info=struct('landingRate',.70,'unsafeRate',.10, ...
    'safeAbortRate',.15,'timeoutRate',.05, ...
    'meanReturn',10-.1*scale,'selectionScore',500-.1*scale, ...
    'meanAbsRelationResidual',[.01;.02]*scale);
if scale>.25+1e-12, info.unsafeRate=.11; end
end

function assertThrows(fun,id)
threw=false;
try, fun(); catch err, threw=strcmp(err.identifier,id); end
assert(threw,'Expected error %s.',id);
end
