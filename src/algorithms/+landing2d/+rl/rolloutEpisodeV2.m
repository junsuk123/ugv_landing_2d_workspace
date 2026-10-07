function [result,traj] = rolloutEpisodeV2(agent,c,seed,opts)
% ROLLOUTEPISODEV2  PPO rollout through the versioned reset/step contract.
if nargin < 4, opts = struct(); end
opts = defaults(opts,struct('deterministic',false,'collect',true, ...
    'rs',[],'maxDecisions',Inf,'traceGraph',false, ...
    'scenarioHeightRange',[],'scenario',[],'sensorEvents',[]));
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
[env,observation,resetInfo] = landing2d.environment.reset(c,seed,resetOptions);
capacity = min(ceil(env.scenario.deadline/c.experiment.policyDt)+1, ...
    opts.maxDecisions);
if ~isfinite(capacity), capacity = ceil(env.scenario.deadline/c.experiment.policyDt)+1; end
stateDim = agent.encoderSpec.stateDim;
traj = struct('observation',zeros(c.rl.observationDim,capacity), ...
    'state',zeros(stateDim,capacity),'nextObservation',zeros(c.rl.observationDim,capacity), ...
    'command',zeros(c.rl.actionDim,capacity),'normalizedAction',zeros(c.rl.actionDim,capacity), ...
    'requestedAcceleration',zeros(c.rl.actionDim,capacity), ...
    'appliedAcceleration',zeros(c.rl.actionDim,capacity), ...
    'logProbability',zeros(1,capacity),'value',zeros(1,capacity), ...
    'baseMean',zeros(c.rl.actionDim,capacity), ...
    'relationResidual',zeros(c.rl.actionDim,capacity), ...
    'descentEligibility',ones(1,capacity), ...
    'verticalGateActive',false(1,capacity), ...
    'reward',zeros(1,capacity),'rewardComponents',{cell(1,capacity)}, ...
    'terminated',false(1,capacity),'truncated',false(1,capacity), ...
    'discount',zeros(1,capacity),'dt',zeros(1,capacity), ...
    'safetyIntervened',false(1,capacity),'count',0,'bootstrap',0, ...
    'captureRate',0,'return',0,'graphValues',[],'graphStates',[]);
log = initializeLog(capacity+1,env);
detections = 0;
while ~env.episodeStatus.terminated && traj.count < capacity
    state = policyState(observation,env.packet,c,agent.encoderSpec.mode);
    [u,logProbability,~,policyDetail] = landing2d.rl.policyAction(agent,state,opts.rs, ...
        opts.deterministic);
    aNorm = tanh(u);
    value = landing2d.rl.valueForward(agent,state);
    [env,nextObservation,reward,terminated,truncated,stepInfo] = ...
        landing2d.environment.step(env,aNorm);
    k = traj.count+1;
    traj.count = k;
    traj.observation(:,k) = observation;
    traj.state(:,k) = state;
    traj.nextObservation(:,k) = nextObservation;
    traj.command(:,k) = u;
    traj.normalizedAction(:,k) = aNorm;
    traj.requestedAcceleration(:,k) = stepInfo.requestedAcceleration;
    traj.appliedAcceleration(:,k) = stepInfo.appliedAcceleration;
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
    detections = detections+double(env.packet.detected);
    log = appendLog(log,k+1,env,stepInfo);
    observation = nextObservation;
end
if ~env.episodeStatus.terminated && traj.count >= capacity
    traj.truncated(traj.count) = true;
    finalState = policyState(observation,env.packet,c,agent.encoderSpec.mode);
    traj.bootstrap = landing2d.rl.valueForward(agent,finalState);
    env.episodeStatus.truncated = true;
else
    traj.bootstrap = 0;
end
n = traj.count;
matrixFields = {'observation','state','nextObservation','command', ...
    'normalizedAction','requestedAcceleration','appliedAcceleration', ...
    'baseMean','relationResidual'};
rowFields = {'logProbability','value','reward','terminated','truncated', ...
    'discount','dt','safetyIntervened','descentEligibility','verticalGateActive'};
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
    'resetInfo',resetInfo,'policyDiagnostics',policyDiagnostics(traj));
if isfield(log,'yDrone')
    % 3D option: lateral/roll trajectory alongside the planar fields.
    for name={'yDrone','vyDrone','roll','rollRate','yPad','vyPad'}
        result.(name{1})=log.(name{1})(1:n+1);
    end
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

function state = policyState(observation,packet,c,mode)
if strcmp(mode,'baseline')
    state = observation;
elseif ismember(mode,{'context_flat','context_node_pool','context_gat','context_rgat'})
    state = landing2d.graphstate.contextGraph(packet,c);
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
log.vxPad(k)=env.pad.vx; log.visible(k)=env.measurement.detected;
log.supervisor(k)=info.supervisorIntervened;
if isfield(log,'yDrone')
    s=env.physicalState;
    log.yDrone(k)=s.y; log.vyDrone(k)=s.vy; log.roll(k)=s.roll;
    log.rollRate(k)=s.rollRate; log.yPad(k)=env.pad.y; log.vyPad(k)=env.pad.vy;
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
