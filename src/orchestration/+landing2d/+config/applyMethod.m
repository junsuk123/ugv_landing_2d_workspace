function cfg = applyMethod(cfg,methodId,trainSeed,graphSeed)
% APPLYMETHOD  Configure one run of a registered method or ablation (planar contract).
%   cfg = landing2d.config.applyMethod(cfg,'onto_rgat_ppo',3)
%   cfg = landing2d.config.applyMethod(cfg,'shuffled_rgat_ppo',3,2)   % ablation
% Sets the state representation, the fixed relation perturbation (graph seed),
% the training seed (rl.seed = base seed + trainSeed - 1, so trainSeed 1 keeps
% the base seed) and a method/seed-specific checkpoint file. The checkpoint
% name and the perturbation are part of the training signature, so runs never
% share or overwrite checkpoints. Reward, PPO loss, dynamics, node features,
% readout, supervisor and action limits are not touched.
registry = landing2d.config.methodRegistry();
known = [registry.methods,registry.ablations];
index = find(strcmp({known.id},methodId),1);
assert(~isempty(index),'landing2d:UnknownMethod','Unknown comparison method %s.',methodId);
assert(~landing2d.environment.isSpatial(cfg),'landing2d:SpatialMethod', ...
    'The comparison registry covers the planar contract only.');
assert(~isfield(cfg,'comparisonRun'),'landing2d:MethodApplied', ...
    'A comparison method was already applied to this configuration.');
method = known(index);
if nargin < 3 || isempty(trainSeed), trainSeed = 1; end
perturbed = ~strcmp(method.graphPerturbation,'none');
if nargin < 4 || isempty(graphSeed)
    graphSeed = NaN;
    if perturbed, graphSeed = registry.graphSeeds(1); end
end
validateattributes(trainSeed,{'numeric'},{'scalar','integer','positive'},mfilename,'trainSeed');
cfg = landing2d.graphstate.applyStateRepresentation(cfg,method.representation);
name = sprintf('%s_s%02d',method.id,trainSeed);
if perturbed
    validateattributes(graphSeed,{'numeric'},{'scalar','integer','positive'},mfilename,'graphSeed');
    cfg.graphState.relationPerturbation = struct('type',method.graphPerturbation, ...
        'graphSeed',graphSeed);
    landing2d.graphstate.validateGraphStateConfig(cfg.graphState);
    name = sprintf('%s_g%02d',name,graphSeed);
else
    graphSeed = NaN;
end
cfg.rl.seed = cfg.rl.seed+trainSeed-1;
cfg.rl.policyFile = ['checkpoints/',name,'.mat'];
cfg.comparisonRun = struct('registryVersion',registry.version,'methodId',method.id, ...
    'label',method.label,'representation',method.representation, ...
    'graphPerturbation',method.graphPerturbation,'trainSeed',trainSeed, ...
    'graphSeed',graphSeed,'runName',name);
cfg.dashboardAgentLabel = method.label;
end
