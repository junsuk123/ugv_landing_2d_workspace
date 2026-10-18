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
% Rollouts of DISPLAYSEED (default: first training seed) are kept for figures.
specs = landing2d.evaluation.factorialCases(c);
f = c.evaluation.factorial;
seeds = landing2d.evaluation.replicateSeeds(c,f.seed,f.replicates);
if nargin < 3 || isempty(displaySeed), displaySeed = min([runs.trainSeed]); end
rows = {}; shown = struct('methodId',{},'case',{},'results',{});
for r = 1:numel(runs)
    fprintf('  factorial S1-S4 %-18s seed %d: %d replicates\n',runs(r).id, ...
        runs(r).trainSeed,numel(seeds));
    for s = 1:numel(specs)
        spec = struct('scenario',specs(s).scenario,'sensorEvents',specs(s).sensorEvents, ...
            'eventWindow',specs(s).eventWindow,'sensorNoiseScale',[]);
        identity = struct('Case',string(specs(s).id),'Replicate',num2cell(1:numel(seeds)));
        keep = repmat(runs(r).trainSeed==displaySeed,1,numel(seeds));
        [caseRows,kept] = landing2d.evaluation.rolloutSet(runs(r),runs(r).config,seeds, ...
            repmat(spec,1,numel(seeds)),identity,keep);
        rows{end+1} = caseRows; %#ok<AGROW>
        if any(keep)
            shown(end+1) = struct('methodId',runs(r).id,'case',specs(s).id, ...
                'results',{kept}); %#ok<AGROW>
        end
    end
end
episodes = struct2table([rows{:}]);
episodes.Failure = 1-episodes.Success;
caseMetrics = {'Success','Failure','Unsafe','WindowAimErrorRMS_m','WindowMaxAbsAimError_m', ...
    'WindowRelativeSpeedRMS_mps','WindowCommandRateRMS_mps3','SpeedRematch_s', ...
    'ReacquisitionLatency_s','ApproachViewLoss_s','UnsuitableDescent_s','ContactMaxRatio'};
effectMetrics = {'Failure','WindowAimErrorRMS_m','WindowRelativeSpeedRMS_mps', ...
    'WindowCommandRateRMS_mps3','UnsuitableDescent_s'};
caseRuns = landing2d.evaluation.runMeans(episodes,{'Case'},caseMetrics);
effects = landing2d.evaluation.factorialEffects(episodes,effectMetrics);
effectRuns = landing2d.evaluation.runMeans(effects,{'Effect'},effectMetrics);
out = struct('cases',specs,'replicateSeeds',seeds,'episodes',episodes, ...
    'caseRuns',caseRuns, ...
    'caseSummary',landing2d.evaluation.seedSummary(caseRuns,{'Case'},caseMetrics), ...
    'effects',effects,'effectRuns',effectRuns, ...
    'effectSummary',landing2d.evaluation.seedSummary(effectRuns,{'Effect'},effectMetrics), ...
    'effectContrasts',landing2d.evaluation.methodContrasts(effectRuns,{'Effect'},effectMetrics), ...
    'caseMetrics',{caseMetrics},'effectMetrics',{effectMetrics}, ...
    'displaySeed',displaySeed,'display',shown);
end
