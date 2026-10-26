function runs = evaluationRuns(runs,d)
% EVALUATIONRUNS The trained runs with the v5 experiment as their environment.
% landing2d.minimal.generalization builds each cell from run.config, so the new
% training family would otherwise leak into the evaluation. The policy-side
% configuration is untouched; only experiment is replaced, after checking that
% it differs from v5 in nothing but the training a2Range and the registered
% validationScenario.
for r = 1:numel(runs)
    e = runs(r).config.experiment;
    assert(isequal(e.validationScenario,d.v5.experiment.scenario), ...
        'landing2d:AccelRangeEvaluation','Validation must stay on the v5 family.');
    e = rmfield(e,'validationScenario');
    e.scenario.a2Range = d.v5.experiment.scenario.a2Range;
    assert(isequal(e,d.v5.experiment),'landing2d:AccelRangeEvaluation', ...
        'Run %s seed %d differs from v5 beyond the training a2Range.',runs(r).id,runs(r).trainSeed);
    runs(r).config.experiment = d.v5.experiment;
end
end
