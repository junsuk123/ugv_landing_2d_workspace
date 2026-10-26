function runs = loadRuns(cfg,options)
% LOADRUNS  Load trained checkpoints of method x training seed without training.
%   runs = landing2d.orchestration.loadRuns(cfg,struct('trainSeeds',1))
% A checkpoint whose training signature does not match the current
% configuration is an error (retrain with run first).
registry = landing2d.config.methodRegistry(cfg);
if nargin < 2, options = struct(); end
methods = {registry.methods.id}; seeds = registry.trainSeeds.default;
if isfield(options,'methods') && ~isempty(options.methods), methods = cellstr(options.methods); end
if isfield(options,'trainSeeds') && ~isempty(options.trainSeeds), seeds = options.trainSeeds; end
runs = [];
for seed = seeds(:)'
    arms = landing2d.config.comparisonArms(cfg,struct('methods',{methods},'trainSeed',seed));
    for i = 1:numel(arms)
        arm = arms(i);
        [agent,info,file] = landing2d.rl.loadCheckpoint(arm.config);
        history = [];
        if isfield(info,'history'), history = info.history; end
        runs = [runs,struct('id',arm.id,'label',arm.label,'trainSeed',arm.trainSeed, ...
            'graphSeed',arm.graphSeed,'color',arm.color,'lineStyle',arm.lineStyle, ...
            'marker',arm.marker,'config',arm.config,'agent',agent,'history',history, ...
            'file',string(file),'identity',landing2d.rl.runIdentity(agent,arm.config,file))]; %#ok<AGROW>
    end
end
end
