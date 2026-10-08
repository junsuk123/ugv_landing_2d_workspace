function status = updateDecisionContext(status,track,t,c,state)
% UPDATEDECISIONCONTEXT  Confidence-aware inhibit and recoverable backup.
% STATE (optional) is the synchronized own state. It enables the
% final-descent phase where configured: entering the low-altitude band with a
% recent confident detection keeps landing authorized until contact, while
% the pad leaves the camera view near touchdown. The 3D option configures it
% in experiment.spatial (downward cone camera); the planar marker-camera
% supervisor configures it in experiment.commonObservation.finalDescent.
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
if nargin >= 5
    band = finalDescentBand(c);
    if ~isempty(band)
        status = finalDescent(status,state,reacquired,t,c,band);
    end
end
end

function band = finalDescentBand(c)
e = c.experiment;
band = [];
if landing2d.environment.isSpatial(c)
    if isfield(e.spatial,'finalDescentHeight')
        band = struct('enterHeight',e.spatial.finalDescentHeight, ...
            'exitHeight',e.spatial.finalDescentExitHeight, ...
            'maxDuration',e.spatial.finalDescentMaxDuration);
    end
elseif isfield(e,'commonObservation') && isfield(e.commonObservation,'finalDescent')
    band = e.commonObservation.finalDescent;
end
end

function status = finalDescent(status,state,reacquired,t,c,band)
% Own altitude above the fixed, known pad plane (same quantity as packet.h).
h = state.z-c.experiment.scenario.padHeight;
if ~isfield(status,'finalDescentActive')
    status.finalDescentActive = false;
    status.finalDescentStartTime = NaN;
end
if status.finalDescentActive
    if status.abortRequested || h > band.exitHeight ...
            || t-status.finalDescentStartTime > band.maxDuration
        status.finalDescentActive = false;
        status.finalDescentStartTime = NaN;
    end
elseif reacquired && ~status.abortRequested && h <= band.enterHeight
    status.finalDescentActive = true;
    status.finalDescentStartTime = t;
end
if status.finalDescentActive
    status.landingInhibited = false;
end
end
