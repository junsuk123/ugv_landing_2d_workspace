function T = cadenceSummary(decisionTrace,timeWindow)
% CADENCESUMMARY  Observed event rates from the distinct data stamps of a trace.
%   T = landing2d.trace.cadenceSummary(trace)          % whole episode
%   T = landing2d.trace.cadenceSummary(trace,[t0,t1])  % moving window
% One row per event type: count, distinct stamps, inter-arrival statistics
% and the observed rate 1/mean(inter-arrival), next to the nominal period
% (experiment.policyDt: the environment takes one camera frame and one
% navigation estimate per decision; physics substeps produce no sensing
% event). Rates are computed from the stamps, not from a display timer.
if nargin < 2, timeWindow = [-Inf,Inf]; end
E = decisionTrace.events;
E = E(E.Time_s >= timeWindow(1) & E.Time_s <= timeWindow(2),:);
types = ["camera_frame","marker_valid","marker_missing","pnp_valid","pnp_rejected", ...
    "kf_measurement_update","kf_time_update","own_navigation_update", ...
    "common_observation_built","actor_action_decided"];
n = numel(types);
T = table(types',zeros(n,1),zeros(n,1),NaN(n,1),NaN(n,1),NaN(n,1),NaN(n,1), ...
    repmat(decisionTrace.context.policyDt,n,1),'VariableNames',{'Type','Count','DistinctStamps', ...
    'MeanInterarrival_s','MinInterarrival_s','MaxInterarrival_s','ObservedRate_Hz', ...
    'NominalPeriod_s'});
for i = 1:n
    stamps = unique(E.Time_s(E.Type==types(i)));
    T.Count(i) = sum(E.Type==types(i));
    T.DistinctStamps(i) = numel(stamps);
    if numel(stamps) >= 2
        d = diff(stamps);
        T.MeanInterarrival_s(i) = mean(d); T.MinInterarrival_s(i) = min(d);
        T.MaxInterarrival_s(i) = max(d); T.ObservedRate_Hz(i) = 1/mean(d);
    end
end
end
