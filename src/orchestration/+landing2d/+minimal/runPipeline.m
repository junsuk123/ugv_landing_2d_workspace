function output = runPipeline(options)
% RUNPIPELINE v3.1 shared dynamic attention; fixed generalization_v1 protocol.
if nargin<1, options = struct(); end
registry = landing2d.config.methodRegistry();
defaults = struct('trainSeeds',registry.trainSeeds.minimalV31Dev, ...
    'methods',{{registry.methods.id}},'trainMethods','all','retrain',false, ...
    'liveTraining',usejava('desktop'),'concurrentRuns',1,'concurrentPool','threads', ...
    'figureVisible',false,'runSelfTest',true,'smoke',false,'saveResults',true, ...
    'phase','development','includeDiagnostics',false);
options = landing2d.minimal.options(options,defaults);
c = landing2d.minimal.config(); c.figureVisible = options.figureVisible;
assert(ismember(options.phase,{'development','confirmation'}), ...
    'landing2d:StudyPhase','Use development or confirmation.');
allowedSeeds = registry.trainSeeds.minimalV31Dev;
if strcmp(options.phase,'confirmation')
    allowedSeeds = registry.trainSeeds.minimalV31Confirm;
    c.evaluation.generalization.seedOffset = 100;
end
assert(all(ismember(options.trainSeeds,allowedSeeds)) && ...
    numel(unique(options.trainSeeds))==numel(options.trainSeeds), ...
    'landing2d:StudySeeds','Use distinct registered seeds for the selected phase.');
c.evaluation.generalization.phase = options.phase;
if options.smoke
    c = landing2d.orchestration.smokeConfig(c);
    options.liveTraining = false; options.saveResults = false;
    options.trainSeeds = registry.trainSeeds.minimalV31Dev(1);
    options.phase = 'development'; options.includeDiagnostics = true;
    c.evaluation.generalization.phase = options.phase;
    c.evaluation.generalization.seedOffset = 0;
end
fprintf('\nMinimal v3.1 | shared two-hop dynamic attention | %s | seeds %s\n',options.phase,mat2str(options.trainSeeds));
tests = table();
if options.runSelfTest, tests = landing2d.minimal.selfTest(); end
trainOptions = rmfield(options,{'figureVisible','runSelfTest','saveResults','phase','includeDiagnostics'});
runs = landing2d.orchestration.trainRuns(c,trainOptions);
folder = ''; figureFolder = '';
if options.saveResults
    seedLabel = strjoin(string(sort(options.trainSeeds)),'-');
    folder = fullfile(c.outputDir,'generalization_v1',options.phase,char("s"+seedLabel));
    if ~isfolder(folder), mkdir(folder); end
    % Register the evaluation and the validation-selected checkpoint hashes
    % BEFORE observing any OOD outcome. Original v3 results stay untouched.
    protocol = c.evaluation; runManifest = struct2table([runs.identity]); %#ok<NASGU>
    save(fullfile(folder,'protocol.mat'),'protocol','options','runManifest');
end
results = landing2d.minimal.evaluate(runs,c,options.includeDiagnostics);
results.isSmoke = logical(options.smoke);
if options.saveResults
    for name = fieldnames(results)'
        if istable(results.(name{1}))
            writetable(results.(name{1}),fullfile(folder,[name{1},'.csv']));
        end
    end
    save(fullfile(folder,'results.mat'),'results','c','options','-v7.3');
    figureFolder = fullfile(folder,'figures');
end
figures = landing2d.minimal.plotResults(results,c,options.figureVisible,figureFolder);
disp(results.primaryBySeed);
disp(results.primaryContrasts(:,{'Contrast','Seeds','Delta_OODSuccess','PrimaryLower','PrimaryUpper'}));
fprintf('No method claim follows from a smoke run or a single training seed.\n');
output = struct('config',c,'tests',tests,'results',results,'figures',figures,'runs',runs);
end
