function status = updateDecisionContext(status,track,t,c)
% UPDATEDECISIONCONTEXT  Confidence-aware inhibit and recoverable backup.
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
end
