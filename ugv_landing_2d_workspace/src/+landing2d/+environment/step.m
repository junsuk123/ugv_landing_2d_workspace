function [env,observation,reward,terminated,truncated,info] = step(env,aNorm)
% STEP  Hold one two-axis policy action until next decision or earliest event.
assert(~env.episodeStatus.terminated && ~env.episodeStatus.truncated, ...
    'landing2d:StepAfterTerminal','Policy/environment work after terminal is forbidden.');
validateattributes(aNorm,{'numeric'},{'real','finite','vector','numel',2});
c = env.config; e = c.experiment;
aNorm = min(max(aNorm(:),-1),1);
requested = [c.axMax*aNorm(1);c.azMax*aNorm(2)];
startTime = env.time;
event = struct('occurred',false,'reason','','time',startTime+e.policyDt);
supervisorIntervened = false; supervisorReasons = {};
appliedIntegral = zeros(2,1);
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
    [current,dynamicsInfo] = landing2d.dynamics.stepPlanar( ...
        previous,applied,dt,e.dynamics,pitchDisturbance);
    nextTime = env.time+dt;
    [padX,padVx,padAx,phase] = landing2d.scenario.evaluateTrajectory( ...
        env.scenario,nextTime);
    padCurrent = struct('x',padX,'z',env.scenario.padHeight, ...
        'vx',padVx,'ax',padAx,'phase',phase);
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
        [padX,padVx,padAx,phase] = landing2d.scenario.evaluateTrajectory( ...
            env.scenario,event.time);
        padCurrent = struct('x',padX,'z',env.scenario.padHeight, ...
            'vx',padVx,'ax',padAx,'phase',phase);
    elseif ~event.occurred
        sensorEvent = struct('dropout',nextTime>=env.sensorEvents.dropoutStart ...
            && nextTime<env.sensorEvents.dropoutEnd);
        measurement = landing2d.sensing.generateMeasurement(current,padCurrent, ...
            nextTime,e.sensor,env.sensorStream,sensorEvent);
        [track,lastEstimatorInfo] = landing2d.sensing.updatePadTrack( ...
            env.observationMemory,measurement,current,nextTime,e.sensor);
        status = landing2d.environment.updateDecisionContext( ...
            env.episodeStatus,track,nextTime,c);
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
env.episodeStatus.previousNormalizedAction = aNorm;
env.decisionContext = env.episodeStatus;
env.stepCount = env.stepCount+1;
packet = landing2d.sensing.buildPacket(env.physicalState, ...
    env.observationMemory,env.measurement,env.episodeStatus, ...
    env.scenario,env.time,c);
observation = landing2d.sensing.normalizePacket(packet,c);
truth = struct('ex',env.pad.x-env.physicalState.x, ...
    'h',env.physicalState.z-env.pad.z);
[reward,rewardComponents] = landing2d.rl.computeReward(truth, ...
    env.measurement,aNorm,elapsed,event,c);
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
for i=1:numel(names)
    name=names{i}; out.(name)=a.(name)+q*(b.(name)-a.(name));
end
end
