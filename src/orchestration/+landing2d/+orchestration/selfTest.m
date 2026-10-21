function report = selfTest()
% SELFTEST  Contract regression suite of relational_policy_v1 (14 checks).
checks={@checkContract,@checkSeeds,@checkScenarioFamily,@checkFactorialCases, ...
    @checkCausalBoundary,@checkScenarioDynamics,@checkTermination, ...
    @checkContextGraph,@checkPpoSmoke,@checkRelationAttention, ...
    @checkCommonObservation,@checkRelationShuffle,@checkProbeReplay, ...
    @checkEvaluation};
names={"contract","seeds","scenario-family","factorial-cases","causal-boundary", ...
    "scenario-dynamics","termination","context-graph","ppo-smoke", ...
    "relation-attention","common-observation","relation-shuffle", ...
    "probe-replay","evaluation"};
passed=false(numel(checks),1); messages=strings(numel(checks),1);
for i=1:numel(checks)
    try
        checks{i}(); passed(i)=true; messages(i)="PASS";
    catch err
        messages(i)=string(getReport(err,'basic','hyperlinks','off'));
    end
    fprintf('  self-test [%2d/%d] %-20s %s\n', ...
        i,numel(checks),names{i},messages(i));
end
report=table(names',passed,messages, ...
    'VariableNames',{'Check','Passed','Message'});
assert(all(passed),'landing2d:SelfTestFailed', ...
    '%d contract self-test(s) failed.',sum(~passed));
end

function checkContract()
% Three methods on one task contract: 10-D common observation, the same
% reward_v5, direct policy, the same PPO budget and loss, 6,101 parameters
% each, separate checkpoints/signatures per method and seed; R-GAT arms differ
% only in the state representation (input-dependent attention).
c=baseConfig();
landing2d.config.validateConfig(c);
schema=c.experiment.observationSchema;
assert(c.rl.actionDim==2 && c.rl.observationDim==schema.dimension ...
    && schema.dimension==10 && strcmp(c.experiment.designVersion,'relational_policy_v1') ...
    && ~any(contains(schema.names,'navigation')));
r=c.experiment.reward;
assert(r.goalCameraAim && r.potentialWeight==4 && r.velocityPotentialWeight==4 ...
    && r.verticalPotentialWeight==4 && strcmp(r.goalRunningCost,'pseudo_huber_v1'));
assert(strcmp(c.rl.trainingRegime,'direct_ppo_v1') ...
    && strcmp(c.experiment.actionApplication,'direct_policy_v1') ...
    && strcmp(c.graphState.readout,'grouped_factorized') ...
    && strcmp(c.graphState.attentionMode,'input_dependent_v1') ...
    && strcmp(c.graphState.observationFeatures,'tosm7_v2') ...
    && c.rl.ppoIterations==750 && c.rl.episodesPerIteration==6);
% relational-policy-v2.0: rgat_v2 encoder and the common validation-plateau
% stop (3 validations >= 95% landing, >= 150 updates; budget 750 stays the cap).
% relational-policy-v2.1: common exploration scale initialLogStd -2.0 and the
% common validation screen (20 episodes, >= 50% landing to fly the rest).
% relational-policy-v2.2: the depth4_v1 encoder (checkRelationAttention).
% relational-policy-v2.3: 10-D o_t, tosm7_v2 features, plain PPO 48-51 / 47-50.
% relational-policy-v2.4: semantic fixed relation operators.
% relational-policy-v2.5: shared operator banks + ontology-sink readout.
% relational-policy-v2.6: only qualifiesEstimate is a reliability gate.
% relational-policy-v2.9: v2.8 semantic codebook plus a node-shared mean
% grouped-factorized readout, with no gate/operator class.
assert(strcmp(landing2d.rl.algorithmVersion(),'relational-policy-v2.9') ...
    && strcmp(c.graphState.v2Operators,'none') ...
    && strcmp(c.graphState.v2RelationParameterization,'fixed_semantic_codebook_v1') ...
    && strcmp(c.graphState.v2ReadoutParameterization,'node_shared_mean_v1') ...
    && c.rl.initialLogStd==-2.0 && c.rl.minimumLogStd==-2.5 ...
    && strcmp(c.rl.validationScreen.rule,'validation_screen_v1') ...
    && c.rl.validationScreen.episodes==20 && c.rl.validationScreen.minimumLandingRate==0.5 ...
    && strcmp(c.graphState.encoderVersion,'rgat_v2') ...
    && strcmp(c.rl.earlyStop.rule,'validation_plateau_v1') && c.rl.earlyStop.window==3 ...
    && c.rl.earlyStop.minimumLandingRate==0.95 && c.rl.earlyStop.minimumIterations==150);
row=@(it,rate)struct('iteration',it,'landingRate',rate);
h=[row(0,0),row(25,0.2),row(50,0.96),row(75,0.97),row(100,1)];
assert(~landing2d.rl.plateauReached(h,100,c.rl));                    % < 150 updates
h=[h,row(125,0.99),row(150,0.95)];
assert(landing2d.rl.plateauReached(h,150,c.rl));
h(end).landingRate=0.94; assert(~landing2d.rl.plateauReached(h,150,c.rl));
noStop=c.rl; noStop=rmfield(noStop,'earlyStop');
assert(~landing2d.rl.plateauReached([h,row(175,1),row(200,1),row(225,1)],225,noStop));
% No arm-specific loss term, input normalization or relation residual head.
assert(~isfield(c.graphState,'temporalPolicyConsistencyWeight') ...
    && ~isfield(c.rl,'inputNormalization'));
registry=landing2d.config.methodRegistry();
assert(isequal({registry.methods.id},{'ppo','onto_rgat_ppo','shuffled_rgat_ppo'}) ...
    && isequal(registry.trainSeeds.default,1:5));
% v2.3 confirmatory seeds are fresh: disjoint from every earlier seed plan.
assert(isequal(registry.trainSeeds.v23,21:30) && ~isfield(registry.trainSeeds,'v21') ...
    && ~isfield(registry.trainSeeds,'depth4') && isempty(intersect(registry.trainSeeds.v23, ...
    [registry.trainSeeds.main,registry.trainSeeds.confirmatory,registry.trainSeeds.v2, ...
    registry.trainSeeds.v21Dev,registry.trainSeeds.depth4Dev,registry.trainSeeds.v23Dev])));
% v2.4 confirmatory seeds 51-60: disjoint from every earlier seed plan.
assert(isequal(registry.trainSeeds.v24,51:60) && isempty(intersect(registry.trainSeeds.v24, ...
    [registry.trainSeeds.main,registry.trainSeeds.confirmatory,registry.trainSeeds.v2, ...
    registry.trainSeeds.v21Dev,registry.trainSeeds.depth4Dev,registry.trainSeeds.v23Dev, ...
    registry.trainSeeds.v23])));
% v2.5 development and confirmatory seeds are mutually disjoint and fresh.
earlier=[registry.trainSeeds.main,registry.trainSeeds.confirmatory,registry.trainSeeds.v2, ...
    registry.trainSeeds.v21Dev,registry.trainSeeds.depth4Dev,registry.trainSeeds.v23Dev, ...
    registry.trainSeeds.v23,registry.trainSeeds.v24];
assert(isequal(registry.trainSeeds.v25Dev,61:64) ...
    && isequal(registry.trainSeeds.v25,71:80) ...
    && isempty(intersect(registry.trainSeeds.v25Dev,earlier)) ...
    && isempty(intersect(registry.trainSeeds.v25,[earlier,registry.trainSeeds.v25Dev])));
earlier=[earlier,registry.trainSeeds.v25Dev,registry.trainSeeds.v25];
assert(isequal(registry.trainSeeds.v26Dev,81:84) ...
    && isequal(registry.trainSeeds.v26,91:100) ...
    && isempty(intersect(registry.trainSeeds.v26Dev,earlier)) ...
    && isempty(intersect(registry.trainSeeds.v26,[earlier,registry.trainSeeds.v26Dev])));
earlier=[earlier,registry.trainSeeds.v26Dev,registry.trainSeeds.v26];
assert(isequal(registry.trainSeeds.v27Dev,101:104) ...
    && isequal(registry.trainSeeds.v27,111:120) ...
    && isempty(intersect(registry.trainSeeds.v27Dev,earlier)) ...
    && isempty(intersect(registry.trainSeeds.v27,[earlier,registry.trainSeeds.v27Dev])));
earlier=[earlier,registry.trainSeeds.v27Dev,registry.trainSeeds.v27];
assert(isequal(registry.trainSeeds.v28Dev,121:124) ...
    && isequal(registry.trainSeeds.v28,131:140) ...
    && isempty(intersect(registry.trainSeeds.v28Dev,earlier)) ...
    && isempty(intersect(registry.trainSeeds.v28,[earlier,registry.trainSeeds.v28Dev])));
earlier=[earlier,registry.trainSeeds.v28Dev,registry.trainSeeds.v28];
assert(isequal(registry.trainSeeds.v29Dev,141:144) ...
    && isequal(registry.trainSeeds.v29,151:160) ...
    && isempty(intersect(registry.trainSeeds.v29Dev,earlier)) ...
    && isempty(intersect(registry.trainSeeds.v29,[earlier,registry.trainSeeds.v29Dev])));
arms=landing2d.config.comparisonArms(c);
assert(numel(arms)==3 && isequal([arms.trainSeed],[1 1 1]) && arms(3).graphSeed==1 ...
    && isnan(arms(1).graphSeed));
files=strings(1,3); prints=strings(1,3); signatures=cell(1,3);
for i=1:3
    files(i)=string(arms(i).config.rl.policyFile);
    prints(i)=string(landing2d.environment.taskFingerprint(arms(i).config));
    signatures{i}=landing2d.rl.trainingSignature(arms(i).config);
    agent=landing2d.rl.agentInit(arms(i).config.rl,RandStream('threefry','Seed',5), ...
        arms(i).config.graphState);
    assert(landing2d.rl.profileAgent(agent,arms(i).config,1,1).parameterCount==6101);
end
assert(numel(unique(files))==3 && all(prints==prints(1)) ...
    && ~isequal(signatures{2},signatures{3}));
% Shuffled graph seed follows the training seed; seeds give distinct runs.
second=landing2d.config.comparisonArms(c,struct('trainSeed',2));
assert(second(3).graphSeed==2 && second(1).config.rl.seed==arms(1).config.rl.seed+1 ...
    && ~any(ismember(string(arrayfun(@(a)a.config.rl.policyFile,second, ...
    'UniformOutput',false)),files)));
assert(~landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(second(1).config), ...
    arms(1).config));
% Execution-only settings do not invalidate a checkpoint; evaluation settings
% are outside the signature and the task fingerprint.
worker=arms(1).config; worker.rl.parallelWorkers=3; worker.rl.parallelEpisodes=false;
worker.evaluation.factorial.replicates=3;
assert(landing2d.rl.signatureMatches(landing2d.rl.trainingSignature(worker),arms(1).config) ...
    && strcmp(landing2d.environment.taskFingerprint(worker),prints(1)));
end

function checkSeeds()
% Disjoint seed namespace below the 1e6 stream spacing; PPO episodes from the
% reserved training range only; fixed-case replicates inside their range.
c=baseConfig(); m=c.experiment.manifest;
splits={m.trainSeeds,m.validationSeeds,m.testSeeds,m.stressSeeds};
for i=1:numel(splits)
    for j=i+1:numel(splits), assert(isempty(intersect(splits{i},splits{j}))); end
end
allSplits=[splits{:}];
assert(max(allSplits)<m.fixedCaseSeedRange(1) ...
    && m.fixedCaseSeedRange(2)<m.trainEpisodeSeedRange(1) ...
    && m.trainEpisodeSeedRange(2)<1e6);
bad=c; bad.experiment.manifest.trainEpisodeSeedRange=[3001,999999];
assertThrows(@()landing2d.config.validateConfig(bad),'landing2d:ManifestOverlap');
rs=RandStream('threefry','Seed',c.rl.seed+c.rl.episodeStreamSeedOffset);
draws=randi(rs,m.trainEpisodeSeedRange,5000,1);
assert(all(draws>=m.trainEpisodeSeedRange(1) & draws<=m.trainEpisodeSeedRange(2)) ...
    && ~any(ismember(draws,allSplits)));
seeds=landing2d.evaluation.replicateSeeds(c,c.evaluation.factorial.seed,400);
assert(seeds(1)==43001 && all(diff(seeds)==1));
assertThrows(@()landing2d.evaluation.replicateSeeds(c,3001,2),'landing2d:ReplicateSeedRange');
end

function checkScenarioFamily()
% 2 x 2 training family: UGV CV/CA and marker clean/dropout drawn
% independently (about 25% per cell), dropout start not tied to T1, values in
% range; initial relative speed/position offsets applied at reset with the pad
% in view.
c=baseConfig(); s=c.experiment.scenario; sensor=c.experiment.sensor;
n=800; motion=false(1,n); dropped=false(1,n); start=nan(1,n); T1=zeros(1,n);
for k=1:n
    base=s.baseSeed+k;
    p=landing2d.scenario.sampleParameters(s,base+c.experiment.randomStreams.scenarioOffset);
    e=landing2d.sensing.sampleEvents(sensor,p,RandStream('threefry', ...
        'Seed',base+c.experiment.randomStreams.sensorOffset));
    motion(k)=p.a2>0; dropped(k)=isfinite(e.dropoutStart); T1(k)=p.T1;
    if motion(k), assert(p.a2>=s.a2Range(1) && p.a2<=s.a2Range(2)); end
    assert(p.T1>=s.T1Range(1) && p.T1<=s.T1Range(2) && p.v1>=s.v1Range(1) ...
        && p.v1<=s.v1Range(2) && abs(p.initialSpeedOffset)<=s.initialSpeedOffsetRange(2));
    if dropped(k)
        start(k)=e.dropoutStart; d=e.dropoutEnd-e.dropoutStart;
        assert(ismember(e.dropoutKind,{'mild','severe'}) && d>=0.2-1e-12 && d<=1.0+1e-12);
    end
end
cells=[mean(~motion&~dropped),mean(~motion&dropped),mean(motion&~dropped),mean(motion&dropped)];
assert(all(abs(cells-0.25)<0.05),'Cell frequencies %s are not balanced.',mat2str(cells,3));
r=corrcoef(T1(dropped),start(dropped));
assert(abs(r(1,2))<0.15,'Dropout start is correlated with T1 (r = %.2f).',r(1,2));
for seed=1:10
    [env,~,info]=landing2d.environment.reset(c,seed);
    sc=env.scenario; pad=info.pad;
    aim=pad.x+sc.height*tan(sensor.cameraPitchOffset);
    assert(abs(env.physicalState.vx-(pad.vx+sc.initialSpeedOffset))<1e-12 ...
        && abs(env.physicalState.x-(aim+sc.initialPositionOffsetApplied))<1e-12 ...
        && landing2d.sensing.projectPad(env.physicalState,pad,sensor).visible);
end
end

function checkFactorialCases()
% S1-S4: one seed, deadline and window; each pair changes one factor; values
% inside the training ranges; the S2/S4 dropout starts at the CA onset.
c=baseConfig(); S=landing2d.evaluation.factorialCases(c); s=c.experiment.scenario;
assert(isequal({S.id},{'S1','S2','S3','S4'}) && isequal([S.motion],[0 0 1 1]) ...
    && isequal([S.observation],[0 1 0 1]) && numel(unique([S.seed]))==1);
assert(isequal(S(1).eventWindow,S(2).eventWindow,S(3).eventWindow,S(4).eventWindow));
deadlines=arrayfun(@(x)x.scenario.deadline,S);
assert(all(deadlines==deadlines(1)));
motionFields={'a2','v3','L2','L3'};
assert(isequaln(S(1).scenario,S(2).scenario) && isequaln(S(3).scenario,S(4).scenario) ...
    && isequaln(rmfield(S(1).scenario,motionFields),rmfield(S(3).scenario,motionFields)));
assert(isequal(S(1).sensorEvents,S(3).sensorEvents) && isequal(S(2).sensorEvents,S(4).sensorEvents) ...
    && S(4).sensorEvents.dropoutStart==S(4).scenario.T1 && strcmp(S(4).sensorEvents.dropoutKind,'severe'));
a=S(3).scenario;
assert(a.a2>=s.a2Range(1) && a.a2<=s.a2Range(2) && a.T1>=s.T1Range(1) && a.T1<=s.T1Range(2) ...
    && a.T2>=s.T2Range(1) && a.T2<=s.T2Range(2) && a.height>=s.heightRange(1));
for i=1:4
    [env,~,info]=landing2d.environment.reset(c,S(i).seed,struct('scenario',S(i).scenario, ...
        'sensorEvents',S(i).sensorEvents));
    assert(isequal(env.sensorEvents.dropoutStart,S(i).sensorEvents.dropoutStart) ...
        && info.commonObservation.ugv.estimateInitialized);
end
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
% Planar graph: built from the common observation only (no packet); node
% features do not depend on the relation assignment (canonical = shuffled).
c=landing2d.config.applyMethod(baseConfig(),'onto_rgat_ppo');
env=landing2d.environment.reset(c,9);
noPacket=env; noPacket.packet=[];
[state,detail]=landing2d.graphstate.environmentGraph(noPacket,c);
schema=detail.schema;
% Reduced TOSM ontology: 7 nodes, 4 semantic relations + self, 13 + 7 edges.
assert(schema.nNodes==7 && schema.nRelations==5 && numel(schema.src)==20 ...
    && size(schema.edgeTable,1)==13 && schema.inDim==6 ...
    && isequal(schema.nodeNames,{'VisionQuality','PadVelocity','RelativePosition', ...
        'RelativeVelocity','DroneMotion','ViewMargin','LandingCondition'}) ...
    && isequal(schema.relationNames,{'qualifiesEstimate','informsMotion', ...
        'affectsVisibility','conditionsLanding','self'}) ...
    && isequal(accumarray(schema.rel(:),1)',[3,3,2,5,7]) ...
    && strcmp(schema.variant,'tosm7_rgat_v2') ...
    && strcmp(schema.knowledgeModel,'TOSM') ...
    && strcmp(schema.tosm.version,'tosm_landing_v2_reduced') ...
    && isequal(schema.tosm.perspectives,{'Symbolic','Explicit','Implicit'}) ...
    && isequal(schema.tosm.nodePerspective(6:7),{'Implicit','Implicit'}) ...
    && isempty(schema.actionNodes) ...
    && numel(schema.edgePurpose)==numel(schema.src));
assert(numel(state)==schema.inDim*schema.nNodes ...
    && all(abs(state)<=1));
nodeFeatures=reshape(state,schema.inDim,schema.nNodes);
% LandingCondition holds the five soft-bounded touchdown ratios.
assert(isfield(detail,'semanticEvidence') ...
    && max(abs(nodeFeatures(1:5,7)-detail.semanticEvidence.landingCondition(:)))<1e-12 ...
    && all(nodeFeatures(1:5,7)>=0 & nodeFeatures(1:5,7)<1));
assert(isequal(state,landing2d.graphstate.environmentGraph(noPacket,c, ...
    detail.observationVector)));
[~,spec]=landing2d.graphstate.encoderInit(c.graphState,c.rl.observationDim, ...
    RandStream('threefry','Seed',17));
assert(strcmp(spec.schema.variant,'tosm7_rgat_v2') ...
    && isequal(schema.groupMatrix,eye(7)) ...
    && isequal(spec.groupMatrix,eye(7)));
% ViewMargin follows the camera projection: on the optical axis the bearing
% is zero and the margin is the full half FOV.
vs=landing2d.observation.vectorSchema(env.observationContext);
v=zeros(vs.dimension,1); hM=0.5; exM=hM*tan(-c.experiment.sensor.cameraPitchOffset);
nrm=env.observationContext.normalization;
v(strcmp(vs.names,'relative_x'))=exM/(exM+nrm.relativePosition);
v(strcmp(vs.names,'relative_height'))=hM/(hM+nrm.height);
v(strcmp(vs.names,'drone_cosTheta'))=1;
[~,axisDetail]=landing2d.graphstate.observationVectorGraph(v,env.observationContext,c);
assert(abs(axisDetail.semanticEvidence.bearing)<1e-9 ...
    && abs(axisDetail.X(1,6)-1)<1e-9);
shuffled=landing2d.config.applyMethod(baseConfig(),'shuffled_rgat_ppo',1,1);
assert(isequal(state,landing2d.graphstate.environmentGraph(env,shuffled)));
% Node features are a deterministic function of the registered 10-D vector.
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
[trained,history]=landing2d.rl.ppoTrain(agent,c,rs);
assert(numel(history)>=2 && all(isfinite([history.score])) && sum([history.selected])==1 ...
    && all(diff([history.environmentSteps])>0) && all([history.validationEpisodes]==1));
assert(~isfield(trained.policy,'relation') && ~isfield(trained.value,'relation'));
% The common PPO loss reaches both R-GAT encoders (pre-clip gradient norms
% recorded by ppoTrain), and the encoders change.
last=history(end);
assert(last.policyEncoderGradNorm>0 && last.valueEncoderGradNorm>0 ...
    && isfinite(last.approxKL) && isfinite(last.entropy) && last.trainEpisodeLength>0 ...
    && isnan(history(1).policyEncoderGradNorm));
% Validation is allowed to retain the initial checkpoint after one update.
% Gradients above prove the update path; parameter inequality is required
% only when that updated checkpoint is the one validation selected.
if trained.trainingSelection.iteration>0
    assert(~isequal(trained.policy.encoder,agent.policy.encoder) ...
        && ~isequal(trained.value.encoder,agent.value.encoder));
else
    assert(isequal(trained.policy.encoder,agent.policy.encoder) ...
        && isequal(trained.value.encoder,agent.value.encoder));
end
% PPO starts from landing2d.rl.initialAgent (the reconstruction used by
% landing2d.evaluation.trainingDiagnostics): with no update the result is it.
c0=c; c0.rl.ppoIterations=0;
untrained=landing2d.rl.trainAgent(c0,@landing2d.rl.ppoTrain);
initial=landing2d.rl.initialAgent(c0);
assert(isequal(untrained.policy,initial.policy) && isequal(untrained.value,initial.value));
% validation_screen_v1: seeds are flown in order and independently, so a
% passed screen (or one covering every seed) is the unscreened evaluation and
% a stopped screen is the evaluation of the screen episodes alone.
seeds=c.experiment.manifest.validationSeeds(1:3);
[~,~,full]=landing2d.rl.evaluateV2(initial,c,seeds);
[~,~,first]=landing2d.rl.evaluateV2(initial,c,seeds(1));
screen=struct('rule','validation_screen_v1','episodes',1,'minimumLandingRate',0);
[~,~,passed]=landing2d.rl.evaluateV2(initial,c,seeds,struct('screen',screen));
assert(~passed.screened && passed.episodeCount==3 && ~full.screened && full.episodeCount==3 ...
    && isequal(passed.returns,full.returns) && passed.selectionScore==full.selectionScore);
screen.minimumLandingRate=1;
[~,~,stopped]=landing2d.rl.evaluateV2(initial,c,seeds,struct('screen',screen));
if first.landingRate<1
    assert(stopped.screened && stopped.episodeCount==1 && isequal(stopped.returns,first.returns) ...
        && stopped.selectionScore==first.selectionScore);
else
    assert(~stopped.screened && isequal(stopped.returns,full.returns));
end
screen.episodes=3;
[~,~,covering]=landing2d.rl.evaluateV2(initial,c,seeds,struct('screen',screen));
assert(~covering.screened && isequal(covering.returns,full.returns));
end

function checkRelationAttention()
% relational-policy-v2.9: two standard additive R-GAT layers, one softmax
% across every incoming edge, fixed equal-norm ontology-role coefficients,
% fixed semantic relation embeddings, one shared attention vector and a
% node-shared mean readout over all seven nodes.
% There is no multiplicative gate, operator class, relation-specific
% trainable bank, raw bypass or hand-set readout.
base=landing2d.graphstate.applyStateRepresentation(baseConfig(),'context_rgat');
assert(strcmp(base.graphState.encoderVersion,'rgat_v2') ...
    && strcmp(base.graphState.v2Operators,'none') ...
    && strcmp(base.graphState.v2RelationParameterization,'fixed_semantic_codebook_v1') ...
    && strcmp(base.graphState.v2ReadoutParameterization,'node_shared_mean_v1') ...
    && ~isfield(base.graphState,'relationOperators') ...
    && ~isfield(base.graphState,'relationParameterSharing'));
agent=landing2d.rl.agentInit(base.rl,RandStream('threefry','Seed',77),base.graphState);
spec=agent.encoderSpec; p=agent.policy.encoder;
expected={'V1','a1','Wroot1','b1','V2','a2','Wroot2','b2','Wc','Wn','bg'};
assert(strcmp(spec.encoderVersion,'rgat_v2') && spec.layers==2 ...
    && spec.relationBases==3 && spec.hiddenDim==16 && spec.residualMix==0 ...
    && spec.graphDim==16 && strcmp(spec.v2Operators,'none') ...
    && strcmp(spec.relationParameterization,'fixed_semantic_codebook_v1') ...
    && strcmp(spec.readoutParameterization,'node_shared_mean_v1') ...
    && strcmp(spec.readout,'grouped_factorized') ...
    && strcmp(spec.attentionMode,'input_dependent_v1') ...
    && isequal(fieldnames(p)',expected) && ~isfield(spec,'Tmod') ...
    && isequal(spec.groupMatrix,eye(7)) && spec.groupCount==7 ...
    && isequal(size(p.Wn),[16 1]));
assert(isequal(size(p.V1),[16 6 3]) && isequal(size(p.V2),[16 16 3]) ...
    && isequal(size(p.a1),[1 36]) && isequal(size(p.a2),[1 36]) ...
    && isequal(size(spec.fixedRelationCodebook),[5 3]) ...
    && isequal(size(spec.fixedRelationEmbedding),[4 5]) ...
    && ~isfield(p,'C1') && ~isfield(p,'E1') ...
    && isequal(base.graphState.v2PolicyHiddenSizes,[26 28]) ...
    && isequal(base.graphState.v2ValueHiddenSizes,[27 27]));
assert(max(abs(sum(spec.fixedRelationCodebook.^2,2)-1))<1e-12);
expectedCode=[1,-1,1;1,-1,0;1,0,0;1,1,0;1,0,-1];
expectedCode=expectedCode./sqrt(sum(expectedCode.^2,2));
expectedEmbedding=[expectedCode';0,0,0,0,1];
expectedEmbedding=expectedEmbedding./sqrt(sum(expectedEmbedding.^2,1));
assert(max(abs(spec.fixedRelationCodebook-expectedCode),[],'all')<1e-12 ...
    && max(abs(spec.fixedRelationEmbedding-expectedEmbedding),[],'all')<1e-12 ...
    && isequal(spec.relationDescriptorNames, ...
    {'sharedEvidence','targetAbstractionDepth','evidenceRole','selfRetention'}));
assert(numericCount(p)==1800 && numericCount(agent.value.encoder)==1800 ...
    && landing2d.rl.profileAgent(agent,base,1,1).parameterCount==6101);
S1=reshape(linspace(-0.9,0.9,spec.stateDim),[],1); S2=flipud(S1);
[g1,cache1]=landing2d.graphstate.encoderForward(p,spec,S1,'policy');
[~,cache2]=landing2d.graphstate.encoderForward(p,spec,S2,'policy');
expectedG=tanh(reshape(mean(cache1.channel,2).*p.Wn,spec.graphDim,1)+p.bg);
assert(max(abs(g1-expectedG),[],'all')<1e-12);
for l=1:spec.layers
    alpha=cache1.layerCaches{l}.alpha(:,1);
    sums=accumarray(spec.T.dst(:),alpha,[spec.nNodes,1]);
    assert(max(abs(sums-1))<1e-6 ...
        && ~isequal(alpha,cache2.layerCaches{l}.alpha(:,1)));
end
assert(isequal(cache1.layerH,cache1.layerF));
batch=[S1,S2,0.5*S1];
loss=@(q,x)sum(landing2d.graphstate.encoderForward(q,spec,x,'policy').^2,'all');
[gb,cb]=landing2d.graphstate.encoderForward(p,spec,batch,'policy');
[grads,dInput]=landing2d.graphstate.encoderBackward(p,spec,cb,2*gb);
h=1e-6;
for name=fieldnames(p)'
    G=grads.(name{1}); [~,k]=max(abs(G(:)));
    assert(abs(G(k))>0,'No gradient for %s.',name{1});
    pp=p; pp.(name{1})(k)=pp.(name{1})(k)+h; pm=p; pm.(name{1})(k)=pm.(name{1})(k)-h;
    numeric=(loss(pp,batch)-loss(pm,batch))/(2*h);
    assert(abs(numeric-G(k))<1e-4*max(1,abs(numeric)), ...
        'Gradient mismatch %s: analytic %.6g, numeric %.6g.',name{1},G(k),numeric);
end
[~,k]=max(abs(dInput(:))); xp=batch; xp(k)=xp(k)+h; xm=batch; xm(k)=xm(k)-h;
numeric=(loss(p,xp)-loss(p,xm))/(2*h);
assert(abs(numeric-dInput(k))<1e-4*max(1,abs(numeric)),'Input gradient mismatch.');
return;
% rgat_v2 depth4_v1 (default of the R-GAT arms, relational-policy-v2.2): four
% relational graph-attention layers (12-D nodes, independent parameters, the
% fixed residual mix 0.5 in layers 2-4) over all 20 typed edges, one input-dependent
% attention softmax per destination across relation types (alpha sums to one
% at every node in every layer, no single-edge pool forced to alpha = 1),
% relation weights from a shared basis, the R-GCN root (self-connection)
% weight, no gate / operator class / identity start / hand-set readout;
% 6,101 parameters; analytic gradients of every
% parameter group and of the input match central differences; the four-hop
% ontology chain PadVelocity -> ... -> LandingCondition is structurally open at
% four layers and closed at three. The v2.0/v2.1 two-layer encoder and the
% archived rgat_v1 encoders (typed_v1, additive_v1) still build and differentiate.
% relational-policy-v2.4 (semantic_fixed_v1): in every layer the modulate edges
% (8) form a gating attention graph and the propagate + self edges (12) the
% additive one, each with one softmax per destination; a single-edge modulate
% pool therefore has alpha = 1. Same parameters as v2.3; the v2.3 encoder
% relational-policy-v2.5 (semantic_bottleneck_v1): the same fixed operators
% share two parameter banks, and grouped_factorized reads only the ontology
% sink LandingCondition. Removed capacity moves to the heads; total 6,101.
% relational-policy-v2.6 (semantic_reliability_bottleneck_v1): only the
% three qualifiesEstimate edges modulate; all other edges propagate.
base=landing2d.graphstate.applyStateRepresentation(baseConfig(),'context_rgat');
assert(strcmp(base.graphState.encoderVersion,'rgat_v2') ...
    && strcmp(base.graphState.v2Operators,'semantic_reliability_bottleneck_v1') ...
    && ~isfield(base.graphState,'relationOperators') ...
    && ~isfield(base.graphState,'relationParameterSharing'));
agent=landing2d.rl.agentInit(base.rl,RandStream('threefry','Seed',77),base.graphState);
spec=agent.encoderSpec; p=agent.policy.encoder;
layerFields=arrayfun(@(l){sprintf('V%d',l),sprintf('C%d',l),sprintf('a%d',l),sprintf('E%d',l), ...
    sprintf('Wroot%d',l),sprintf('b%d',l)},1:4,'UniformOutput',false);
assert(strcmp(spec.encoderVersion,'rgat_v2') && spec.layers==4 && spec.relationBases==2 ...
    && spec.hiddenDim==12 && spec.residualMix==0.5 && spec.graphDim==16 ...
    && strcmp(spec.readout,'grouped_factorized') && strcmp(spec.attentionMode,'input_dependent_v1') ...
    && isequal(fieldnames(p)',[layerFields{:},{'Wc','Wn','bg'}]) ...
    && ~isfield(agent.policy,'relation'));
% Every layer has its own parameters; 2,056 per encoder, heads 24-24 / 24-20.
assert(~isequal(p.V2,p.V3) && ~isequal(p.V3,p.V4) && isequal(size(p.V1),[12 6 2]) ...
    && isequal(size(p.V4),[12 12 2]) && isequal(size(p.C1),[2 2]) ...
    && isequal(size(p.a1),[1 28 2]) && isequal(size(p.E1),[4 2]) ...
    && numericCount(p)==2056 && numericCount(agent.value.encoder)==2056 ...
    && isequal(base.graphState.v2PolicyHiddenSizes,[24 24]) ...
    && isequal(base.graphState.v2ValueHiddenSizes,[24 20]));
assert(landing2d.rl.profileAgent(agent,base,1,1).parameterCount==6101);
modRel=find(strcmp(spec.schema.relationOperators,'modulate'));
assert(strcmp(spec.v2Operators,'semantic_reliability_bottleneck_v1') ...
    && spec.parameterRelationCount==2 ...
    && isequal(spec.readoutTargetNodes,spec.schema.landingConditionNodes) ...
    && isequal(spec.groupMatrix,[0 0 0 0 0 0 1]) && spec.groupCount==1 ...
    && numel(spec.modEdges)==3 ...
    && numel(spec.addEdges)==17 && all(ismember(spec.T.rel(spec.modEdges),modRel)) ...
    && ~any(ismember(spec.T.rel(spec.addEdges),modRel)));
S1=reshape(linspace(-0.9,0.9,spec.stateDim),[],1); S2=flipud(S1);
[g1,cache1]=landing2d.graphstate.encoderForward(p,spec,S1,'policy');
[~,cache2]=landing2d.graphstate.encoderForward(p,spec,S2,'policy');
for l=1:spec.layers
    alpha=cache1.layerCaches{l}.alpha(:,1);
    for pool={spec.addEdges(:),spec.modEdges(:)}
        e=pool{1}; dst=spec.T.dst(e); sums=accumarray(dst(:),alpha(e),[spec.nNodes,1]);
        assert(max(abs(sums(unique(dst))-1))<1e-6);
    end
    assert(~isequal(alpha,cache2.layerCaches{l}.alpha(:,1)));
    % F = (1 + M) .* A with the gate exactly 1 at nodes without modulate edges.
    assert(max(abs(cache1.layerF{l}-(1+cache1.layerM{l}).*cache1.layerA{l}),[],'all')<1e-12);
    noMod=setdiff(1:spec.nNodes,unique(spec.T.dst(spec.modEdges)));
    assert(all(cache1.layerM{l}(:,noMod)==0,'all'));
end
% An additive pool with two or more inputs splits attention by input (alpha < 1).
dstAdd=spec.T.dst(spec.addEdges); multi=find(accumarray(dstAdd(:),1,[spec.nNodes,1])>=2);
alphaFirst=cache1.layerCaches{1}.alpha(:,1);
assert(~isempty(multi) && all(alphaFirst(spec.addEdges(ismember(dstAdd,multi)))<1));
% Variance-preserving residual: H^1 = F^1, H^l = sqrt(.5) H^(l-1) + sqrt(.5) F^l.
assert(strcmp(spec.residualRule,'variance_preserving_v1') && base.graphState.v2InitGain==5/3);
assert(isequal(cache1.layerH{1},cache1.layerF{1}));
for l=2:spec.layers
    assert(max(abs(cache1.layerH{l}-sqrt(0.5)*(cache1.layerH{l-1}+cache1.layerF{l})),[],'all')<1e-12);
end
% The convex rule of the specification stays available (and differentiates).
cv=base; cv.graphState.residualRule='convex_v1';
convex=landing2d.rl.agentInit(cv.rl,RandStream('threefry','Seed',77),cv.graphState);
[gc,cc]=landing2d.graphstate.encoderForward(convex.policy.encoder,convex.encoderSpec,S1,'policy');
assert(max(abs(cc.layerH{2}-(0.5*cc.layerH{1}+0.5*cc.layerF{2})),[],'all')<1e-12);
gradsConvex=landing2d.graphstate.encoderBackward(convex.policy.encoder,convex.encoderSpec,cc,ones(size(gc)));
assert(norm(gradsConvex.V1(:))>0);
% Four-hop chain: keep only PadVelocity -> RelativeVelocity -> RelativePosition
% -> ViewMargin -> LandingCondition and the self edges. LandingCondition's
% last-layer state then depends on PadVelocity's node features at four
% layers and is exactly independent of them at three (structural, not a
% numeric importance claim).
names=spec.schema.nodeNames; id=@(n)find(strcmp(names,n));
chain=[id('PadVelocity'),id('RelativeVelocity'),id('RelativePosition'),id('ViewMargin'),id('LandingCondition')];
keep=false(1,spec.T.nEdges);
for k=1:4, keep=keep|(spec.T.src==chain(k) & spec.T.dst==chain(k+1)); end
keep=keep|(spec.T.src==spec.T.dst);
assert(sum(keep)==4+spec.nNodes);
masked=spec.schema; masked.src=spec.schema.src(keep); masked.dst=spec.schema.dst(keep);
masked.rel=spec.schema.rel(keep);
chainSpec=spec; chainSpec.T=landing2d.rgat.topology(masked);
isModMasked=ismember(masked.rel,modRel);
chainSpec.addEdges=find(~isModMasked); chainSpec.modEdges=find(isModMasked);
part=masked; part.src=masked.src(~isModMasked); part.dst=masked.dst(~isModMasked);
part.rel=ones(size(part.src)); part.nRelations=2; chainSpec.Tadd=landing2d.rgat.topology(part);
part=masked; part.src=masked.src(isModMasked); part.dst=masked.dst(isModMasked);
part.rel=2*ones(size(part.src)); part.nRelations=2; chainSpec.Tmod=landing2d.rgat.topology(part);
X=reshape(S1,spec.inDim,spec.nNodes); Xp=X; Xp(:,chain(1))=Xp(:,chain(1))+0.3;
for depth=[4 3]
    depthSpec=chainSpec; depthSpec.layers=depth;
    [~,c0]=landing2d.graphstate.encoderForward(p,depthSpec,X(:),'policy');
    [~,c1]=landing2d.graphstate.encoderForward(p,depthSpec,Xp(:),'policy');
    change=max(abs(c1.layerH{depth}(:,chain(end))-c0.layerH{depth}(:,chain(end))));
    if depth==4, assert(change>1e-6,'Four-hop chain closed at four layers.');
    else, assert(change==0,'LandingCondition reached in three layers on the four-hop chain.'); end
end
batch=[S1,S2,0.5*S1];
loss=@(q,x)sum(landing2d.graphstate.encoderForward(q,spec,x,'policy').^2,'all');
[gb,cb]=landing2d.graphstate.encoderForward(p,spec,batch,'policy');
[grads,dInput]=landing2d.graphstate.encoderBackward(p,spec,cb,2*gb);
h=1e-6;
for name=fieldnames(p)'
    G=grads.(name{1}); [~,k]=max(abs(G(:)));
    assert(abs(G(k))>0,'No gradient for %s.',name{1});
    pp=p; pp.(name{1})(k)=pp.(name{1})(k)+h; pm=p; pm.(name{1})(k)=pm.(name{1})(k)-h;
    numeric=(loss(pp,batch)-loss(pm,batch))/(2*h);
    assert(abs(numeric-G(k))<1e-4*max(1,abs(numeric)), ...
        'Gradient mismatch %s: analytic %.6g, numeric %.6g.',name{1},G(k),numeric);
end
[~,k]=max(abs(dInput(:)));
xp=batch; xp(k)=xp(k)+h; xm=batch; xm(k)=xm(k)-h;
numeric=(loss(p,xp)-loss(p,xm))/(2*h);
assert(abs(numeric-dInput(k))<1e-4*max(1,abs(numeric)),'Input gradient mismatch.');
% The archived v2.3 encoder (no operator classes): one softmax over all
% incoming edges, old head allocation, and 6,101 parameters.
c=baseConfig(); c.graphState.v2Operators='none';
c.graphState.v2PolicyHiddenSizes=[16,12]; c.graphState.v2ValueHiddenSizes=[15,13];
c=landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
v23=landing2d.rl.agentInit(c.rl,RandStream('threefry','Seed',77),c.graphState);
assert(strcmp(v23.encoderSpec.v2Operators,'none') && ~isfield(v23.encoderSpec,'Tmod') ...
    && landing2d.rl.profileAgent(v23,c,1,1).parameterCount==6101);
[g23,c23]=landing2d.graphstate.encoderForward(v23.policy.encoder,v23.encoderSpec,S1,'policy');
assert(~isequal(g23,g1));
for l=1:4
    sums=accumarray(v23.encoderSpec.T.dst(:),c23.layerCaches{l}.alpha(:,1),[spec.nNodes,1]);
    assert(max(abs(sums-1))<1e-6);
end
% The v2.0/v2.1 two-layer rgat_v2 (16-D nodes, no residual, no operator
% classes, heads 27-26 / 25-24) still builds with 6,101 parameters.
c=baseConfig(); c.graphState.layers=2; c.graphState.v2HiddenDim=16; c.graphState.residualMix=0;
c.graphState.v2Operators='none';
c.graphState.v2InitGain=1;
c.graphState.v2PolicyHiddenSizes=[27,26]; c.graphState.v2ValueHiddenSizes=[25,24];
c=landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
two=landing2d.rl.agentInit(c.rl,RandStream('threefry','Seed',77),c.graphState);
assert(two.encoderSpec.layers==2 && two.encoderSpec.residualMix==0 ...
    && landing2d.rl.profileAgent(two,c,1,1).parameterCount==6101 ...
    && isequal(fieldnames(two.policy.encoder)',{'V1','C1','a1','E1','Wroot1','b1','V2','C2','a2','E2', ...
    'Wroot2','b2','Wc','Wn','bg'}));
[g2,c2]=landing2d.graphstate.encoderForward(two.policy.encoder,two.encoderSpec,S1,'policy');
assert(isequal(c2.layerH,c2.layerF));
grads2=landing2d.graphstate.encoderBackward(two.policy.encoder,two.encoderSpec,c2,ones(size(g2)));
assert(norm(grads2.V1(:))>0 && norm(grads2.a2(:))>0);
% Archived single-layer encoders remain available.
for mode=["typed_v1","additive_v1"]
    c=baseConfig(); c.graphState.encoderVersion='rgat_v1';
    c.graphState.relationOperators=char(mode);
    if mode=="typed_v1", c.graphState.relationParameterSharing='operator_shared_v1'; end
    c=landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
    legacy=landing2d.rl.agentInit(c.rl,RandStream('threefry','Seed',77),c.graphState);
    assert(strcmp(legacy.encoderSpec.encoderVersion,'rgat_v1') ...
        && landing2d.rl.profileAgent(legacy,c,1,1).parameterCount==6101);
    [gl,cl]=landing2d.graphstate.encoderForward(legacy.policy.encoder,legacy.encoderSpec,S1,'policy');
    gradsLegacy=landing2d.graphstate.encoderBackward(legacy.policy.encoder,legacy.encoderSpec,cl,ones(size(gl)));
    assert(norm(gradsLegacy.W1(:))>0 && norm(gradsLegacy.a1(:))>0);
end
end

function checkEvaluation()
% Seed-level statistics, seed-paired contrasts, factorial effects on a
% synthetic table, and the open-loop probe set on one reference episode.
rows=[];
for m=["ppo","onto_rgat_ppo"]
    for t=1:3
        for r=1:4
            for k=1:4
                value=r+10*k+100*double(m=="onto_rgat_ppo")*t;
                rows=[rows;struct('MethodId',m,'Method',m,'TrainSeed',t,'Replicate',r, ...
                    'Case',"S"+k,'EpisodeSeed',43000+r,'Success',1,'Failure',0, ...
                    'WindowAimErrorRMS_m',value,'WindowRelativeSpeedRMS_mps',0, ...
                    'WindowCommandRateRMS_mps3',0,'UnsuitableDescent_s',double(k==4))]; %#ok<AGROW>
            end
        end
    end
end
T=struct2table(rows);
R=landing2d.evaluation.runMeans(T,{'Case'},{'WindowAimErrorRMS_m'});
assert(height(R)==2*3*4 && all(R.Episodes==4));
S=landing2d.evaluation.seedSummary(R,{'Case'},{'WindowAimErrorRMS_m'});
row=S(S.Case=="S1" & S.MethodId=="onto_rgat_ppo",:);
assert(row.Seeds==3 && abs(row.WindowAimErrorRMS_m-(2.5+10+200))<1e-12 ...
    && abs(row.WindowAimErrorRMS_m_ci-4.303*100/sqrt(3))<1e-9);
C=landing2d.evaluation.methodContrasts(R,{'Case'},{'WindowAimErrorRMS_m'});
d=C(C.Case=="S1" & C.Contrast=="onto_rgat_ppo - ppo",:);
assert(d.Seeds==3 && abs(d.Delta_WindowAimErrorRMS_m-200)<1e-12 ...
    && d.Delta_WindowAimErrorRMS_m_positive==3);
one=landing2d.evaluation.seedSummary(R(R.TrainSeed==1,:),{'Case'},{'WindowAimErrorRMS_m'});
assert(all(isnan(one.WindowAimErrorRMS_m_ci)));
% Seed quartiles (type 7) and the episode total behind the run means.
assert(abs(row.WindowAimErrorRMS_m_median-212.5)<1e-12 ...
    && abs(row.WindowAimErrorRMS_m_q25-162.5)<1e-12 ...
    && abs(row.WindowAimErrorRMS_m_q75-262.5)<1e-12 && row.Episodes==12);
% Failure classes: per-run fractions over a fixed class list.
T.FailureClass=repmat("SUCCESS",height(T),1);
T.FailureClass(T.Case=="S4" & T.MethodId=="ppo")="TIMEOUT_TRACKING";
[FR,FS]=landing2d.evaluation.failureTable(T,{'Case'});
classes=landing2d.evaluation.failureClasses();
assert(height(FR)==2*3*4*numel(classes) && all(abs(splitapply(@sum,FR.Fraction, ...
    findgroups(FR(:,{'Case','MethodId','TrainSeed'})))-1)<1e-12));
f=FS(FS.Case=="S4" & FS.MethodId=="ppo" & FS.Class=="TIMEOUT_TRACKING",:);
assert(f.Fraction==1 && f.Seeds==3);
unknown=T; unknown.FailureClass(:)="CRASH";
assertThrows(@()landing2d.evaluation.failureTable(unknown,{'Case'}),'landing2d:FailureClass');
% Factorial effects: S_k values r + 10 k -> dropout|CV = 10, motion|clean = 20,
% interaction = 0; unsuitable descent only in S4 -> interaction 1.
c=baseConfig();
E=landing2d.evaluation.factorialEffects(T,{'WindowAimErrorRMS_m','UnsuitableDescent_s'});
ppo=E(E.MethodId=="ppo",:);
assert(all(abs(ppo.WindowAimErrorRMS_m(ppo.Effect=="Dropout|CV")-10)<1e-12) ...
    && all(abs(ppo.WindowAimErrorRMS_m(ppo.Effect=="Motion|clean")-20)<1e-12) ...
    && all(abs(ppo.WindowAimErrorRMS_m(ppo.Effect=="Interaction"))<1e-12) ...
    && all(ppo.UnsuitableDescent_s(ppo.Effect=="Interaction")==1));
% Probe set: nominal replay = environment; stale replays predict; noise
% replicates replay the same physical trajectory with other noise tables.
c.evaluation.probes.episodes=1; c.evaluation.probes.stride=15;
c.evaluation.probes.noiseReplicates=2;
P=landing2d.evaluation.buildProbeSet(c);
assert(~isempty(P.velocity));
dv=c.evaluation.probes.velocityDelta;
v=P.velocity(1);
assert(abs(v.plus.ugv.velocityXZ(1)-v.minus.ugv.velocityXZ(1)-2*dv)<1e-12 ...
    && isequal(v.plus.ugv.positionXZ,v.minus.ugv.positionXZ));
assert(numel(P.noise)==numel(P.velocity) && numel(P.noise(1).O)==3 ...
    && isequal(P.noise(1).O{1}.ugv.positionXZ,v.plus.ugv.positionXZ) ...
    && ~isequal(P.noise(1).O{2}.ugv.positionXZ,P.noise(1).O{1}.ugv.positionXZ) ...
    && P.noise(1).decision==v.decision);
for i=1:numel(P.update)
    assert(~P.update(i).stale.ugv.visionUpdated && P.update(i).fresh.ugv.visionUpdated ...
        && P.update(i).stale.ugv.visionAge>=c.evaluation.probes.staleAge-1e-9);
end
end

function checkCommonObservation()
% o_t = [G;D;H] (24-D): UGV state from corners -> planar PnP -> KF, drone
% navigation with the paper noise, previous-decision motion record; Gamma
% stays out of o_t; capture accepts only detections and navigation; prediction
% (never truth) while unseen; one planar camera (tracker geometry = marker
% camera); start with the pad on the optical axis; marker perception drives
% landing authorization with the blind final-descent latch.
c=baseConfig(); co=c.experiment.commonObservation;
[env,~,info]=landing2d.environment.reset(c,5);
G=info.observationContext; O=info.commonObservation;
schema=landing2d.observation.vectorSchema(G);
assert(schema.dimension==10 && numel(unique(schema.names))==10);
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
    && abs(sensor.fov-2*atan(K(2,3)/K(2,2)))<1e-12);
% Start at the camera-aim point (pad on the optical axis, behind the pad) plus
% the sampled position offset, seen and authorized from the first frame.
h0=env.physicalState.z-env.pad.z;
assert(abs(env.physicalState.x-(env.pad.x+h0*tan(sensor.cameraPitchOffset) ...
    +env.scenario.initialPositionOffsetApplied))<1e-12 ...
    && env.physicalState.x<env.pad.x && info.packet.trackInitialized);
% The evaluation aim error uses the reward's aim point: at the start it is
% exactly minus the applied position offset (0 at the aim point itself).
assert(abs(landing2d.evaluation.aimError(env.pad.x,env.physicalState.x,h0,c) ...
    +env.scenario.initialPositionOffsetApplied)<1e-12);
assert(O.ugv.estimateInitialized && O.ugv.visionUpdated && ~env.episodeStatus.landingInhibited);
% Vector: x relative to the current drone x (drone_x = 0), z/velocity scaled.
x=landing2d.observation.toVector(O,G);
named=@(v,name)v(strcmp(schema.names,name));
assert(numel(x)==10 && all(isfinite(x)));
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
changed=c; changed.experiment.commonObservation.detector.pixelNoiseStd= ...
    2*c.experiment.commonObservation.detector.pixelNoiseStd;
assert(~isequal(landing2d.environment.taskFingerprint(c), ...
    landing2d.environment.taskFingerprint(changed)));
arm=landing2d.graphstate.applyStateRepresentation(c,'context_rgat');
assert(isfield(landing2d.rl.trainingSignature(arm).experiment,'commonObservation'));
[env,~,~,~,~,stepInfo]=landing2d.environment.step(env,[0.3;-0.2]);
H=env.commonObservation.history;
assert(H.valid && H.ugvInitialized && isequal(H.dronePositionXZ,O.drone.positionXZ) ...
    && isequal(H.ugvPositionXZ,O.ugv.positionXZ) && isfield(stepInfo.perceptionError,'position'));
end

function checkRelationShuffle()
% v2.9 has no operator classes. The shuffled arm changes at least 10/13
% semantic labels while preserving self edges, topology and relation counts;
% both arms share the same fixed codebook and initial trainable parameters.
base=baseConfig();
onto=landing2d.config.applyMethod(base,'onto_rgat_ppo',1);
[paramsO,specO]=landing2d.graphstate.encoderInit(onto.graphState, ...
    onto.rl.observationDim,RandStream('threefry','Seed',1));
canonical=specO.T.rel; selfId=find(strcmp(specO.schema.relationNames,'self'));
counts=@(rel)accumarray(rel(:),1,[specO.schema.nRelations,1]);
registry=landing2d.config.methodRegistry();
semantic=find(canonical~=selfId);
minChanged=ceil(registry.relationShuffle.minChangedFraction*numel(semantic)-1e-9);
assert(minChanged==10);
hashes=strings(1,3);
for g=1:3
    sh=landing2d.config.applyMethod(base,'shuffled_rgat_ppo',1,g);
    assert(~isfield(sh.graphState.relationPerturbation,'minOperatorChangedFraction'));
    [paramsS,specS]=landing2d.graphstate.encoderInit(sh.graphState, ...
        sh.rl.observationDim,RandStream('threefry','Seed',1));
    rel=specS.T.rel;
    assert(isequal(specS.T.src,specO.T.src) && isequal(specS.T.dst,specO.T.dst) ...
        && isequal(counts(rel),counts(canonical)) && all(rel(canonical==selfId)==selfId) ...
        && sum(rel(semantic)~=canonical(semantic))>=minChanged ...
        && isequal(paramsS,paramsO) ...
        && isequal(specS.fixedRelationCodebook,specO.fixedRelationCodebook) ...
        && isequal(specS.fixedRelationEmbedding,specO.fixedRelationEmbedding) ...
        && ~strcmp(specS.graph.hash,specO.graph.hash));
    [~,again]=landing2d.graphstate.encoderInit(sh.graphState,sh.rl.observationDim, ...
        RandStream('threefry','Seed',2));
    assert(isequal(again.T.rel,rel) && strcmp(again.graph.hash,specS.graph.hash));
    hashes(g)=string(specS.graph.hash);
end
assert(numel(unique(hashes))==3);
return;
% Fixed edge-relation shuffle: same nodes/src/dst/counts/per-relation counts,
% self edges protected, never the canonical assignment or a global renaming
% of it, at least minChangedFraction of the semantic edges retyped
% (registry v6-v9: no operator rule; v10-v11 fixed operators changed 10 of
% 13; v12 reliability operators change the maximum 6 of 13),
% reproducible per graph seed, distinct hashes, identical initial weights,
% the stored graph used through PPO and inference, and checkpoints that
% cannot be swapped between graphs.
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
    sem=canonical~=selfId; ops=specO.schema.relationOperators;
    assert(sum(~strcmp(ops(rel(sem)),ops(canonical(sem))))>=6 ...
        && ~isequal(specS.modEdges,specO.modEdges));
    assert(isequal(paramsS,paramsO) && ~strcmp(specS.graph.hash,specO.graph.hash));
    [~,again]=landing2d.graphstate.encoderInit(sh.graphState,sh.rl.observationDim, ...
        RandStream('threefry','Seed',2));
    assert(isequal(again.T.rel,rel) && strcmp(again.graph.hash,specS.graph.hash));
    hashes(g)=string(specS.graph.hash);
end
assert(numel(unique(hashes))==3);
schema=landing2d.graphstate.contextSchema('context_rgat',2,'commonObservation');
schema.relationOperators=specO.schema.relationOperators;
T=landing2d.rgat.topology(schema);
registry=landing2d.config.methodRegistry();
semantic=find(canonical~=selfId);
minChanged=ceil(registry.relationShuffle.minChangedFraction*numel(semantic)-1e-9);
assert(minChanged==10 && ~isfield(registry.relationShuffle,'minOperatorChangedFraction') ...
    && sh.graphState.relationPerturbation.minChangedFraction== ...
        registry.relationShuffle.minChangedFraction ...
    && sh.graphState.relationPerturbation.minOperatorChangedFraction== ...
        registry.relationShuffle.minReliabilityOperatorChangedFraction);
for g=1:60
    gs=struct('relationPerturbation',struct('type','edge_relation_shuffle','graphSeed',g, ...
        'minChangedFraction',registry.relationShuffle.minChangedFraction, ...
        'minOperatorChangedFraction',registry.relationShuffle.minReliabilityOperatorChangedFraction));
    [~,Tg]=landing2d.rgat.applyRelationPerturbation(schema,T,gs);
    assert(~isequal(Tg.rel,canonical) ...
        && sum(Tg.rel(semantic)~=canonical(semantic))>=minChanged ...
        && sum(~strcmp(specO.schema.relationOperators(Tg.rel(semantic)), ...
            specO.schema.relationOperators(canonical(semantic))))>=6);
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
sh.rl.ppoIterations=1; sh.rl.episodesPerIteration=1; sh.rl.ppoEpochs=1;
sh.rl.miniBatch=64; sh.rl.evaluateEvery=1; sh.rl.valueWarmup=0;
sh.rl.parallelEpisodes=false; sh.rl.verbose=false;
sh.experiment.validationEpisodeCount=1;
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
% scale, the exogenous manifest, the sensing replay of a reference trajectory
% (bit-identical at the nominal scale; basis of the open-loop probes), and the
% closed-loop command log (pre-tanh mean, requested, applied per physics step,
% supervisor reasons, actual acceleration as separate evaluation truth).
c=baseConfig(); co=c.experiment.commonObservation; sensor=c.experiment.sensor;
% Evaluation settings are outside the task fingerprint and the training signature.
alt=c; alt.evaluation.probes.stride=7; alt.evaluation.generalization.episodes=3;
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
% scale^2); scale 0 is noise free.
zero=landing2d.environment.reset(c,7,struct('sensorNoiseScale',0));
double2=landing2d.environment.reset(c,7,struct('sensorNoiseScale',2));
assert(~any(zero.noise.marker(:)) && ~any(zero.noise.navigation(:)) ...
    && isequal(double2.noise.marker,2*envB.noise.marker) ...
    && isequal(double2.noise.tracker,2*envB.noise.tracker));
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
arms=landing2d.config.comparisonArms(c);
limits=landing2d.environment.actionLimits(c);
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

function n=numericCount(s)
% Trainable scalars of a parameter struct (numeric leaves).
n=0;
for name=fieldnames(s)'
    v=s.(name{1});
    if isstruct(v), n=n+numericCount(v); elseif isnumeric(v), n=n+numel(v); end
end
end

function c=baseConfig()
c=landing2d.config.primaryConfig(landing2d.orchestration.projectRoot());
end

function assertThrows(fun,id)
threw=false;
try, fun(); catch err, threw=strcmp(err.identifier,id); end
assert(threw,'Expected error %s.',id);
end
