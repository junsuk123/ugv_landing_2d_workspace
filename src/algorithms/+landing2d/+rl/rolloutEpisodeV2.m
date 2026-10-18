function [result,traj] = rolloutEpisodeV2(agent,c,seed,opts)
% ROLLOUTEPISODEV2  PPO rollout through the versioned reset/step contract.
% traj.time are the policy decision timestamps; traj.actorMean is the
% pre-tanh actor mean (diagnostic; equals traj.command in deterministic runs);
% traj.requestedAcceleration is tanh(command) times the axis limits before the
% supervisor; traj.appliedAccelerationIntervalMean is the decision-interval
% average of the supervisor-applied command (not a high-rate command).
% result.contact is the evaluation-only pre-impact state of a contact
% termination (xError, relativeVx, relativeVz, pitch, pitchRate; empty struct
% otherwise). opts.commandLog = true adds result.commandLog (landing2d.rl.rolloutEpisodeV2
% local buildCommandLog): policy input/output, decision context, per-physics-
% step applied commands and supervisor reasons, evaluation-only truth (actual
% body acceleration, perception error) and the exogenous manifest, kept in
% separate sections. opts.run / opts.configHash identify the policy and the
% resolved configuration; opts.sensorNoiseScale scales planar sensor noise;
% opts.scenario / opts.sensorEvents replace the sampled ones (fixed cases).
if nargin < 4, opts = struct(); end
opts = defaults(opts,struct('deterministic',false,'collect',true, ...
    'rs',[],'maxDecisions',Inf,'traceGraph',false, ...
    'scenario',[],'sensorEvents',[], ...
    'sensorNoiseScale',[],'commandLog',false,'commandLogStates',false, ...
    'run',struct(),'configHash',''));
if isempty(opts.rs)
    opts.rs = RandStream('threefry','Seed',c.experiment.scenario.baseSeed+ ...
        c.experiment.randomStreams.policyOffset+double(seed));
end
resetOptions = struct();
if ~isempty(opts.scenario), resetOptions.scenario = opts.scenario; end
if ~isempty(opts.sensorEvents), resetOptions.sensorEvents = opts.sensorEvents; end
if ~isempty(opts.sensorNoiseScale), resetOptions.sensorNoiseScale = opts.sensorNoiseScale; end
[env,observation,resetInfo] = landing2d.environment.reset(c,seed,resetOptions);
manifest = struct();
if opts.commandLog, manifest = landing2d.environment.exogenousManifest(env); end
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
    [u,logProbability,mu] = landing2d.rl.policyAction(agent,state,opts.rs, ...
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
    'normalizedAction','requestedAcceleration','appliedAccelerationIntervalMean'};
rowFields = {'time','logProbability','value','reward','terminated','truncated', ...
    'discount','dt','safetyIntervened','landingInhibited'};
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
    'contact',env.episodeStatus.contact, ...
    'resetInfo',resetInfo,'commandLog',[]);
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

function state = policyState(observation,env,c,mode)
% Plain PPO: the 12-D common observation. R-GAT arms: the TOSM graph of it.
if strcmp(mode,'baseline')
    state = observation;
else
    state = landing2d.graphstate.environmentGraph(env,c,observation);
end
end

function out = defaults(in,base)
out = base; keys = fieldnames(in);
for i = 1:numel(keys), out.(keys{i}) = in.(keys{i}); end
end

function log = initializeLog(n,env)
fields = {'time','xDrone','zDrone','vxDrone','vzDrone','theta','pitchRate', ...
    'xPad','vxPad','visible','supervisor'};
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
end

function visible = visionAvailable(env)
% Measured visibility of the marker-camera perception used by the policy.
visible = env.commonObservation.ugv.visionUpdated;
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
