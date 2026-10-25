function cfg = applyMethod(cfg,methodId,trainSeed,graphSeed)
% APPLYMETHOD  Configure one run of a registered method.
%   cfg = landing2d.config.applyMethod(cfg,'onto_rgat_ppo',3)
%   cfg = landing2d.config.applyMethod(cfg,'shuffled_rgat_ppo',3)     % graph seed 3
%   cfg = landing2d.config.applyMethod(cfg,'shuffled_rgat_ppo',3,1)   % graph seed 1
% Sets the state representation, the fixed relation permutation (graph seed,
% default = training seed), the training seed (rl.seed = base + trainSeed - 1)
% and a run-specific checkpoint file. The checkpoint name and the permutation
% are part of the training signature, so runs never share checkpoints.
% Reward, PPO loss, dynamics, node features, readout and action limits are
% not touched.
registry = landing2d.config.methodRegistry();
index = find(strcmp({registry.methods.id},methodId),1);
assert(~isempty(index),'landing2d:UnknownMethod','Unknown comparison method %s.',methodId);
assert(~isfield(cfg,'comparisonRun'),'landing2d:MethodApplied', ...
    'A comparison method was already applied to this configuration.');
method = registry.methods(index);
if nargin < 3 || isempty(trainSeed), trainSeed = 1; end
validateattributes(trainSeed,{'numeric'},{'scalar','integer','positive'},mfilename,'trainSeed');
perturbed = ~strcmp(method.graphPerturbation,'none');
if nargin < 4 || isempty(graphSeed), graphSeed = trainSeed; end
cfg = landing2d.graphstate.applyStateRepresentation(cfg,method.representation);
name = sprintf('%s_s%02d',method.id,trainSeed);
if perturbed
    if ismember(cfg.graphState.encoderVersion,{'rgat_minimal_v1','rgat_minimal_v2','rgat_minimal_v3'})
        registry.relationShuffle.minChangedFraction = registry.relationShuffle.minimalChangedFraction;
    end
    validateattributes(graphSeed,{'numeric'},{'scalar','integer','positive'},mfilename,'graphSeed');
    cfg.graphState.relationPerturbation = struct('type',method.graphPerturbation, ...
        'graphSeed',graphSeed, ...
        'minChangedFraction',registry.relationShuffle.minChangedFraction);
    % The operator-class rule applies whenever relation types select an
    % operator: the archived rgat_v1 typed_v1 encoder and rgat_v2 with
    % semantic_fixed_v1 operators (relational-policy-v2.4).
    legacyTyped = strcmp(cfg.graphState.encoderVersion,'rgat_v1') ...
        && isfield(cfg.graphState,'relationOperators') ...
        && strcmp(cfg.graphState.relationOperators,'typed_v1');
    fixedOperators = strcmp(cfg.graphState.encoderVersion,'rgat_v2') ...
        && isfield(cfg.graphState,'v2Operators') ...
        && ismember(cfg.graphState.v2Operators, ...
        {'semantic_fixed_v1','semantic_bottleneck_v1','semantic_reliability_bottleneck_v1'});
    if legacyTyped || fixedOperators
        operatorFraction = registry.relationShuffle.minChangedFraction;
        if strcmp(cfg.graphState.v2Operators,'semantic_reliability_bottleneck_v1')
            operatorFraction = registry.relationShuffle.minReliabilityOperatorChangedFraction;
        end
        cfg.graphState.relationPerturbation.minOperatorChangedFraction = operatorFraction;
    end
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
end
