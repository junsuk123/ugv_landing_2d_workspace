function event = evaluateTermination(previous,current,padPrevious,padCurrent, ...
    status,t0,dt,c,dynamicsInfo)
% EVALUATETERMINATION  Earliest physical event with pre-impact quantities.
s = c.experiment.safety;
event = blankEvent(t0+dt);
h0 = previous.z-padPrevious.z;
h1 = current.z-padCurrent.z;
% The configured touchdown height is the landing-gear/contact-plane offset.
% V2 previously ignored it and required the vehicle reference point to cross
% the pad plane exactly.  Near the ground the FOV supervisor would brake at
% 1--3 cm and create the observed endless hover although touchdown had
% already entered the declared contact envelope.
contactHeight = s.touchdownHeight;
crossedContactHeight = h0 > contactHeight && h1 <= contactHeight;
crossedPadPlane = h0 > 0 && h1 <= 0;
contact = crossedContactHeight || crossedPadPlane;
if contact
    if crossedContactHeight
        alpha = min(max((h0-contactHeight)/max(h0-h1,eps),0),1);
    else
        alpha = min(max(h0/max(h0-h1,eps),0),1);
    end
    contactTime = t0+alpha*dt;
    drone = interpolateState(previous,current,alpha);
    padX = padPrevious.x+alpha*(padCurrent.x-padPrevious.x);
    padVx = padPrevious.vx+alpha*(padCurrent.vx-padPrevious.vx);
    ex = padX-drone.x;
    relVx = padVx-drone.vx;
    relVz = -drone.vz;
    inFootprint = abs(ex) <= c.padHalfLength;
    horizontalSpeedSafe = abs(relVx)<=s.touchdownSpeedX;
    attitudeSafe = abs(drone.theta)<=s.touchdownPitchTolerance ...
        && abs(drone.pitchRate)<=s.touchdownPitchRateTolerance;
    mechanicalSafe = inFootprint && horizontalSpeedSafe ...
        && abs(relVz)<=s.touchdownSpeedZ && attitudeSafe;
    directPlanar = isfield(c.experiment,'actionApplication') ...
        && strcmp(c.experiment.actionApplication,'direct_policy_v1');
    % The minimal planar task has no landing-authorization guard. A contact
    % is classified solely by footprint, relative speeds and attitude. The
    % no supervisor authorization participates in the contact classification.
    authorized = directPlanar || (~status.landingInhibited && ~status.abortRequested);
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
abortElapsed = 0;
if status.abortRequested && isfinite(status.abortRequestTime)
    abortElapsed = t0+dt-status.abortRequestTime;
end
directPlanar = isfield(c.experiment,'actionApplication') ...
    && strcmp(c.experiment.actionApplication,'direct_policy_v1');
if ~directPlanar && status.abortRequested && abortElapsed >= s.backupDurationLimit ...
        && current.z-padCurrent.z >= s.abortHoldHeight ...
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
