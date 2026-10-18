function runs = trainRuns(cfg,options)
% TRAINRUNS  Train (or reuse) every method x training seed of the comparison.
%   runs = landing2d.orchestration.trainRuns(cfg,struct('trainSeeds',1:5))
% options.methods     registry ids (default all three)
% options.trainSeeds  training seeds (default registry.trainSeeds.default)
% options.retrain     true retrains even when a compatible checkpoint exists
%                     (default false: a checkpoint is reused only when its
%                     training signature matches, otherwise it is retrained)
% options.smoke       true: one bounded PPO iteration per run, nothing saved
%                     (integration check, not a performance result)
% Seeds are the outer loop, so every method of seed 1 finishes before seed 2.
% Methods with the same seed share the training-episode sequence.
registry = landing2d.config.methodRegistry();
defaults = struct('methods',{{registry.methods.id}}, ...
    'trainSeeds',registry.trainSeeds.default,'retrain',false,'smoke',false);
options = withDefaults(options,defaults);
cfg.rl.retrain = logical(options.retrain);
runs = [];
for seed = options.trainSeeds(:)'
    arms = landing2d.config.comparisonArms(cfg,struct('methods',{options.methods}, ...
        'trainSeed',seed));
    for i = 1:numel(arms)
        arm = arms(i);
        fprintf('[train] %-18s seed %d\n',arm.id,seed);
        file = '';
        if options.smoke
            [agent,info] = landing2d.rl.trainAgent(arm.config,@landing2d.rl.ppoTrain);
        else
            [agent,info,file] = landing2d.rl.loadOrTrainAgent(arm.config,@landing2d.rl.ppoTrain);
        end
        runs = [runs,makeRun(arm,agent,info,file)]; %#ok<AGROW>
    end
end
end

function run = makeRun(arm,agent,info,file)
history = [];
if isfield(info,'history'), history = info.history; end
run = struct('id',arm.id,'label',arm.label,'trainSeed',arm.trainSeed, ...
    'graphSeed',arm.graphSeed,'color',arm.color,'lineStyle',arm.lineStyle, ...
    'marker',arm.marker,'config',arm.config,'agent',agent,'history',history, ...
    'file',string(file),'identity',landing2d.rl.runIdentity(agent,arm.config,char(file)));
end

function options = withDefaults(options,defaults)
if nargin < 1 || isempty(options), options = struct(); end
unknown = setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption','Unknown option: %s',strjoin(unknown,', '));
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(options,names{i}) || isempty(options.(names{i}))
        options.(names{i}) = defaults.(names{i});
    end
end
options.methods = cellstr(options.methods);
end
