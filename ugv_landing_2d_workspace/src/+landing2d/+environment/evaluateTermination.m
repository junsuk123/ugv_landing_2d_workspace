function event = evaluateTermination(previous,current,padPrevious,padCurrent, ...
    status,t0,dt,c,dynamicsInfo)
% EVALUATETERMINATION  Earliest physical event with pre-impact quantities.
s = c.experiment.safety;
event = blankEvent(t0+dt);
h0 = previous.z-padPrevious.z;
h1 = current.z-padCurrent.z;
contact = h0 > 0 && h1 <= 0;
if contact
    alpha = min(max(h0/max(h0-h1,eps),0),1);
    contactTime = t0+alpha*dt;
    drone = interpolateState(previous,current,alpha);
    padX = padPrevious.x+alpha*(padCurrent.x-padPrevious.x);
    padVx = padPrevious.vx+alpha*(padCurrent.vx-padPrevious.vx);
    ex = padX-drone.x;
    relVx = padVx-drone.vx;
    relVz = -drone.vz;
    inFootprint = abs(ex) <= c.padHalfLength;
    mechanicalSafe = inFootprint && abs(relVx)<=s.touchdownSpeedX ...
        && abs(relVz)<=s.touchdownSpeedZ ...
        && abs(drone.theta)<=s.touchdownPitchTolerance ...
        && abs(drone.pitchRate)<=s.touchdownPitchRateTolerance;
    authorized = ~status.landingInhibited && ~status.abortRequested;
    if ~inFootprint
        reason = 'MISSED_PAD_CONTACT';
    elseif ~authorized
        reason = 'UNAUTHORIZED_CONTACT';
    elseif ~mechanicalSafe
        reason = 'UNSAFE_CONTACT';
    else
        reason = 'SUCCESS';
    end
    event = struct('occurred',true,'reason',reason,'time',contactTime, ...
        'alpha',alpha,'physicalContact',true,'authorized',authorized, ...
        'mechanicallySafe',mechanicalSafe,'preImpact',struct( ...
        'xError',ex,'relativeVx',relVx,'relativeVz',relVz, ...
        'pitch',drone.theta,'pitchRate',drone.pitchRate));
    return;
end
physicalVector = [current.x,current.z,current.vx,current.vz,current.theta, ...
    current.pitchRate,current.collectiveThrust];
hardViolation = dynamicsInfo.hardEnvelopeViolation || current.z > s.ceilingHeight ...
    || current.z < s.minimumHeight-1e-9 || any(~isfinite(physicalVector));
if hardViolation
    event = makeSimple('SAFETY_ENVELOPE_VIOLATION',t0+dt);
    return;
end
if status.abortRequested && current.z-padCurrent.z >= s.abortHoldHeight ...
        && abs(current.vz)<=s.abortVerticalSpeedTolerance
    event = makeSimple('SAFE_ABORT',t0+dt);
    return;
end
deadline = c.experiment.currentScenario.deadline;
if t0+dt >= deadline-1e-12
    event = makeSimple('TASK_TIMEOUT',deadline);
end
end

function event = blankEvent(t)
event = struct('occurred',false,'reason','','time',t,'alpha',1, ...
    'physicalContact',false,'authorized',false,'mechanicallySafe',false, ...
    'preImpact',struct());
end

function event = makeSimple(reason,time)
event = blankEvent(time); event.occurred = true; event.reason = reason;
end

function out = interpolateState(a,b,q)
out = a;
names = {'x','z','vx','vz','theta','pitchRate','collectiveThrust'};
for i = 1:numel(names)
    name = names{i}; out.(name) = a.(name)+q*(b.(name)-a.(name));
end
end
