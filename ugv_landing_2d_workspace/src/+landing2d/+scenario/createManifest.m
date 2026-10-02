function manifest = createManifest(cfg,split,seeds)
% CREATEMANIFEST  Persistable scenario manifest with explicit provenance.
if nargin < 3 || isempty(seeds)
    field = [split 'Seeds'];
    assert(isfield(cfg.experiment.manifest,field), ...
        'landing2d:ManifestSplit','Unknown split %s.',split);
    seeds = cfg.experiment.manifest.(field);
end
template = landing2d.scenario.sampleParameters(cfg.experiment.scenario,seeds(1));
cases = repmat(template,1,numel(seeds));
for i = 1:numel(seeds)
    scenarioSeed = cfg.experiment.scenario.baseSeed+ ...
        cfg.experiment.randomStreams.scenarioOffset+seeds(i);
    cases(i) = landing2d.scenario.sampleParameters( ...
        cfg.experiment.scenario,scenarioSeed);
end
manifest = struct('schemaVersion','scenario_manifest_v2','split',split, ...
    'seeds',seeds,'cases',cases,'units',struct('time','s','distance','m', ...
    'velocity','m/s','acceleration','m/s^2'));
end
