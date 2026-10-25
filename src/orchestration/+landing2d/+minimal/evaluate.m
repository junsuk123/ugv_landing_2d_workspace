function out = evaluate(runs,c,includeDiagnostics)
% EVALUATE Generalization first; learning and optional old cases are secondary.
if nargin<3, includeDiagnostics = false; end
out = landing2d.minimal.generalization(runs,c);
learning = landing2d.evaluation.learningEfficiency(runs,c);
out.runManifest = struct2table([runs.identity]);
learningMetrics = {'AUC','Reached80'};
out.learningBySeed = learning.runs(:,[{'MethodId','Method','TrainSeed'},learningMetrics]);
out.learningCurves = learning.curves;
out.learningContrasts = landing2d.evaluation.methodContrasts(out.learningBySeed,{},learningMetrics);
if ~includeDiagnostics, return; end
metrics = {'Success','Unsafe','AimErrorRMS_m','CommandRateRMS_mps3','RecoveryTime_s'};
seeds = c.experiment.manifest.testSeeds(1:c.experiment.testEpisodeCount);
rows = cell(1,numel(runs));
for r = 1:numel(runs)
    fprintf('  held-out %-18s seed %d (%d episodes)\n',runs(r).id,runs(r).trainSeed,numel(seeds));
    rows{r} = landing2d.evaluation.rolloutSet(runs(r),runs(r).config,seeds,[], ...
        repmat(struct('Split',"test"),1,numel(seeds)));
end
out.heldoutEpisodes = struct2table([rows{:}]);
out.heldoutBySeed = landing2d.evaluation.runMeans(out.heldoutEpisodes,{},metrics);
out.heldoutContrasts = landing2d.evaluation.methodContrasts(out.heldoutBySeed,{},metrics);
specs = landing2d.minimal.cases(c);
seeds = landing2d.evaluation.replicateSeeds(c,c.evaluation.factorial.seed,c.evaluation.factorial.replicates);
rows = {}; spread = {};
shown = struct('methodId',{},'case',{},'results',{});
for r = 1:numel(runs)
    for s = 1:numel(specs)
        fprintf('  %s %-18s seed %d (%d noise replicates)\n', ...
            specs(s).id,runs(r).id,runs(r).trainSeed,numel(seeds));
        spec = struct('scenario',specs(s).scenario,'sensorEvents',specs(s).sensorEvents, ...
            'eventWindow',specs(s).eventWindow,'sensorNoiseScale',[]);
        identity = struct('Case',string(specs(s).id),'Replicate',num2cell(1:numel(seeds)));
        [rows{end+1},kept] = landing2d.evaluation.rolloutSet(runs(r),runs(r).config,seeds, ...
            repmat(spec,1,numel(seeds)),identity,true(1,numel(seeds))); %#ok<AGROW>
        spread{end+1} = dispersion(runs(r),specs(s),kept,c); %#ok<AGROW>
        if runs(r).trainSeed==min([runs.trainSeed])
            shown(end+1) = struct('methodId',runs(r).id,'case',specs(s).id,'results',{kept}); %#ok<AGROW>
        end
    end
end
out.caseEpisodes = struct2table([rows{:}]);
caseMetrics = {'Success','Unsafe','WindowAimErrorRMS_m','WindowCommandRateRMS_mps3','RecoveryTime_s'};
out.caseBySeed = landing2d.evaluation.runMeans(out.caseEpisodes,{'Case'},caseMetrics);
out.caseBySeed = join(out.caseBySeed,vertcat(spread{:}),'Keys',{'Case','MethodId','TrainSeed'});
caseMetrics = [caseMetrics,{'CommandVariance_m2ps4','CommonHorizon_s'}];
out.caseSummary = landing2d.evaluation.seedSummary(out.caseBySeed,{'Case'},caseMetrics);
out.caseContrasts = landing2d.evaluation.methodContrasts(out.caseBySeed,{'Case'},caseMetrics);
out.cases = specs;
out.display = shown;
out.displaySeed = min([runs.trainSeed]);
end

function row = dispersion(run,spec,kept,c)
% Same case, different sensor noise. Use only the shared event-window horizon.
n = numel(kept); m = min(cellfun(@(x)size(x.command,2),kept));
t = kept{1}.time(1:m);
commands = zeros(2,m,n);
for j = 1:n
    assert(isequal(kept{j}.time(1:m),t),'landing2d:DispersionGrid','Time grids differ.');
    commands(:,:,j) = kept{j}.command(:,1:m);
end
window = t>=spec.eventWindow(1) & t<spec.eventWindow(2)+c.evaluation.settling;
value = NaN;
if n>=2 && any(window)
    variance = sum(var(commands,0,3),1);
    value = mean(variance(window));
end
row = table(string(spec.id),string(run.id),run.trainSeed,value,m*c.experiment.policyDt, ...
    'VariableNames',{'Case','MethodId','TrainSeed','CommandVariance_m2ps4','CommonHorizon_s'});
end
