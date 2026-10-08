function runs = trainCampaign(options)
% TRAINCAMPAIGN  Train (or load) registered methods over training/graph seeds.
%   runs = landing2d.orchestration.trainCampaign(struct('methods',{{'ppo'}}, ...
%       'trainSeeds',1:5,'graphSeeds',1:3))
% Planar contract only. Every run is configured by landing2d.config.applyMethod
% and trained with the unchanged MATLAB PPO path (landing2d.rl.loadOrTrainAgent),
% so it lands in <outputDir>/checkpoints/<method_id>_s<train_seed>[_g<graph_seed>].mat
% with its training signature and run identity. The relation-perturbed method
% is trained once per graph seed; the other methods ignore graphSeeds. A
% compatible existing checkpoint is reused, never retrained. Separate MATLAB
% processes may train different runs concurrently because every run writes
% its own checkpoint file. Validation seeds select checkpoints; the test split
% is not touched here.
if nargin < 1, options = struct(); end
projectRoot = landing2d.orchestration.projectRoot();
cfg = landing2d.config.primaryConfig(projectRoot);
registry = landing2d.config.methodRegistry();
known = [registry.methods,registry.ablations]; % ablations only when requested
defaults = struct('methods',{{registry.methods.id}},'trainSeeds',1, ...
    'graphSeeds',1,'outputDir',cfg.outputDir,'verbose',true, ...
    'parallelWorkers',0);
names = fieldnames(options);
for i = 1:numel(names)
    assert(isfield(defaults,names{i}),'landing2d:CampaignOption', ...
        'Unknown trainCampaign option %s.',names{i});
    defaults.(names{i}) = options.(names{i});
end
options = defaults;
methods = cellstr(options.methods);
cfg.outputDir = char(options.outputDir);
cfg.rl.verbose = logical(options.verbose);
cfg.rl.parallelWorkers = options.parallelWorkers;
cfg.showLiveDashboard = false; cfg.figureVisible = false; cfg.animate = false;
landing2d.config.validateConfig(cfg);
assert(~landing2d.environment.isSpatial(cfg),'landing2d:CampaignPlanarOnly', ...
    'trainCampaign covers the planar comparison methods.');
runs = struct('MethodId',{},'TrainSeed',{},'GraphSeed',{},'CheckpointFile',{}, ...
    'GraphHash',{},'RelationalPathActive',{},'TrainingSeconds',{}, ...
    'PretrainingSeconds',{},'RelationActivationSeconds',{},'EnvironmentSteps',{});
for m = 1:numel(methods)
    index = find(strcmp({known.id},methods{m}),1);
    assert(~isempty(index),'landing2d:UnknownMethod','Unknown method %s.',methods{m});
    perturbed = ~strcmp(known(index).graphPerturbation,'none');
    graphSeeds = NaN;
    if perturbed, graphSeeds = options.graphSeeds; end
    for s = options.trainSeeds(:)'
        for g = graphSeeds(:)'
            arm = landing2d.config.applyMethod(cfg,methods{m},s,g);
            if options.verbose
                fprintf('=== %s train_seed %d graph_seed %g -> %s\n',methods{m},s,g, ...
                    arm.rl.policyFile);
            end
            [agent,info,file] = landing2d.rl.loadOrTrainAgent(arm,@landing2d.rl.ppoTrain);
            run = landing2d.rl.runIdentity(agent,arm,file);
            steps = NaN;
            if isfield(info,'history') && isfield(info.history,'environmentSteps')
                steps = info.history(end).environmentSteps;
            end
            runs(end+1) = struct('MethodId',run.MethodId,'TrainSeed',s,'GraphSeed',g, ...
                'CheckpointFile',file,'GraphHash',run.GraphHash, ...
                'RelationalPathActive',run.RelationalPathActive, ...
                'TrainingSeconds',fieldOr(info,'trainingSeconds'), ...
                'PretrainingSeconds',fieldOr(info,'pretrainingSeconds'), ...
                'RelationActivationSeconds',fieldOr(fieldOr(info,'relationActivation'),'seconds'), ...
                'EnvironmentSteps',steps); %#ok<AGROW>
            if options.verbose
                fprintf('=== done %s s%d g%g: %.0f s, relational path active %d\n', ...
                    methods{m},s,g,runs(end).TrainingSeconds,runs(end).RelationalPathActive);
            end
        end
    end
end
end

function value = fieldOr(s,name)
value = NaN;
if isstruct(s) && isfield(s,name) && ~isempty(s.(name)), value = s.(name); end
end
