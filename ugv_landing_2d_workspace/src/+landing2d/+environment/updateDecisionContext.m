function status = updateDecisionContext(status,track,t,c)
% UPDATEDECISIONCONTEXT  Confidence-aware inhibit and latched abort logic.
s = c.experiment.safety;
recent = track.initialized && track.timeSinceLastDetection <= s.recentTrackGrace;
confident = track.lastConfidence >= s.minimumTrackConfidence;
status.landingInhibited = ~(recent && confident) || status.abortRequested;
if ~status.abortRequested && track.timeSinceLastDetection >= s.prolongedLoss
    status.abortRequested = true;
    status.abortRequestTime = t;
    status.landingInhibited = true;
end
end
