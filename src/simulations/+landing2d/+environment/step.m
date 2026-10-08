function [env,observation,reward,terminated,truncated,info] = step(env,aNorm)
% STEP  Hold one two-axis policy action until next decision or earliest event.
% The 3D option holds a three-axis action [a_x,a_y,a_z] with the same timing.
% info.physics logs every physics substep: the supervisor-applied command,
% the supervisor reason code, and the realized body acceleration of the
% lagged dynamics (evaluation truth; it is not the commanded acceleration).
% info.appliedAccelerationIntervalMean is the time average of the applied
% command over the decision interval, not a high-rate executed command.
assert(~env.episodeStatus.terminated && ~env.episodeStatus.truncated, ...
    'landing2d:StepAfterTerminal','Policy/environment work after terminal is forbidden.');
c = env.config; e = c.experiment;
spatial = landing2d.environment.isSpatial(c);
limits = landing2d.environment.actionLimits(c);
validateattributes(aNorm,{'numeric'},{'real','finite','vector','numel',numel(limits)});
aNorm = min(max(aNorm(:),-1),1);
requested = limits.*aNorm;
startTime = env.time;
decisionStartState = env.physicalState;
decisionStartPad = env.pad;
event = struct('occurred',false,'reason','','time',startTime+e.policyDt);
supervisorIntervened = false; supervisorReasons = {};
appliedIntegral = zeros(numel(limits),1);
elapsed = 0; dynamicsInfo = struct('hardEnvelopeViolation',false);
lastEstimatorInfo = struct();
% Planar runs with the common observation: the supervisor and landing
% authorization use the decision-rate marker-camera UGV estimate (held and
% predicted between camera frames). Otherwise they use the 100-Hz tracker.
perception = ~isempty(env.commonMemory);
% Decision k of this step (k = 0 was reset); time-indexed noise column k+1.
decision = env.stepCount+1;
capacity = round(e.policyDt/e.physicsDt)+2;
if perception
    capacity = size(env.noise.tracker,2);
    assert(decision+1 <= size(env.noise.marker,4),'landing2d:NoiseTable', ...
        'Decision %d exceeds the time-indexed noise table.',decision);
end
physics = struct('time',zeros(1,capacity),'dt',zeros(1,capacity), ...
    'appliedAcceleration',zeros(numel(limits),capacity), ...
    'actualAcceleration',zeros(numel(limits),capacity), ...
    'supervisorIntervened',false(1,capacity),'supervisorReasonCode',zeros(1,capacity,'uint8'));
substep = 0;
while elapsed < e.policyDt-1e-12 && ~event.occurred
    substep = substep+1;
    assert(substep <= capacity,'landing2d:PhysicsSubsteps', ...
        'A decision interval exceeded %d physics substeps.',capacity);
    dt = min([e.physicsDt,e.policyDt-elapsed,env.scenario.deadline-env.time]);
    previous = env.physicalState;
    padPrevious = env.pad;
    if perception
        supervisorInput = landing2d.environment.perceptionView(env.commonObservation, ...
            previous,env.episodeStatus,env.time,env.scenario,c);
    else
        supervisorInput = landing2d.sensing.buildPacket(previous,env.observationMemory, ...
            env.measurement,env.episodeStatus,env.scenario,env.time,c);
    end
    if isfield(e,'actionApplication') ...
            && strcmp(e.actionApplication,'direct_policy_v1')
        applied = requested;
        supervisor = struct('intervened',false,'reasons',{{}}, ...
            'stoppingHeight',NaN,'availableVerticalBrake',NaN);
    else
        [applied,supervisor] = landing2d.control.safetySupervisor( ...
            requested,previous,supervisorInput,c);
    end
    supervisorIntervened = supervisorIntervened || supervisor.intervened;
    supervisorReasons = union(supervisorReasons,supervisor.reasons,'stable');
    pitchDisturbance = 0;
    if env.time >= env.sensorEvents.pitchStart && env.time < env.sensorEvents.pitchEnd
        pitchDisturbance = env.sensorEvents.pitchRate*dt;
    end
    if spatial
        [current,dynamicsInfo] = landing2d.dynamics.stepSpatial( ...
            previous,applied,dt,e.dynamics,pitchDisturbance);
    else
        [current,dynamicsInfo] = landing2d.dynamics.stepPlanar( ...
            previous,applied,dt,e.dynamics,pitchDisturbance);
    end
    nextTime = env.time+dt;
    padCurrent = landing2d.scenario.padState(env.scenario,nextTime);
    % Contact/hard-boundary events are resolved before creating a measurement
    % at the end of the physics step. This prevents post-impact information
    % from entering observation memory.
    event = landing2d.environment.evaluateTermination(previous,current, ...
        padPrevious,padCurrent,env.episodeStatus,env.time,dt,c,dynamicsInfo);
    measurement = env.measurement;
    track = env.observationMemory;
    status = env.episodeStatus;
    if event.occurred && event.physicalContact && event.alpha < 1
        current = interpolatePhysical(previous,current,event.alpha);
        padCurrent = landing2d.scenario.padState(env.scenario,event.time);
    elseif ~event.occurred
        sensorEvent = struct('dropout',nextTime>=env.sensorEvents.dropoutStart ...
            && nextTime<env.sensorEvents.dropoutEnd);
        trackerNoise = env.sensorStream;
        if perception, trackerNoise = env.noise.tracker(:,substep,decision+1); end
        measurement = landing2d.sensing.generateMeasurement(current,padCurrent, ...
            nextTime,e.sensor,trackerNoise,sensorEvent);
        [track,lastEstimatorInfo] = landing2d.sensing.updatePadTrack( ...
            env.observationMemory,measurement,current,nextTime,e.sensor);
        if ~perception
            status = landing2d.environment.updateDecisionContext( ...
                env.episodeStatus,track,nextTime,c,current);
        end
        event = landing2d.environment.evaluateTermination(previous,current, ...
            padPrevious,padCurrent,status,env.time,dt,c,dynamicsInfo);
    end
    actualDt = dt;
    if event.occurred, actualDt = event.time-env.time; end
    appliedIntegral = appliedIntegral+applied*actualDt;
    elapsed = elapsed+actualDt;
    env.time = env.time+actualDt;
    physics.time(substep) = env.time;
    physics.dt(substep) = actualDt;
    physics.appliedAcceleration(:,substep) = applied;
    physics.actualAcceleration(:,substep) = dynamicsInfo.actualAcceleration;
    physics.supervisorIntervened(substep) = supervisor.intervened;
    physics.supervisorReasonCode(substep) = ...
        landing2d.control.supervisorReasonCode(supervisor.reasons);
    env.physicalState = current;
    env.pad = padCurrent;
    env.measurement = measurement;
    env.observationMemory = track;
    env.episodeStatus = status;
    if supervisor.intervened
        env.episodeStatus.supervisorDuration = ...
            env.episodeStatus.supervisorDuration+actualDt;
    end
end
if event.occurred
    env.episodeStatus.terminated = true;
    env.episodeStatus.terminalReason = event.reason;
    env.episodeStatus.physicalContact = event.physicalContact;
    env.episodeStatus.contactAuthorized = event.authorized;
    env.episodeStatus.mechanicallySafeContact = event.mechanicallySafe;
    env.episodeStatus.contact = event.preImpact;
    if strcmp(event.reason,'SAFE_ABORT')
        env.episodeStatus.abortCompletionTime = event.time;
    end
end
perceptionError = [];
if perception
    % Decision-rate camera frame and navigation fix. A terminal event leaves no
    % new image, as the packet path keeps post-impact information out of memory.
    frameEvent = struct('dropout',env.time>=env.sensorEvents.dropoutStart ...
        && env.time<env.sensorEvents.dropoutEnd,'frameCaptured',~event.occurred);
    detections = landing2d.sensing.detectMarkers(env.physicalState,env.pad, ...
        env.time,e.sensor,e.commonObservation,env.noise.marker(:,:,:,decision+1),frameEvent);
    navigation = landing2d.sensing.navigationEstimate(env.physicalState,env.time, ...
        e.commonObservation.navigation,env.noise.navigation(:,decision+1));
    [env.commonObservation,env.commonMemory] = landing2d.observation.capture( ...
        env.commonMemory,detections,navigation,env.time,env.observationContext);
    perceptionError = landing2d.metrics.perceptionError(env.commonObservation, ...
        env.pad,env.observationContext);
    if ~event.occurred
        [~,perceptionTrack] = landing2d.environment.perceptionView( ...
            env.commonObservation,env.physicalState,env.episodeStatus, ...
            env.time,env.scenario,c);
        env.episodeStatus = landing2d.environment.updateDecisionContext( ...
            env.episodeStatus,perceptionTrack,env.time,c,env.physicalState);
    end
end
previousNormalizedAction = env.episodeStatus.previousNormalizedAction;
env.episodeStatus.previousNormalizedAction = aNorm;
env.decisionContext = env.episodeStatus;
env.stepCount = env.stepCount+1;
packet = landing2d.sensing.buildPacket(env.physicalState, ...
    env.observationMemory,env.measurement,env.episodeStatus, ...
    env.scenario,env.time,c);
% Policy observation: the normalized 12-D common observation in the planar
% contract; the normalized causal packet otherwise (3D option, old configs).
if perception
    observation = landing2d.observation.toVector(env.commonObservation, ...
        env.observationContext);
else
    observation = landing2d.sensing.normalizePacket(packet,c);
end
previousTruth = struct('ex',decisionStartPad.x-decisionStartState.x, ...
    'h',decisionStartState.z-decisionStartPad.z, ...
    'relativeVx',decisionStartPad.vx-decisionStartState.vx, ...
    'vz',decisionStartState.vz,'theta',decisionStartState.theta, ...
    'pitchRate',decisionStartState.pitchRate);
truth = struct('ex',env.pad.x-env.physicalState.x, ...
    'h',env.physicalState.z-env.pad.z, ...
    'relativeVx',env.pad.vx-env.physicalState.vx, ...
    'vz',env.physicalState.vz,'theta',env.physicalState.theta, ...
    'pitchRate',env.physicalState.pitchRate);
if spatial
    previousTruth = addLateralTruth(previousTruth,decisionStartState,decisionStartPad);
    truth = addLateralTruth(truth,env.physicalState,env.pad);
end
[reward,rewardComponents] = landing2d.rl.computeReward(previousTruth,truth, ...
    env.measurement,aNorm,elapsed,event,c,previousNormalizedAction);
if event.occurred
    assert(~env.episodeStatus.terminalRewardPaid, ...
        'landing2d:DuplicateTerminalReward','Terminal reward paid twice.');
    env.episodeStatus.terminalRewardPaid = true;
end
env.rewardSum = env.rewardSum+reward;
env.packet = packet;
terminated = env.episodeStatus.terminated;
truncated = false;
names = {'time','dt','appliedAcceleration','actualAcceleration', ...
    'supervisorIntervened','supervisorReasonCode'};
for i = 1:numel(names), physics.(names{i}) = physics.(names{i})(:,1:substep); end
info = struct('packet',packet,'commonObservation',env.commonObservation, ...
    'perceptionError',perceptionError,'requestedAcceleration',requested, ...
    'appliedAccelerationIntervalMean',appliedIntegral/max(elapsed,eps), ...
    'decisionIndex',decision,'startTime',startTime,'physics',physics, ...
    'normalizedAction',aNorm,'dt',elapsed,'event',event, ...
    'rewardComponents',rewardComponents,'supervisorIntervened', ...
    supervisorIntervened,'supervisorReasons',{supervisorReasons}, ...
    'dynamics',dynamicsInfo,'estimator',lastEstimatorInfo, ...
    'terminated',terminated,'truncated',truncated);
end

function out=interpolatePhysical(a,b,q)
out=a;
names={'x','z','vx','vz','theta','pitchRate','collectiveThrust'};
if isfield(a,'y'), names=[names,{'y','vy','roll','rollRate'}]; end
for i=1:numel(names)
    name=names{i}; out.(name)=a.(name)+q*(b.(name)-a.(name));
end
end

function truth=addLateralTruth(truth,state,pad)
% Reward-only truth (never a policy input), 3D option.
truth.ey=pad.y-state.y;
truth.relativeVy=pad.vy-state.vy;
truth.roll=state.roll;
truth.rollRate=state.rollRate;
end
