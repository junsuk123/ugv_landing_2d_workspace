function [result,traj,gainInfo] = rollout(agent,c,seed,gain,opts)
% ROLLOUT Deterministic landing2d.rl.rolloutEpisodeV2 with a horizontal command gain.
% Identical loop (policy input -> policyAction -> tanh -> environment.step) and
% result/traj fields (no command log); the only change is, at every decision,
%   normalizedAction(1) = clip(gain * tanh(mu_x), -1, 1)      normalizedAction(2) = tanh(mu_z)
% gain = 1 is the identity (bit-identical to rolloutEpisodeV2, checked in
% selfTest). The policy, its parameters and its inputs are not changed.
% gainInfo: decisions whose gain * tanh(mu_x) left [-1,1] (clipped), decisions
% with |applied a_x| > saturation (applied in [-1,1]), mean |requested a_x|.
if nargin < 5, opts = struct(); end
opts = defaults(opts,struct('rs',[],'sensorNoiseScale',[],'saturation',0.95));
if isempty(opts.rs)
    opts.rs = RandStream('threefry','Seed',c.experiment.scenario.baseSeed+ ...
        c.experiment.randomStreams.policyOffset+double(seed));
end
resetOptions = struct();
if ~isempty(opts.sensorNoiseScale), resetOptions.sensorNoiseScale = opts.sensorNoiseScale; end
[env,observation,resetInfo] = landing2d.environment.reset(c,seed,resetOptions);
capacity = ceil(env.scenario.deadline/c.experiment.policyDt)+1;
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
truthLog = initializeLog(capacity+1,env);
markerUpdateCount = 0; clipped = 0; saturated = 0;
while ~env.episodeStatus.terminated && traj.count < capacity
    policyInput = buildPolicyInput(observation,env,c,agent.encoderSpec.mode);
    landingInhibited = env.episodeStatus.landingInhibited;
    decisionTime = env.time;
    [preTanhAction,logProbability,mu] = landing2d.rl.policyAction(agent,policyInput, ...
        opts.rs,true);
    normalizedAction = tanh(preTanhAction);
    scaled = gain*normalizedAction(1);
    clipped = clipped+double(abs(scaled)>1);
    normalizedAction(1) = min(max(scaled,-1),1);
    saturated = saturated+double(abs(normalizedAction(1))>opts.saturation);
    value = landing2d.rl.valueForward(agent,policyInput);
    [env,nextObservation,reward,terminated,truncated,stepInfo] = ...
        landing2d.environment.step(env,normalizedAction);
    k = traj.count+1;
    traj.count = k;
    traj.time(k) = decisionTime;
    traj.observation(:,k) = observation;
    traj.state(:,k) = policyInput;
    traj.nextObservation(:,k) = nextObservation;
    traj.command(:,k) = preTanhAction;
    traj.actorMean(:,k) = mu;
    traj.normalizedAction(:,k) = normalizedAction;
    traj.requestedAcceleration(:,k) = stepInfo.requestedAcceleration;
    traj.appliedAccelerationIntervalMean(:,k) = stepInfo.appliedAccelerationIntervalMean;
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
    markerUpdateCount = markerUpdateCount+double(visionUpdated(env));
    truthLog = appendLog(truthLog,k+1,env,stepInfo);
    observation = nextObservation;
end
if ~env.episodeStatus.terminated && traj.count >= capacity
    traj.truncated(traj.count) = true;
    finalPolicyInput = buildPolicyInput(observation,env,c,agent.encoderSpec.mode);
    traj.bootstrap = landing2d.rl.valueForward(agent,finalPolicyInput);
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
traj.captureRate = markerUpdateCount/max(n,1);
result = struct('schemaVersion','rollout_result_v2','seed',seed, ...
    'scenario',env.scenario,'status',env.episodeStatus.terminalReason, ...
    'terminated',env.episodeStatus.terminated,'truncated',env.episodeStatus.truncated, ...
    'return',traj.return,'captureRate',traj.captureRate,'time',truthLog.time(1:n+1), ...
    'xDrone',truthLog.xDrone(1:n+1),'zDrone',truthLog.zDrone(1:n+1), ...
    'vxDrone',truthLog.vxDrone(1:n+1),'vzDrone',truthLog.vzDrone(1:n+1), ...
    'theta',truthLog.theta(1:n+1),'pitchRate',truthLog.pitchRate(1:n+1), ...
    'xPad',truthLog.xPad(1:n+1),'vxPad',truthLog.vxPad(1:n+1), ...
    'visible',truthLog.visible(1:n+1),'supervisor',truthLog.supervisor(1:n+1), ...
    'terminalReason',env.episodeStatus.terminalReason, ...
    'landingTime',terminalTime(env,'SUCCESS'),'failureTime',failureTime(env), ...
    'contact',env.episodeStatus.contact, ...
    'resetInfo',resetInfo,'commandLog',[]);
gainInfo = struct('Gain',gain,'ClippedFraction',clipped/max(n,1), ...
    'SaturatedFraction',saturated/max(n,1), ...
    'MeanAbsRequestedAx_mps2',mean(abs(traj.requestedAcceleration(1,:))));
end

function policyInput = buildPolicyInput(observation,env,c,mode)
if strcmp(mode,'baseline')
    policyInput = observation;
else
    policyInput = landing2d.graphstate.environmentGraph(env,c,observation);
end
end

function out = defaults(in,base)
out = base; keys = fieldnames(in);
for i = 1:numel(keys), out.(keys{i}) = in.(keys{i}); end
end

function truthLog = initializeLog(n,env)
fields = {'time','xDrone','zDrone','vxDrone','vzDrone','theta','pitchRate', ...
    'xPad','vxPad','visible','supervisor'};
for i = 1:numel(fields), truthLog.(fields{i}) = zeros(1,n); end
truthLog = appendLog(truthLog,1,env,struct('supervisorIntervened',false));
end

function truthLog = appendLog(truthLog,k,env,info)
truthLog.time(k)=env.time; truthLog.xDrone(k)=env.physicalState.x;
truthLog.zDrone(k)=env.physicalState.z; truthLog.vxDrone(k)=env.physicalState.vx;
truthLog.vzDrone(k)=env.physicalState.vz; truthLog.theta(k)=env.physicalState.theta;
truthLog.pitchRate(k)=env.physicalState.pitchRate; truthLog.xPad(k)=env.pad.x;
truthLog.vxPad(k)=env.pad.vx; truthLog.visible(k)=visionUpdated(env);
truthLog.supervisor(k)=info.supervisorIntervened;
end

function updated = visionUpdated(env)
updated = env.commonObservation.ugv.visionUpdated;
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
