function out = generalization(runs,c)
% GENERALIZATION Three predeclared shifts, each with a paired ID reference.
g = c.evaluation.generalization;
assert(isequal(g.conditions,{'motion','dropout','noise'}));
assert(g.oodA2Range(1)>c.experiment.scenario.a2Range(2) ...
    && g.oodDropoutDuration(1)>c.experiment.sensor.perturbation.severeDropoutDuration(2) ...
    && g.oodNoiseScale>1,'landing2d:GeneralizationRange','OOD must be strictly outside training.');
assert(g.episodes>=1 && g.episodes<=100 && ismember(g.seedOffset,[0,100]));
seeds = c.experiment.manifest.stressSeeds(g.seedOffset+(1:g.episodes));
rows = {};
for factor = g.conditions
    for shift = {'ID','OOD'}
        for r = 1:numel(runs)
            % Use the currently registered evaluation with the loaded run's
            % own policy configuration. No optimizer or model selection here.
            base = runs(r).config; base.evaluation = c.evaluation;
            [envConfig,scale] = landing2d.minimal.generalizationCondition(base,factor{1},shift{1});
            spec = struct('scenario',[],'sensorEvents',[],'eventWindow',[],'sensorNoiseScale',scale);
            identity = struct('Factor',string(factor{1}),'Shift',string(shift{1}));
            fprintf('  generalization %-7s %s %-18s seed %d (%d episodes)\n', ...
                factor{1},shift{1},runs(r).id,runs(r).trainSeed,numel(seeds));
            rows{end+1} = landing2d.evaluation.rolloutSet(runs(r),envConfig,seeds, ...
                repmat(spec,1,numel(seeds)),repmat(identity,1,numel(seeds))); %#ok<AGROW>
        end
    end
end
out = landing2d.minimal.generalizationSummary(struct2table([rows{:}]));
out.generalizationProtocol = g;
out.generalizationProtocol.episodeSeeds = seeds;
end
