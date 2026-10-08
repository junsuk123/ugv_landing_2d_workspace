function status = probeStatus(probe)
% PROBESTATUS  Decision context of a fixed probe held over a validity prediction.
% landingInhibited already includes the final-descent latch (updateDecisionContext).
status = struct('landingInhibited',logical(probe.context.landingInhibited), ...
    'abortRequested',logical(probe.context.abortRequested),'abortRequestTime',NaN);
end
