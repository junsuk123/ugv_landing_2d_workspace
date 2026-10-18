function out = factorialStudy(runs,c,displaySeed)
% FACTORIALSTUDY  Controlled 2 x 2 evaluation (S1-S4) with paired effects and interaction.
%   out = landing2d.evaluation.factorialStudy(runs,c,displaySeed)
% Every run flies S1-S4 (landing2d.evaluation.factorialCases) with the same
% replicate seeds. Per replicate (same initial state and noise table in all
% four cases) and metric L:
%   Dropout|CV   L(S2) - L(S1)        Dropout|CA   L(S4) - L(S3)
%   Motion|clean L(S3) - L(S1)        Motion|dropout L(S4) - L(S2)
%   Interaction  L(S4) - L(S3) - L(S2) + L(S1)
% The interaction is the extra change when dropout and UGV acceleration occur
% together, beyond the sum of the separate effects. It is an experimental
% interaction of this design, not a causal attribution to a relation; read it
% with the per-case means and the mission outcome. Effects are averaged over
% replicates per run, then compared over training seeds.
% Noise-induced trajectory dispersion: the replicates of one case share the
% physical scenario and the initial state and differ only in the sensor-noise
% table, so per run and case
%   TrajectoryVariance_m2 = mean_t tr Cov_replicates[(x_drone - x_pad, z_drone)(t)]
% over the decisions where every replicate is still flying (CommonHorizon_s),
% and WindowTrajectoryVariance_m2 over the event window (+ settling) only.
% A secondary robustness metric: read it with tracking and recovery, since a
% policy that ignores its inputs also has a small dispersion.
% Rollouts of DISPLAYSEED (default: first training seed) are kept for figures.
specs = landing2d.evaluation.factorialCases(c);
f = c.evaluation.factorial;
seeds = landing2d.evaluation.replicateSeeds(c,f.seed,f.replicates);
if nargin < 3 || isempty(displaySeed), displaySeed = min([runs.trainSeed]); end
rows = {}; dispersion = {}; shown = struct('methodId',{},'case',{},'results',{});
for r = 1:numel(runs)
    fprintf('  factorial S1-S4 %-18s seed %d: %d replicates\n',runs(r).id, ...
        runs(r).trainSeed,numel(seeds));
    for s = 1:numel(specs)
        spec = struct('scenario',specs(s).scenario,'sensorEvents',specs(s).sensorEvents, ...
            'eventWindow',specs(s).eventWindow,'sensorNoiseScale',[]);
        identity = struct('Case',string(specs(s).id),'Replicate',num2cell(1:numel(seeds)));
        keep = true(1,numel(seeds));
        [caseRows,kept] = landing2d.evaluation.rolloutSet(runs(r),runs(r).config,seeds, ...
            repmat(spec,1,numel(seeds)),identity,keep);
        rows{end+1} = caseRows; %#ok<AGROW>
        dispersion{end+1} = dispersionRow(runs(r),specs(s),kept,c.evaluation.settling); %#ok<AGROW>
        if runs(r).trainSeed==displaySeed
            shown(end+1) = struct('methodId',runs(r).id,'case',specs(s).id, ...
                'results',{kept}); %#ok<AGROW>
        end
    end
end
episodes = struct2table([rows{:}]);
episodes.Failure = 1-episodes.Success;
caseMetrics = {'Success','Failure','Unsafe','WindowAimErrorRMS_m','WindowMaxAbsAimError_m', ...
    'WindowRelativeSpeedRMS_mps','WindowCommandRateRMS_mps3','SpeedRematch_s', ...
    'RecoveryTime_s','ReacquisitionLatency_s','TrackingReacquisition_s', ...
    'ApproachViewLoss_s','UnsuitableDescent_s','ContactMaxRatio', ...
    'TouchdownPositionError_m','TouchdownRelativeSpeed_mps'};
effectMetrics = {'Failure','WindowAimErrorRMS_m','WindowRelativeSpeedRMS_mps', ...
    'WindowCommandRateRMS_mps3','UnsuitableDescent_s'};
dispersionMetrics = {'TrajectoryVariance_m2','WindowTrajectoryVariance_m2','CommonHorizon_s'};
caseRuns = landing2d.evaluation.runMeans(episodes,{'Case'},caseMetrics);
effects = landing2d.evaluation.factorialEffects(episodes,effectMetrics);
effectRuns = landing2d.evaluation.runMeans(effects,{'Effect'},effectMetrics);
dispersionRuns = vertcat(dispersion{:});
[failureRuns,failureSummary] = landing2d.evaluation.failureTable(episodes,{'Case'});
out = struct('cases',specs,'replicateSeeds',seeds,'episodes',episodes, ...
    'caseRuns',caseRuns, ...
    'caseSummary',landing2d.evaluation.seedSummary(caseRuns,{'Case'},caseMetrics), ...
    'caseContrasts',landing2d.evaluation.methodContrasts(caseRuns,{'Case'},caseMetrics), ...
    'dispersionRuns',dispersionRuns, ...
    'dispersionSummary',landing2d.evaluation.seedSummary(dispersionRuns,{'Case'},dispersionMetrics), ...
    'dispersionContrasts',landing2d.evaluation.methodContrasts(dispersionRuns,{'Case'},dispersionMetrics), ...
    'failureRuns',failureRuns,'failureSummary',failureSummary, ...
    'effects',effects,'effectRuns',effectRuns, ...
    'effectSummary',landing2d.evaluation.seedSummary(effectRuns,{'Effect'},effectMetrics), ...
    'effectContrasts',landing2d.evaluation.methodContrasts(effectRuns,{'Effect'},effectMetrics), ...
    'caseMetrics',{caseMetrics},'effectMetrics',{effectMetrics}, ...
    'dispersionMetrics',{dispersionMetrics},'displaySeed',displaySeed,'display',shown);
end

function row = dispersionRow(run,spec,results,settling)
% Noise-induced dispersion of the replicate trajectories of one run and case.
n = numel(results);
m = min(cellfun(@(r)numel(r.time)-1,results));   % decisions (last entry = terminal time)
t = results{1}.time(1:m);
X = zeros(n,m); Z = zeros(n,m);
for i = 1:n
    r = results{i};
    assert(max(abs(r.time(1:m)-t))<1e-9,'landing2d:DispersionGrid', ...
        'The replicates of a case must share the decision times.');
    X(i,:) = r.xDrone(1:m)-r.xPad(1:m);
    Z(i,:) = r.zDrone(1:m);
end
variance = var(X,0,1)+var(Z,0,1);
inWindow = t>=spec.eventWindow(1) & t<spec.eventWindow(2)+settling;
windowVariance = NaN;
if any(inWindow), windowVariance = mean(variance(inWindow)); end
row = table(string(spec.id),string(run.id),string(run.label),run.trainSeed,n, ...
    mean(variance),windowVariance,t(m), ...
    'VariableNames',{'Case','MethodId','Method','TrainSeed','Replicates', ...
    'TrajectoryVariance_m2','WindowTrajectoryVariance_m2','CommonHorizon_s'});
end
