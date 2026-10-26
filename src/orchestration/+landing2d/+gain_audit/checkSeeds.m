function checkSeeds(d)
% CHECKSEEDS Reject a configuration that opens 9101-9200 or leaves the development stress seeds.
m = d.c.experiment.manifest;
assert(isempty(intersect(d.environmentSeeds,d.forbiddenEnvironmentSeeds)), ...
    'landing2d:GainAuditSeeds','Confirmation environments 9101-9200 stay closed.');
assert(all(ismember(d.environmentSeeds,m.stressSeeds(1:100))), ...
    'landing2d:GainAuditSeeds','Use the opened development stress seeds 9001-9100 only.');
assert(isequal(d.trainSeeds,421:425) && numel(d.methods)==4 && isequal(d.gains,[1,2]), ...
    'landing2d:GainAuditSeeds','The registered models and gains are fixed.');
end
