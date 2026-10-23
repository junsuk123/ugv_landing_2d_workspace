function decisionTrace = recordEpisode(agent,c,seed,opts)
% RECORDEPISODE  One closed-loop episode with a read-only decision trace.
%   trace = landing2d.trace.recordEpisode(agent,c,seed,opts)
% The loop is the loop of landing2d.rl.rolloutEpisodeV2 (reset, TOSM graph of
% the returned o_t, policyAction with the episode's own random stream,
% valueForward, step), with the same calls in the same order, so actions,
% observations, rewards and outcome are those of the evaluation rollout
% (landing2d.trace.selfTest compares the two bit for bit). Around it the trace
% reads, without changing anything:
%   - the decision-time sensing chain (landing2d.trace.decisionSensing,
%     replay asserted identical to the environment observation)
%   - the node features X_t and semantic evidence of the same o_t
%   - the Actor R-GAT caches, readout and MLP (landing2d.trace.actorForward,
%     mean asserted identical to landing2d.rl.policyAction) and the Critic
%   - the requested / interval-applied command and, in a separate
%     evaluation-only section, the physical truth (never a policy input)
% opts.deterministic (default true, as in evaluation), opts.rs (default the
% rollout's policy stream), opts.scenario / sensorEvents / sensorNoiseScale
% (fixed cases), opts.onStart (called once with the trace skeleton - schema,
% provenance, context, no records - before the first decision),
% opts.onRecord (called with a copy of every finished decision record, e.g.
% a live dashboard; an error in either callback disables it and never alters
% the episode), opts.identity (provenance fields stored as is).
if nargin < 4, opts = struct(); end
opts = defaults(opts,struct('deterministic',true,'rs',[],'scenario',[], ...
    'sensorEvents',[],'sensorNoiseScale',[],'onStart',[],'onRecord',[], ...
    'identity',struct(),'maxDecisions',Inf));
if isempty(opts.rs)
    opts.rs = RandStream('threefry','Seed',c.experiment.scenario.baseSeed+ ...
        c.experiment.randomStreams.policyOffset+double(seed));
end
assert(strcmp(agent.encoderSpec.mode,'context_rgat'),'landing2d:TraceSchema', ...
    'The decision trace explains the R-GAT Actor; plain PPO has no graph.');
schema = landing2d.trace.graphSchema(agent);
resetOptions = struct();
if ~isempty(opts.scenario), resetOptions.scenario = opts.scenario; end
if ~isempty(opts.sensorEvents), resetOptions.sensorEvents = opts.sensorEvents; end
if ~isempty(opts.sensorNoiseScale), resetOptions.sensorNoiseScale = opts.sensorNoiseScale; end
[env,observation] = landing2d.environment.reset(c,seed,resetOptions);
G = env.observationContext;
sensing = landing2d.trace.decisionSensing(env,landing2d.observation.initialMemory(),false);
provenance = landing2d.trace.provenanceMap(c,G,env.commonObservation);
capacity = min(ceil(env.scenario.deadline/c.experiment.policyDt)+1,opts.maxDecisions);
limits = landing2d.environment.actionLimits(c);
records = cell(1,capacity);
callback = opts.onRecord; callbackError = '';
identity = opts.identity;
identity.episodeSeed = seed;
identity.deterministic = opts.deterministic;
identity.recordedAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
if ~isempty(opts.onStart)
    skeleton = assemble(identity,schema,provenance,c,G,limits,env,[], ...
        struct('terminated',false,'truncated',false,'reason','','time',env.time, ...
        'sensing',sensing,'returnSum',0,'decisions',0),'');
    try
        opts.onStart(skeleton);
    catch err
        callbackError = err.message; callback = [];
    end
end
k = 0;
while ~env.episodeStatus.terminated && k < capacity
    [policyInput,graphDetail] = landing2d.graphstate.environmentGraph(env,c,observation);
    decisionTime = env.time;
    truth = truthAt(env);
    forward = landing2d.trace.actorForward(agent,policyInput);
    [preTanhAction,logProbability,mu] = landing2d.rl.policyAction(agent,policyInput, ...
        opts.rs,opts.deterministic);
    normalizedAction = tanh(preTanhAction);
    value = landing2d.rl.valueForward(agent,policyInput);
    assert(isequal(mu,forward.mu) && isequal(value,forward.value),'landing2d:TraceForward', ...
        'The traced Actor/Critic forward differs from the policy at t = %.2f s.',decisionTime);
    memoryBefore = env.commonMemory;
    [env,nextObservation,reward,terminated,~,stepInfo] = ...
        landing2d.environment.step(env,normalizedAction);
    k = k+1;
    record = struct('decisionIndex',k,'time',decisionTime,'sensing',sensing, ...
        'observation',observation,'policyInput',policyInput, ...
        'graph',struct('X',graphDetail.X,'semanticEvidence',graphDetail.semanticEvidence, ...
            'estimate',estimateValues(sensing.observation,G), ...
            'featureVersion',graphDetail.featureVersion), ...
        'actor',actorSection(forward,preTanhAction,mu,normalizedAction,logProbability, ...
            opts.deterministic), ...
        'critic',struct('g',forward.criticG,'value',value), ...
        'command',struct('requestedAcceleration',stepInfo.requestedAcceleration, ...
            'appliedAccelerationIntervalMean',stepInfo.appliedAccelerationIntervalMean, ...
            'actionLimits',limits), ...
        'step',struct('reward',reward,'terminated',terminated,'dt',stepInfo.dt, ...
            'endTime',env.time,'eventReason',stepInfo.event.reason), ...
        'evaluation',struct('truth',truth,'injectedDropout',sensing.evaluation.injectedDropout, ...
            'realizedAccelerationMean',mean(stepInfo.physics.actualAcceleration,2), ...
            'aimError',landing2d.evaluation.aimError(truth.padX,truth.droneX, ...
                truth.droneZ-truth.padZ,c)));
    records{k} = record;
    if ~isempty(callback)
        try
            callback(record);
        catch err
            callbackError = err.message; callback = [];
        end
    end
    sensing = landing2d.trace.decisionSensing(env,memoryBefore,stepInfo.event.occurred);
    observation = nextObservation;
end
truncated = ~env.episodeStatus.terminated && k >= capacity;
records = [records{1:k}];
terminal = struct('terminated',env.episodeStatus.terminated,'truncated',truncated, ...
    'reason',char(env.episodeStatus.terminalReason),'time',env.time, ...
    'sensing',sensing,'returnSum',env.rewardSum,'decisions',k);
decisionTrace = assemble(identity,schema,provenance,c,G,limits,env,records,terminal,callbackError);
end

function decisionTrace = assemble(identity,schema,provenance,c,G,limits,env,records,terminal,callbackError)
% One layout for the skeleton (onStart) and the finished trace.
decisionTrace = struct('schemaVersion','decision_trace_v1','identity',identity, ...
    'schema',schema,'provenance',provenance,'labels',landing2d.trace.labels(), ...
    'context',contextSection(c,G,limits),'scenario',env.scenario, ...
    'evaluationOnly',struct('sensorEvents',env.sensorEvents, ...
        'note','외부 주입 사건 일정은 평가 전용 정보이며 정책 입력이 아님'), ...
    'records',records,'terminal',terminal,'callbackError',callbackError);
decisionTrace.events = landing2d.trace.buildEvents(decisionTrace);
end

function A = actorSection(F,preTanhAction,mu,normalizedAction,logProbability,deterministic)
A = rmfield(F,{'criticG','value','consistency'});
A.mu = mu;
A.preTanhAction = preTanhAction;
A.normalizedAction = normalizedAction;
A.deterministicPreview = tanh(mu);
A.sampled = ~deterministic;
A.logProbability = logProbability;
A.consistency = F.consistency;
end

function E = estimateValues(O,G)
% Policy-visible estimates in physical units (the values behind o_t), NaN
% where the UGV estimate is not initialized.
E = struct('relativeX',NaN,'height',NaN,'relativeVx',NaN,'ugvVx',NaN, ...
    'droneVz',O.drone.velocityXZ(2), ...
    'theta',atan2(O.drone.pitchSinCos(1),O.drone.pitchSinCos(2)), ...
    'pitchRate',O.drone.pitchRate,'visionAge',O.ugv.visionAge, ...
    'navigationAge',O.drone.navigationAge,'estimateInitialized',O.ugv.estimateInitialized);
if O.ugv.estimateInitialized
    E.relativeX = O.ugv.positionXZ(1)-O.drone.positionXZ(1);
    E.height = O.drone.positionXZ(2)-(O.ugv.positionXZ(2)+G.ugv.padOffset(2));
    E.relativeVx = O.ugv.velocityXZ(1)-O.drone.velocityXZ(1);
    E.ugvVx = O.ugv.velocityXZ(1);
end
end

function t = truthAt(env)
% Evaluation-only physical truth at the decision time (not a policy input).
s = env.physicalState; p = env.pad;
t = struct('droneX',s.x,'droneZ',s.z,'droneVx',s.vx,'droneVz',s.vz, ...
    'theta',s.theta,'pitchRate',s.pitchRate,'padX',p.x,'padZ',p.z,'padVx',p.vx);
end

function C = contextSection(c,G,limits)
e = c.experiment;
C = struct('policyDt',e.policyDt,'physicsDt',e.physicsDt,'actionLimits',limits(:)', ...
    'fov',e.sensor.fov,'cameraPitchOffset',e.sensor.cameraPitchOffset, ...
    'aimSlope',tan(-e.sensor.cameraPitchOffset), ...
    'touchdown',struct('position',e.safety.touchdownPositionTolerance, ...
        'speedX',e.safety.touchdownSpeedX,'speedZ',e.safety.touchdownSpeedZ, ...
        'pitch',e.safety.touchdownPitchTolerance,'pitchRate',e.safety.touchdownPitchRateTolerance), ...
    'normalization',G.normalization,'padOffset',G.ugv.padOffset(:)', ...
    'observationNames',{landing2d.observation.vectorSchema(G).names}, ...
    'markerIds',G.pad.markerIds,'imageSize',G.camera.imageSize);
end

function out = defaults(in,base)
out = base; keys = fieldnames(in);
for i = 1:numel(keys), out.(keys{i}) = in.(keys{i}); end
end
