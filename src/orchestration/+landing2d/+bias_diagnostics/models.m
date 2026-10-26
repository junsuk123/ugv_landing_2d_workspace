function runs = models(d,trainSeeds)
% MODELS The frozen v5 development checkpoints with verified identities and file SHA-256.
% The identity hash must equal the run manifest of the protocol-v2 development
% evaluation, so every diagnostic reads exactly the evaluated policies.
if nargin<2, trainSeeds = d.trainSeeds; end
runs = landing2d.orchestration.loadRuns(d.c,struct('trainSeeds',trainSeeds));
assert(numel(runs)==4*numel(trainSeeds) && all(ismember({runs.id},d.methods)));
manifest = readtable(fullfile(d.v2Evaluation,'runManifest.csv'),'TextType','string');
for r = 1:numel(runs)
    row = manifest(manifest.MethodId==string(runs(r).id) & manifest.TrainSeed==runs(r).trainSeed,:);
    assert(height(row)==1 && row.CheckpointHash==string(runs(r).identity.CheckpointHash), ...
        'landing2d:BiasDiagnosticsCheckpoint','%s seed %d differs from the evaluated checkpoint.', ...
        runs(r).id,runs(r).trainSeed);
    runs(r).fileSha256 = string(landing2d.bias_diagnostics.fileHash(runs(r).file));
end
end
