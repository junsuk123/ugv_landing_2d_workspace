function checkSeeds(d)
% CHECKSEEDS Reject a configuration that opens 9101-9200 or changes the registered seeds.
g = d.v5.evaluation.generalization;
used = d.v5.experiment.manifest.stressSeeds(g.seedOffset+(1:g.episodes));
assert(isequal(used(:)',d.environmentSeeds(:)') && isempty(intersect(used,d.forbiddenEnvironmentSeeds)), ...
    'landing2d:AccelRangeSeeds','Evaluate on the opened development seeds 9001-9100 only.');
assert(isequal(d.trainSeeds,421:425) && numel(d.methods)==4 && strcmp(g.phase,'development'), ...
    'landing2d:AccelRangeSeeds','The registered paired seeds and methods are fixed.');
end
