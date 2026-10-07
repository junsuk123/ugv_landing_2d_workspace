function report = selfTest()
% SELFTEST  Compact final-contract regression suite.
checks={@checkContract,@checkCausalBoundary,@checkScenarioDynamics, ...
    @checkTermination,@checkContextGraph,@checkPpoSmoke, ...
    @checkRelationGuard,@checkPaperScenarios,@checkSpatial3d};
names={"contract","causal-boundary","scenario-dynamics","termination", ...
    "context-graph","ppo-smoke","relation-guard","paper-scenarios", ...
    "spatial-3d"};
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
c=baseConfig();
landing2d.config.validateConfig(c);
assert(c.rl.actionDim==2 && c.rl.observationDim==26);
assert(c.experiment.validationEpisodeCount==100 ...
    && c.experiment.testEpisodeCount==100);
assert(isempty(intersect(c.experiment.manifest.validationSeeds, ...
    c.experiment.manifest.testSeeds)));
modes={'baseline','context_flat','context_rgat'};
fingerprints=strings(size(modes));
for i=1:numel(modes)
    arm=landing2d.graphstate.applyStateRepresentation(c,modes{i});
    fingerprints(i)=string(landing2d.environment.taskFingerprint(arm));
end
assert(all(fingerprints==fingerprints(1)));
end

function checkCausalBoundary()
c=baseConfig();
[env,observation,info]=landing2d.environment.reset(c,5); %#ok<ASGLU>
assert(numel(observation)==26 && info.packet.trackInitialized);
for name={'phase','truePadAcceleration','terminalReason','futurePadX'}
    assert(~isfield(info.packet,name{1}));
end
arm=landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
bad=info.packet; bad.futurePadX=0;
assertThrows(@()landing2d.graphstate.contextGraph(bad,arm), ...
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
assert(strcmp(blocked.reason,'UNAUTHORIZED_CONTACT'));
end

function checkContextGraph()
c=landing2d.graphstate.applyStateRepresentation(baseConfig(),'context_rgat');
[env]=landing2d.environment.reset(c,9);
[state,detail]=landing2d.graphstate.contextGraph(env.packet,c);
schema=detail.schema;
assert(schema.nNodes==9 && schema.nRelations==5 && numel(schema.src)==26);
assert(numel(state)==schema.inDim*schema.nNodes);
assert(all(sum(schema.groupMatrix>0,1)==1));
flat=landing2d.graphstate.applyStateRepresentation(c,'context_flat');
assert(isequal(state,landing2d.graphstate.contextGraph(env.packet,flat)));
end

function checkPpoSmoke()
c=landing2d.graphstate.applyStateRepresentation(baseConfig(),'context_rgat');
c.rl.ppoIterations=1; c.rl.episodesPerIteration=1; c.rl.ppoEpochs=1;
c.rl.miniBatch=64; c.rl.evaluateEvery=1; c.rl.valueWarmup=0;
c.rl.parallelEpisodes=false; c.rl.verbose=false;
c.experiment.validationEpisodeCount=1;
rs=RandStream('threefry','Seed',1234);
agent=landing2d.rl.agentInit(c.rl,rs,c.graphState);
[~,history]=landing2d.rl.ppoTrain(agent,c,rs);
assert(numel(history)>=2 && all(isfinite([history.score])));
end

function checkRelationGuard()
c=landing2d.graphstate.applyStateRepresentation(baseConfig(),'context_rgat');
rs=RandStream('threefry','Seed',77);
anchor=landing2d.rl.agentInit(c.rl,rs,c.graphState); candidate=anchor;
candidate.policy.encoder.Wg=0.1*randn(rs,size(candidate.policy.encoder.Wg));
candidate.value.encoder.Wg=0.1*randn(rs,size(candidate.value.encoder.Wg));
fullNorm=norm(candidate.policy.encoder.Wg,'fro');
opts=struct('scaleGrid',[1 .5 .25 .1], ...
    'meanReturnTolerance',.25,'selectionScoreTolerance',.25, ...
    'minResidualNorm',1e-6,'maxResidualNorm',.006, ...
    'evaluator',@(agent)mockGuardInfo(agent,fullNorm));
[selected,guard]=landing2d.rl.guardRelationalCandidate(anchor,candidate,c,opts);
assert(guard.accepted && abs(guard.selectedScale-.25)<eps);
assert(landing2d.rl.relationalPathActive(selected));
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
% absent from the planar contract.
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
planar=landing2d.environment.updateDecisionContext(landing2d.environment.initialStatus(), ...
    track,10,c2,low);
assert(~isfield(planar,'finalDescentActive'));
assert(c.experiment.reward.actionChangeWeight>0 && ~isfield(c2.experiment.reward,'actionChangeWeight'));
[env,~,~,~,~,stepInfo]=landing2d.environment.step(env,tanh(u));
assert(numel(stepInfo.appliedAcceleration)==3 && isfield(env.physicalState,'roll'));
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
