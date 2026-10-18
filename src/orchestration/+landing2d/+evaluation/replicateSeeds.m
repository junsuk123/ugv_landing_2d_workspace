function seeds = replicateSeeds(c,seed,replicates)
% REPLICATESEEDS  Episode seeds of the noise replicates of one fixed-case group.
%   seeds = landing2d.evaluation.replicateSeeds(c,43001,20)   % 1 x R
% Replicate r uses seed + r - 1 (another sensor-noise realization and initial
% random state); the cases of one group share every replicate seed. All seeds
% lie in the reserved fixed-case range and outside every manifest split.
validateattributes(replicates,{'numeric'},{'scalar','integer','positive'});
seeds = double(seed)+(0:replicates-1);
manifest = c.experiment.manifest;
range = manifest.fixedCaseSeedRange;
assert(all(seeds>=range(1) & seeds<=range(2)),'landing2d:ReplicateSeedRange', ...
    'Fixed-case replicate seeds must stay inside [%d,%d].',range(1),range(2));
splits = [manifest.trainSeeds,manifest.validationSeeds,manifest.testSeeds,manifest.stressSeeds];
assert(~any(ismember(seeds,splits)),'landing2d:ReplicateSeedSplit', ...
    'A fixed-case replicate seed falls inside a manifest split.');
end
