% RUN Active compact study. Edit settings, then press F5.
% Four evidence nodes -> two shared dynamic-attention hops -> PPO.
% See docs/MINIMAL_V31_DESIGN_KO.md. Outputs are isolated in minimal_v31.
runSettings = struct();
runSettings.trainSeeds = 271:275;       % fresh development; confirmation: 281:290
runSettings.phase = 'development';
runSettings.train.ppo = true;
runSettings.train.onto_rgat_ppo = true;
runSettings.train.shuffled_rgat_ppo = true;
runSettings.includeDiagnostics = false; % true also evaluates held-out and S1-S3
runSettings.retrain = false;           % reuse only matching checkpoints
runSettings.liveTraining = usejava('desktop');
runSettings.concurrentRuns = 1;
runSettings.figureVisible = false;
runSettings.runSelfTest = true;

landingStudy = runWithSettings(runSettings);

function output = runWithSettings(settings)
root = fileparts(mfilename('fullpath'));
for name = {'orchestration','simulations','algorithms'}
    addpath(fullfile(root,'src',name{1}));
end
names = fieldnames(settings.train);
registry = landing2d.config.methodRegistry();
assert(isequal(sort(names),sort({registry.methods.id}')), ...
    'landing2d:UnknownMethod','Set train flags for all three registered methods.');
for j = 1:numel(names)
    validateattributes(settings.train.(names{j}),{'logical','numeric'},{'scalar','binary'});
end
trained = cellfun(@(name)logical(settings.train.(name)),names);
options = rmfield(settings,'train');
options.trainMethods = names(trained)';
output = landing2d.minimal.runPipeline(options);
end
