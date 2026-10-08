function [result,traj] = rolloutEpisodeV2(agent,c,seed,opts)
% ROLLOUTEPISODEV2  PPO rollout through the versioned reset/step contract.
% traj.time are the policy decision timestamps; traj.actorMean is the
% pre-tanh actor mean (diagnostic; equals traj.command in deterministic runs);
% traj.requestedAcceleration is tanh(command) times the axis limits before the
% supervisor; traj.appliedAccelerationIntervalMean is the decision-interval
% average of the supervisor-applied command (not a high-rate command).
% opts.commandLog = true adds result.commandLog (landing2d.rl.rolloutEpisodeV2
% local buildCommandLog): policy input/output, decision context, per-physics-
% step applied commands and supervisor reasons, evaluation-only truth (actual
% body acceleration, perception error) and the exogenous manifest, kept in
% separate sections. opts.run / opts.configHash identify the policy and the
% resolved configuration; opts.sensorNoiseScale scales planar sensor noise.
% opts.descentPrefix (training curriculum only) = struct('handoverHeight',h,
% 'maxTime',T): the causal reference driver flies the episode start until the
% height above the pad is at most h (or T seconds pass); the policy acts from
% there and the prefix decisions are not policy transitions.
if nargin < 4, opts = struct(); end
opts = defaults(opts,struct('deterministic',false,'collect',true, ...
    'rs',[],'maxDecisions',Inf,'traceGraph',false, ...
    'scenarioHeightRange',[],'scenario',[],'sensorEvents',[], ...
    'sensorNoiseScale',[],'commandLog',false,'commandLogStates',false, ...
    'run',struct(),'configHash','','descentPrefix',[]));
if isempty(opts.rs)
    opts.rs = RandStream('threefry','Seed',c.experiment.scenario.baseSeed+ ...
        c.experiment.randomStreams.policyOffset+double(seed));
end
resetOptions = struct();
if ~isempty(opts.scenarioHeightRange)
    resetOptions.scenarioHeightRange = opts.scenarioHeightRange;
end
if ~isempty(opts.scenario), resetOptions.scenario = opts.scenario; end
if ~isempty(opts.sensorEvents), resetOptions.sensorEvents = opts.sensorEvents; end
if ~isempty(opts.sensorNoiseScale), resetOptions.sensorNoiseScale = opts.sensorNoiseScale; end
[env,observation,resetInfo] = landing2d.environment.reset(c,seed,resetOptions);
manifest = struct();
if opts.commandLog, manifest = landing2d.environment.exogenousManifest(env); end
prefixDecisions = 0;
if ~isempty(opts.descentPrefix)
    assert(~isempty(env.commonObservation),'landing2d:DescentPrefix', ...
        'The descent prefix needs the planar common observation.');
    while ~env.episodeStatus.terminated && env.time < opts.descentPrefix.maxTime ...
            && env.physicalState.z-env.pad.z > opts.descentPrefix.handoverHeight
        a = landing2d.probe.referenceDriver(env.commonObservation, ...
            env.observationContext,c,[],0);
        [env,observation] = landing2d.environment.step(env,a);
        prefixDecisions = prefixDecisions+1;
    end
end
capacity = min(ceil(env.scenario.deadline/c.experiment.policyDt)+1, ...
    opts.maxDecisions);
if ~isfinite(capacity), capacity = ceil(env.scenario.deadline/c.experiment.policyDt)+1; end
stateDim = agent.encoderSpec.stateDim;
traj = struct('time',zeros(1,capacity),'observation',zeros(c.rl.observationDim,capacity), ...
    'state',zeros(stateDim,capacity),'nextObservation',zeros(c.rl.observationDim,capacity), ...
    'command',zeros(c.rl.actionDim,capacity),'actorMean',zeros(c.rl.actionDim,capacity), ...
    'normalizedAction',zeros(c.rl.actionDim,capacity), ...
    'requestedAcceleration',zeros(c.rl.actionDim,capacity), ...
    'appliedAccelerationIntervalMean',zeros(c.rl.actionDim,capacity), ...
    'logProbability',zeros(1,capacity),'value',zeros(1,capacity), ...
    'baseMean',zeros(c.rl.actionDim,capacity), ...
    'relationResidual',zeros(c.rl.actionDim,capacity), ...
    'descentEligibility',ones(1,capacity), ...
    'verticalGateActive',false(1,capacity), ...
    'reward',zeros(1,capacity),'rewardComponents',{cell(1,capacity)}, ...
    'terminated',false(1,capacity),'truncated',false(1,capacity), ...
    'discount',zeros(1,capacity),'dt',zeros(1,capacity), ...
    'safetyIntervened',false(1,capacity),'landingInhibited',false(1,capacity), ...
    'count',0,'bootstrap',0, ...
    'captureRate',0,'return',0,'graphValues',[],'graphStates',[]);
log = initializeLog(capacity+1,env);
detections = 0;
if opts.commandLog
    decisionLog = initializeDecisionLog(capacity,resetInfo);
end
while ~env.episodeStatus.terminated && traj.count < capacity
    state = policyState(observation,env,c,agent.encoderSpec.mode);
    % Landing authorization in force during this decision (environment record,
    % not a planar policy input).
    landingInhibited = env.episodeStatus.landingInhibited;
    decisionStatus = env.episodeStatus;
    decisionTime = env.time;
    [u,logProbability,mu,policyDetail] = landing2d.rl.policyAction(agent,state,opts.rs, ...
        opts.deterministic);
    aNorm = tanh(u);
    value = landing2d.rl.valueForward(agent,state);
    [env,nextObservation,reward,terminated,truncated,stepInfo] = ...
        landing2d.environment.step(env,aNorm);
    k = traj.count+1;
    traj.count = k;
    traj.time(k) = decisionTime;
    traj.observation(:,k) = observation;
    traj.state(:,k) = state;
    traj.nextObservation(:,k) = nextObservation;
    traj.command(:,k) = u;
    traj.actorMean(:,k) = mu;
    traj.normalizedAction(:,k) = aNorm;
    traj.requestedAcceleration(:,k) = stepInfo.requestedAcceleration;
    traj.appliedAccelerationIntervalMean(:,k) = stepInfo.appliedAccelerationIntervalMean;
    if opts.commandLog
        decisionLog = appendDecisionLog(decisionLog,k,decisionStatus,stepInfo);
    end
    traj.logProbability(k) = logProbability;
    traj.value(k) = value;
    traj.baseMean(:,k) = policyDetail.baseMean;
    traj.relationResidual(:,k) = policyDetail.relationResidual;
    traj.descentEligibility(k) = policyDetail.descentEligibility;
    traj.verticalGateActive(k) = policyDetail.verticalGateActive;
    traj.reward(k) = reward;
    traj.rewardComponents{k} = stepInfo.rewardComponents;
    traj.terminated(k) = terminated;
    traj.truncated(k) = truncated;
    traj.dt(k) = stepInfo.dt;
    traj.discount(k) = exp(-stepInfo.dt/ ...
        c.experiment.reward.discountTimeConstant);
    traj.safetyIntervened(k) = stepInfo.supervisorIntervened;
    traj.landingInhibited(k) = landingInhibited;
    detections = detections+double(visionAvailable(env));
    log = appendLog(log,k+1,env,stepInfo);
    observation = nextObservation;
end
if ~env.episodeStatus.terminated && traj.count >= capacity
    traj.truncated(traj.count) = true;
    finalState = policyState(observation,env,c,agent.encoderSpec.mode);
    traj.bootstrap = landing2d.rl.valueForward(agent,finalState);
    env.episodeStatus.truncated = true;
else
    traj.bootstrap = 0;
end
n = traj.count;
matrixFields = {'observation','state','nextObservation','command','actorMean', ...
    'normalizedAction','requestedAcceleration','appliedAccelerationIntervalMean', ...
    'baseMean','relationResidual'};
rowFields = {'time','logProbability','value','reward','terminated','truncated', ...
    'discount','dt','safetyIntervened','landingInhibited','descentEligibility', ...
    'verticalGateActive'};
for i = 1:numel(matrixFields), traj.(matrixFields{i}) = traj.(matrixFields{i})(:,1:n); end
for i = 1:numel(rowFields), traj.(rowFields{i}) = traj.(rowFields{i})(1:n); end
traj.rewardComponents = traj.rewardComponents(1:n);
traj.return = sum(traj.reward);
traj.captureRate = detections/max(n,1);
result = struct('schemaVersion','rollout_result_v2','seed',seed, ...
    'scenario',env.scenario,'status',env.episodeStatus.terminalReason, ...
    'terminated',env.episodeStatus.terminated,'truncated',env.episodeStatus.truncated, ...
    'return',traj.return,'captureRate',traj.captureRate,'time',log.time(1:n+1), ...
    'xDrone',log.xDrone(1:n+1),'zDrone',log.zDrone(1:n+1), ...
    'vxDrone',log.vxDrone(1:n+1),'vzDrone',log.vzDrone(1:n+1), ...
    'theta',log.theta(1:n+1),'pitchRate',log.pitchRate(1:n+1), ...
    'xPad',log.xPad(1:n+1),'vxPad',log.vxPad(1:n+1), ...
    'visible',log.visible(1:n+1),'supervisor',log.supervisor(1:n+1), ...
    'terminalReason',env.episodeStatus.terminalReason, ...
    'landingTime',terminalTime(env,'SUCCESS'),'failureTime',failureTime(env), ...
    'resetInfo',resetInfo,'policyDiagnostics',policyDiagnostics(traj), ...
    'prefixDecisions',prefixDecisions,'commandLog',[]);
if isfield(log,'yDrone')
    % 3D option: lateral/roll trajectory alongside the planar fields.
    for name={'yDrone','vyDrone','roll','rollRate','yPad','vyPad'}
        result.(name{1})=log.(name{1})(1:n+1);
    end
end
if opts.commandLog
    result.commandLog = buildCommandLog(traj,decisionLog,log,result,manifest,env,c, ...
        seed,opts,agent.encoderSpec.mode);
end
end

function d = initializeDecisionLog(capacity,resetInfo)
d = struct('abortRequested',false(1,capacity),'finalDescentActive',false(1,capacity), ...
    'supervisorReasons',{cell(1,capacity)},'physics',{cell(1,capacity)}, ...
    'perceptionError',{cell(1,capacity+1)});
d.perceptionError{1} = resetInfo.perceptionError;
end

function d = appendDecisionLog(d,k,status,stepInfo)
% Decision context in force during decision k, its supervisor reasons and
% physics substeps, and the evaluation-only estimate error at its end.
d.abortRequested(k) = status.abortRequested;
d.finalDescentActive(k) = isfield(status,'finalDescentActive') && status.finalDescentActive;
d.supervisorReasons{k} = stepInfo.supervisorReasons;
physics = stepInfo.physics;
physics.decisionIndex = k*ones(1,numel(physics.time));
d.physics{k} = physics;
d.perceptionError{k+1} = stepInfo.perceptionError;
end

function L = buildCommandLog(traj,d,truthLog,result,manifest,env,c,seed,opts,mode)
% Sections: identity, policy (input and output, before the supervisor),
% decision (environment decision context and supervisor record, not policy
% input), physics (supervisor-applied command per physics substep), truth and
% exogenous (evaluation only; exogenous includes future events), outcome.
n = traj.count;
physics = [d.physics{1:n}];
if isempty(physics)
    names = {'time','dt','appliedAcceleration','actualAcceleration', ...
        'supervisorIntervened','supervisorReasonCode','decisionIndex'};
    physics = cell2struct(cell(numel(names),1),names,1);
else
    physics = struct('time',[physics.time],'dt',[physics.dt], ...
        'decisionIndex',[physics.decisionIndex], ...
        'appliedAcceleration',[physics.appliedAcceleration], ...
        'supervisorIntervened',[physics.supervisorIntervened], ...
        'supervisorReasonCode',[physics.supervisorReasonCode], ...
        'actualAcceleration',[physics.actualAcceleration]);
end
[~,reasonNames] = landing2d.control.supervisorReasonCode({});
limits = landing2d.environment.actionLimits(c);
axisNames = {'a_x','a_z'};
if numel(limits) == 3, axisNames = {'a_x','a_y','a_z'}; end
identity = struct('schemaVersion','command_log_v1','seed',seed,'run',opts.run, ...
    'configHash',opts.configHash,'stateRepresentation',mode, ...
    'deterministic',opts.deterministic,'sensorNoiseScale',env.provenance.noiseScale, ...
    'policyDt',c.experiment.policyDt,'physicsDt',c.experiment.physicsDt, ...
    'actionLimits',limits(:)','axisNames',{axisNames});
policy = struct('time',traj.time,'observation',traj.observation, ...
    'actorMean',traj.actorMean,'command',traj.command, ...
    'normalizedAction',traj.normalizedAction, ...
    'requestedAcceleration',traj.requestedAcceleration);
if opts.commandLogStates, policy.state = traj.state; end
decision = struct('time',traj.time,'dt',traj.dt, ...
    'landingInhibited',traj.landingInhibited,'abortRequested',d.abortRequested(1:n), ...
    'finalDescentActive',d.finalDescentActive(1:n), ...
    'supervisorIntervened',traj.safetyIntervened, ...
    'supervisorReasons',{d.supervisorReasons(1:n)}, ...
    'appliedAccelerationIntervalMean',traj.appliedAccelerationIntervalMean);
physicsLog = rmfield(physics,'actualAcceleration');
physicsLog.reasonNames = reasonNames;
truth = struct('time',result.time, ...
    'drone',struct('x',truthLog.xDrone(1:n+1),'z',truthLog.zDrone(1:n+1), ...
        'vx',truthLog.vxDrone(1:n+1),'vz',truthLog.vzDrone(1:n+1), ...
        'theta',truthLog.theta(1:n+1),'pitchRate',truthLog.pitchRate(1:n+1)), ...
    'pad',struct('x',truthLog.xPad(1:n+1),'vx',truthLog.vxPad(1:n+1)), ...
    'physicsTime',physics.time,'actualAcceleration',physics.actualAcceleration, ...
    'perceptionError',perceptionErrors(d.perceptionError(1:n+1)));
outcome = struct('terminalReason',result.terminalReason,'return',result.return, ...
    'landingTime',result.landingTime,'failureTime',result.failureTime, ...
    'terminated',result.terminated,'truncated',result.truncated,'decisions',n);
labels = struct( ...
    'actorMean','tanh 이전 actor 평균 (진단용, 무차원)', ...
    'requestedAcceleration','정책 요청 가속도 명령, 감독기 적용 전 [m/s^2]', ...
    'appliedAccelerationIntervalMean','결정 구간 평균 적용 명령, 감독기 적용 후 [m/s^2]', ...
    'physicsAppliedAcceleration','물리 스텝 적용 명령, 감독기 적용 후 [m/s^2]', ...
    'actualAcceleration','실제 기체 가속도, 지연 동역학 참값 (평가 전용) [m/s^2]', ...
    'policyTime','정책 결정 시각 [s]','physicsTime','물리 스텝 종료 시각 [s]');
L = struct('identity',identity,'policy',policy,'decision',decision, ...
    'physics',physicsLog,'truth',truth,'exogenous',manifest,'outcome',outcome, ...
    'labels',labels);
end

function e = perceptionErrors(cells)
% Planar UGV-estimate error per decision boundary (evaluation only); empty
% for configurations without the common observation.
m = numel(cells);
e = struct('valid',false(1,m),'visionUpdated',false(1,m), ...
    'position',NaN(2,m),'velocity',NaN(2,m));
for i = 1:m
    if isempty(cells{i}), continue; end
    e.valid(i) = cells{i}.valid; e.visionUpdated(i) = cells{i}.visionUpdated;
    e.position(:,i) = cells{i}.position; e.velocity(:,i) = cells{i}.velocity;
end
end

function d=policyDiagnostics(traj)
if traj.count==0
    blank=zeros(size(traj.relationResidual,1),1);
    d=struct('meanAbsRelationResidual',blank, ...
        'terminalRelationResidual',blank, ...
        'meanDescentEligibility',1,'verticalGateFraction',0);
    return;
end
d=struct('meanAbsRelationResidual',mean(abs(traj.relationResidual),2), ...
    'terminalRelationResidual',traj.relationResidual(:,end), ...
    'meanDescentEligibility',mean(traj.descentEligibility), ...
    'verticalGateFraction',mean(traj.verticalGateActive));
end

function state = policyState(observation,env,c,mode)
% Baseline: the environment observation (planar: registered 12-D vector).
% Graph arms: the context graph of the same causal observation.
if strcmp(mode,'baseline')
    state = observation;
elseif ismember(mode,{'context_flat','context_node_pool','context_gat','context_rgat'})
    state = landing2d.graphstate.environmentGraph(env,c,observation);
else
    error('landing2d:V2StateMode','V2 rollout does not accept legacy graph mode %s.',mode);
end
end

function out = defaults(in,base)
out = base; keys = fieldnames(in);
for i = 1:numel(keys), out.(keys{i}) = in.(keys{i}); end
end

function log = initializeLog(n,env)
fields = {'time','xDrone','zDrone','vxDrone','vzDrone','theta','pitchRate', ...
    'xPad','vxPad','visible','supervisor'};
if isfield(env.physicalState,'y')
    fields = [fields,{'yDrone','vyDrone','roll','rollRate','yPad','vyPad'}];
end
for i = 1:numel(fields), log.(fields{i}) = zeros(1,n); end
log = appendLog(log,1,env,struct('supervisorIntervened',false));
end

function log = appendLog(log,k,env,info)
log.time(k)=env.time; log.xDrone(k)=env.physicalState.x;
log.zDrone(k)=env.physicalState.z; log.vxDrone(k)=env.physicalState.vx;
log.vzDrone(k)=env.physicalState.vz; log.theta(k)=env.physicalState.theta;
log.pitchRate(k)=env.physicalState.pitchRate; log.xPad(k)=env.pad.x;
log.vxPad(k)=env.pad.vx; log.visible(k)=visionAvailable(env);
log.supervisor(k)=info.supervisorIntervened;
if isfield(log,'yDrone')
    s=env.physicalState;
    log.yDrone(k)=s.y; log.vyDrone(k)=s.vy; log.roll(k)=s.roll;
    log.rollRate(k)=s.rollRate; log.yPad(k)=env.pad.y; log.vyPad(k)=env.pad.vy;
end
end

function visible = visionAvailable(env)
% Measured visibility of the perception the policy and supervisor use: the
% planar marker-camera vision update, otherwise the tracker detection (3D).
if isfield(env,'commonObservation') && ~isempty(env.commonObservation)
    visible = env.commonObservation.ugv.visionUpdated;
else
    visible = env.measurement.detected;
end
end

function t = terminalTime(env,reason)
if strcmp(env.episodeStatus.terminalReason,reason), t=env.time; else, t=NaN; end
end

function t = failureTime(env)
if env.episodeStatus.terminated && ~strcmp(env.episodeStatus.terminalReason,'SUCCESS')
    t=env.time;
else
    t=NaN;
end
end
