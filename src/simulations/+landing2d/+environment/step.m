function [env,observation,reward,terminated,truncated,info] = step(env,aNorm)
% STEP  Hold one two-axis policy action until next decision or earliest event.
% The 3D option holds a three-axis action [a_x,a_y,a_z] with the same timing.
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
while elapsed < e.policyDt-1e-12 && ~event.occurred
    dt = min([e.physicsDt,e.policyDt-elapsed,env.scenario.deadline-env.time]);
    previous = env.physicalState;
    padPrevious = env.pad;
    packet = landing2d.sensing.buildPacket(previous,env.observationMemory, ...
        env.measurement,env.episodeStatus,env.scenario,env.time,c);
    [applied,supervisor] = landing2d.control.safetySupervisor( ...
        requested,previous,packet,c);
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
        measurement = landing2d.sensing.generateMeasurement(current,padCurrent, ...
            nextTime,e.sensor,env.sensorStream,sensorEvent);
        [track,lastEstimatorInfo] = landing2d.sensing.updatePadTrack( ...
            env.observationMemory,measurement,current,nextTime,e.sensor);
        status = landing2d.environment.updateDecisionContext( ...
            env.episodeStatus,track,nextTime,c,current);
        event = landing2d.environment.evaluateTermination(previous,current, ...
            padPrevious,padCurrent,status,env.time,dt,c,dynamicsInfo);
    end
    actualDt = dt;
    if event.occurred, actualDt = event.time-env.time; end
    appliedIntegral = appliedIntegral+applied*actualDt;
    elapsed = elapsed+actualDt;
    env.time = env.time+actualDt;
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
previousNormalizedAction = env.episodeStatus.previousNormalizedAction;
env.episodeStatus.previousNormalizedAction = aNorm;
env.decisionContext = env.episodeStatus;
env.stepCount = env.stepCount+1;
packet = landing2d.sensing.buildPacket(env.physicalState, ...
    env.observationMemory,env.measurement,env.episodeStatus, ...
    env.scenario,env.time,c);
observation = landing2d.sensing.normalizePacket(packet,c);
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
info = struct('packet',packet,'requestedAcceleration',requested, ...
    'appliedAcceleration',appliedIntegral/max(elapsed,eps), ...
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
