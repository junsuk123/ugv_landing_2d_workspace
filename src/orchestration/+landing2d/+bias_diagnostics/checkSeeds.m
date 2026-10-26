function checkSeeds(d)
% CHECKSEEDS Reject any diagnostic configuration that would open 9101-9200 or leave the allowed splits.
m = d.c.experiment.manifest;
closedLoop = [d.rollout.seeds,d.branch.seeds,d.typingSwap.seeds];
assert(isempty(intersect([d.reference.seeds,closedLoop],d.forbiddenEnvironmentSeeds)), ...
    'landing2d:BiasDiagnosticsSeeds','Confirmation environments 9101-9200 stay closed.');
assert(all(ismember(d.reference.seeds,m.testSeeds)) ...
    && all(ismember(closedLoop,m.stressSeeds(1:100))), ...
    'landing2d:BiasDiagnosticsSeeds','Use test-split references and development stress seeds only.');
assert(isequal(d.trainSeeds,421:425) && numel(d.methods)==4);
end
