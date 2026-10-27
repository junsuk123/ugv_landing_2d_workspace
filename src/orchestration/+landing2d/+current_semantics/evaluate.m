function out = evaluate(runs,d,phase,smoke)
% EVALUATE Eight closed-loop cells. Evaluation never selects a checkpoint.
if nargin<4, smoke = false; end
assert(ismember(phase,{'development','confirmation'}));
if strcmp(phase,'development'), seeds=d.developmentEnvironments; else, seeds=d.confirmationEnvironments; end
if smoke, seeds=d.smokeEnvironmentSeed; end
assert(isempty(intersect(seeds,d.forbiddenEnvironmentSeeds)));
rows = {};
for factor = d.c.evaluation.generalization.conditions
    for shift = {'ID','OOD'}
        for k=1:numel(runs)
            base = runs(k).config; base.evaluation = d.c.evaluation;
            [envConfig,scale] = landing2d.current_semantics.condition(base,factor{1},shift{1});
            spec = struct('scenario',[],'sensorEvents',[],'eventWindow',[],'sensorNoiseScale',scale);
            identity = struct('Factor',string(factor{1}),'Shift',string(shift{1}));
            fprintf('[current semantics] %s %s %s seed %d (%d episodes)\n', ...
                factor{1},shift{1},runs(k).id,runs(k).trainSeed,numel(seeds));
            rows{end+1} = landing2d.evaluation.rolloutSet(runs(k),envConfig,seeds, ...
                repmat(spec,1,numel(seeds)),repmat(identity,1,numel(seeds))); %#ok<AGROW>
        end
    end
end
episodes = struct2table([rows{:}]);
assert(height(episodes)==numel(runs)*8*numel(seeds));
out = landing2d.current_semantics.summarize(episodes,d);
out.protocol = struct('version',d.c.evaluation.protocolVersion,'phase',phase, ...
    'episodeSeeds',seeds,'isSmoke',logical(smoke),'independentUnit','training_seed', ...
    'conditions',{d.c.evaluation.generalization.conditions});
out.isSmoke = logical(smoke);
end
