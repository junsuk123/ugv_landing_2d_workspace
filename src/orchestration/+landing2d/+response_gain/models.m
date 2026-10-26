function [v5,r1] = models(d,trainSeeds)
% MODELS The v5 and R1 checkpoints of the same methods and seeds, identities verified.
% v5: landing2d.bias_diagnostics.models (identity hash = protocol-v2 run manifest).
% R1: identity hash = acceleration_range_r1_v1 runManifest.csv and file SHA-256
% = its manifest.json. R1 runs get the v5 experiment (accel_range.evaluationRuns)
% so every environment they fly is the v5 / protocol-v2 one.
if nargin<2, trainSeeds = d.trainSeeds; end
v5 = landing2d.bias_diagnostics.models(d,trainSeeds);
r1 = landing2d.orchestration.loadRuns(d.r1.c,struct('trainSeeds',trainSeeds));
manifest = readtable(fullfile(d.r1Results,'runManifest.csv'),'TextType','string');
saved = jsondecode(fileread(fullfile(d.r1Results,'manifest.json'))).checkpoints;
assert(numel(r1)==numel(v5) && isequal({r1.id},{v5.id}) && isequal([r1.trainSeed],[v5.trainSeed]), ...
    'landing2d:ResponseGainModels','R1 and v5 runs must pair by method and seed.');
for r = 1:numel(r1)
    row = manifest(manifest.MethodId==string(r1(r).id) & manifest.TrainSeed==r1(r).trainSeed,:);
    assert(height(row)==1 && row.CheckpointHash==string(r1(r).identity.CheckpointHash), ...
        'landing2d:ResponseGainCheckpoint','%s seed %d differs from the R1 run.',r1(r).id,r1(r).trainSeed);
    sha = landing2d.bias_diagnostics.fileHash(r1(r).file);
    entry = saved(strcmp({saved.MethodId},r1(r).id) & [saved.TrainSeed]==r1(r).trainSeed);
    assert(isscalar(entry) && strcmp(entry.sha256,sha),'landing2d:ResponseGainCheckpoint', ...
        '%s seed %d file differs from the R1 manifest.',r1(r).id,r1(r).trainSeed);
    r1(r).fileSha256 = string(sha);
end
r1 = landing2d.accel_range.evaluationRuns(r1,d.r1);
end
