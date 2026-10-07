function status = updateDecisionContext(status,track,t,c,state)
% UPDATEDECISIONCONTEXT  Confidence-aware inhibit and recoverable backup.
% STATE (optional) is the synchronized own state. With the 3D option it
% enables the final-descent phase: entering the low-altitude band with a
% recent confident detection keeps landing authorized until contact, while
% the pad center leaves the shrinking camera footprint near touchdown.
s = c.experiment.safety;
recent = track.initialized && track.timeSinceLastDetection <= s.recentTrackGrace;
confident = track.lastConfidence >= s.minimumTrackConfidence;
reacquired = recent && confident;
% A prolonged loss starts a supervised backup/hold, but it is not an
% irreversible episode verdict. A causal reacquisition during the bounded
% backup window returns control to the policy with landing enabled again.
if status.abortRequested && reacquired
    status.abortRequested = false;
    status.abortRequestTime = NaN;
elseif ~status.abortRequested && track.timeSinceLastDetection >= s.prolongedLoss
    status.abortRequested = true;
    status.abortRequestTime = t;
end
status.landingInhibited = ~reacquired || status.abortRequested;
if nargin >= 5 && landing2d.environment.isSpatial(c) ...
        && isfield(c.experiment.spatial,'finalDescentHeight')
    status = finalDescent(status,state,reacquired,t,c);
end
end

function status = finalDescent(status,state,reacquired,t,c)
sp = c.experiment.spatial;
% Own altitude above the fixed, known pad plane (same quantity as packet.h).
h = state.z-c.experiment.scenario.padHeight;
if ~isfield(status,'finalDescentActive')
    status.finalDescentActive = false;
    status.finalDescentStartTime = NaN;
end
if status.finalDescentActive
    if status.abortRequested || h > sp.finalDescentExitHeight ...
            || t-status.finalDescentStartTime > sp.finalDescentMaxDuration
        status.finalDescentActive = false;
        status.finalDescentStartTime = NaN;
    end
elseif reacquired && ~status.abortRequested && h <= sp.finalDescentHeight
    status.finalDescentActive = true;
    status.finalDescentStartTime = t;
end
if status.finalDescentActive
    status.landingInhibited = false;
end
end
