function out = heldOut(runs,c)
% HELDOUT  Held-out test of the training distribution (test split, every run).
%   out = landing2d.evaluation.heldOut(runs,c)
% The same experiment.testEpisodeCount test-split seeds for every run, so
% runs are paired by episode. Episodes are labelled with their motion x
% observation cell (CV/CA x clean/dropout). The test split never selects a
% checkpoint. Outputs: episodes (one row per run and episode), runs (per-run
% means, overall and per cell), summary (mean and 95% interval over training
% seeds), contrasts (seed-paired method differences), failureRuns /
% failureSummary (outcome classes, landing2d.evaluation.failureClasses).
% RecoveryTime_s exists only in CA episodes and TrackingReacquisition_s only
% in dropout episodes; touchdown errors only in episodes with a contact.
seeds = c.experiment.manifest.testSeeds(1:c.experiment.testEpisodeCount);
identity = repmat(struct('Split',"test"),1,numel(seeds));
rows = cell(1,numel(runs));
for r = 1:numel(runs)
    fprintf('  held-out test  %-18s seed %d: %d episodes\n',runs(r).id, ...
        runs(r).trainSeed,numel(seeds));
    rows{r} = landing2d.evaluation.rolloutSet(runs(r),runs(r).config,seeds,[],identity);
end
episodes = struct2table([rows{:}]);
metrics = metricNames();
overall = episodes; overall.Cell(:) = "all";
R = landing2d.evaluation.runMeans([overall;episodes],{'Cell'},metrics);
[failureRuns,failureSummary] = landing2d.evaluation.failureTable([overall;episodes],{'Cell'});
out = struct('episodes',episodes,'runs',R, ...
    'summary',landing2d.evaluation.seedSummary(R,{'Cell'},metrics), ...
    'contrasts',landing2d.evaluation.methodContrasts(R,{'Cell'},metrics), ...
    'failureRuns',failureRuns,'failureSummary',failureSummary,'metrics',{metrics});
end

function m = metricNames()
m = {'Success','Unsafe','Timeout','Return','AimErrorRMS_m','RelativeSpeedRMS_mps', ...
    'CommandRateRMS_mps3','ApproachViewLoss_s','UnsuitableDescent_s','ContactMaxRatio', ...
    'RecoveryTime_s','TrackingReacquisition_s','TouchdownPositionError_m', ...
    'TouchdownRelativeSpeed_mps','TouchdownVerticalSpeed_mps'};
end
