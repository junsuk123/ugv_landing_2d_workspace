function output = runPipeline(options)
% RUNPIPELINE Registered four-arm direct-mean residual development, retaining plain PPO.
if nargin<1, options = struct(); end
c = landing2d.residual_motion.config(); registry = landing2d.config.methodRegistry(c);
defaults = struct('trainSeeds',registry.trainSeeds.residualDev, ...
    'methods',{{registry.methods.id}},'trainMethods','all','retrain',false, ...
    'liveTraining',usejava('desktop'),'concurrentRuns',1,'concurrentPool','threads', ...
    'figureVisible',false,'runSelfTest',true,'smoke',false,'saveResults',true, ...
    'phase','development','includeDiagnostics',false);
options = landing2d.minimal.options(options,defaults);
assert(strcmp(options.phase,'development'),'landing2d:ConfirmationClosed', ...
    'Confirmation requires a separate frozen release after the development gate.');
assert(isequal(sort(options.trainSeeds),registry.trainSeeds.residualDev) || options.smoke, ...
    'landing2d:ResidualSeeds','Use all five registered development seeds.');
assert(isequal(sort(options.methods),sort({registry.methods.id})), ...
    'landing2d:ResidualArms','The development comparison requires all four methods.');
c.figureVisible = options.figureVisible;
if options.smoke
    c = landing2d.orchestration.smokeConfig(c);
    options.liveTraining = false; options.saveResults = false; options.trainSeeds = 381;
end
tests = struct(); if options.runSelfTest, tests = landing2d.residual_motion.selfTest(); end
trainOptions = rmfield(options,{'figureVisible','runSelfTest','saveResults','phase','includeDiagnostics'});
runs = landing2d.orchestration.trainRuns(c,trainOptions);
folder = ''; figureFolder = '';
if options.saveResults
    development = fullfile(c.outputDir,'development');
    if ~isfolder(development), mkdir(development); end
    folder = fullfile(c.outputDir,'generalization_v1','development','s381-382-383-384-385');
    assert(~isfile(fullfile(folder,'results.mat')),'Preserve completed evaluation.');
    if ~isfolder(folder), mkdir(folder); end
    protocol = c.evaluation; runManifest = struct2table([runs.identity]);
    save(fullfile(folder,'protocol.mat'),'protocol','options','runManifest');
    save(fullfile(c.outputDir,'development','training_complete.mat'),'runs','c','options','-v7.3');
end
results = landing2d.minimal.evaluate(runs,c,options.includeDiagnostics);
results.isSmoke = logical(options.smoke);
gate = struct();
if ~options.smoke, gate = landing2d.residual_motion.developmentGate(runs,results); end
if options.saveResults
    for name = fieldnames(results)'
        if istable(results.(name{1})), writetable(results.(name{1}),fullfile(folder,[name{1},'.csv'])); end
    end
    save(fullfile(folder,'results.mat'),'results','c','options','gate','-v7.3');
    save(fullfile(c.outputDir,'development','gate.mat'),'gate','c','options');
    writetable(gate.validation,fullfile(c.outputDir,'development','validation_gate.csv'));
    figureFolder = fullfile(folder,'figures');
end
figures = landing2d.minimal.plotResults(results,c,options.figureVisible,figureFolder);
disp(results.primaryBySeed); disp(results.primaryContrasts);
output = struct('config',c,'tests',tests,'results',results,'figures',figures,'runs',runs,'gate',gate);
end
