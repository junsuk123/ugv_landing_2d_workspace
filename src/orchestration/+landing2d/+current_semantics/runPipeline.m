function out = runPipeline(options)
% RUNPIPELINE One registered phase; confirmation is explicit and gated.
if nargin<1, options=struct(); end
defaults=struct('root',landing2d.orchestration.projectRoot(),'phase','development', ...
    'smoke',false,'autoRegister',true,'runSelfTest',true,'concurrentRuns',1, ...
    'resumeEvaluation',false);
options=landing2d.minimal.options(options,defaults);
assert(ismember(options.phase,{'development','confirmation'}));
validateattributes(options.concurrentRuns,{'numeric'},{'scalar','integer','positive'});
d=landing2d.current_semantics.config(options.root);
if options.smoke
    [tests,runs,results]=landing2d.current_semantics.smokeTest(d);
    out=struct('config',d.c,'d',d,'tests',tests,'runs',runs,'results',results,'isSmoke',true);
    return;
end
folder=fullfile(d.outputDir,options.phase);
assert(~isfile(fullfile(folder,'completed.json')),'landing2d:CurrentSemanticsDone','Preserve the completed phase.');
executionFile=fullfile(folder,'execution.json');
if isfile(executionFile)
    assert(options.resumeEvaluation,'landing2d:CurrentSemanticsInterrupted', ...
        ['An execution exists. resumeEvaluation=true can reuse sealed completed training; ' ...
         'interrupted training requires audited manual recovery and is never automatically retrained.']);
elseif options.resumeEvaluation
    error('landing2d:CurrentSemanticsResume','There is no interrupted execution to resume.');
end
registrationFile=fullfile(folder,'registration.json');
assert(~options.resumeEvaluation || isfile(registrationFile), ...
    'landing2d:CurrentSemanticsResume','A resumed evaluation requires its original registration.');
tests=struct();
if ~isfile(registrationFile)
    assert(options.autoRegister && options.runSelfTest, ...
        'landing2d:CurrentSemanticsNativeGate','Run native checks and register this frozen phase first.');
    if strcmp(options.phase,'confirmation')
        prior=fullfile(d.outputDir,'development','registration.json');
        assert(isfile(prior),'landing2d:CurrentSemanticsConfirmationClosed','Development has not been registered.');
        developmentRegistration=jsondecode(fileread(prior));
        landing2d.current_semantics.verifySources(d.root,developmentRegistration.sources);
        tests=developmentRegistration.nativeChecks;
    else
        tests=landing2d.current_semantics.smokeTest(d);
    end
    landing2d.current_semantics.register(options.phase,tests,d.root);
end
registration=landing2d.current_semantics.verifyRegistration(d,options.phase);
if strcmp(options.phase,'development'), seeds=d.developmentSeeds; else, seeds=d.confirmationSeeds; end
resumedFrom='';
if options.resumeEvaluation
    oldExecution=jsondecode(fileread(executionFile));
    runs=landing2d.current_semantics.restoreTraining(d,seeds,folder);
    started=string(oldExecution.startedAtUtc);
    resumedFrom=archiveEvaluation(folder);
else
    % loadOrTrainAgent otherwise silently retrains incompatible checkpoints.
    % Refuse every pre-existing checkpoint before the one-shot training starts.
    for seed=seeds
        arms=landing2d.config.comparisonArms(d.c,struct('methods',{d.methods},'trainSeed',seed));
        for k=1:numel(arms)
            assert(~isfile(fullfile(d.c.outputDir,arms(k).config.rl.policyFile)), ...
                'landing2d:CurrentSemanticsCheckpoint','A checkpoint already exists for %s seed %d.',arms(k).id,seed);
        end
    end
    started=string(datetime('now','TimeZone','UTC'));
    landing2d.current_semantics.writeJson(executionFile, ...
        struct('startedAtUtc',started,'phase','training','options',options));
    runs=landing2d.orchestration.trainRuns(d.c,struct('trainSeeds',seeds,'methods',{d.methods}, ...
        'trainMethods','all','retrain',false,'smoke',false,'liveTraining',false, ...
        'concurrentRuns',options.concurrentRuns,'concurrentPool',d.training.concurrentPool));
    assert(numel(runs)==4*numel(seeds));
    landing2d.current_semantics.verifySources(d.root,registration.sources);
    trainingFile=fullfile(folder,'training_complete.mat');
    save(trainingFile,'runs','d','options','-v7.3');
    trainingSeal=struct('fileSha256',landing2d.bias_diagnostics.fileHash(trainingFile), ...
        'trainSeeds',seeds,'methods',{d.methods}, ...
        'checkpoints',landing2d.current_semantics.checkpointRecords(runs));
    landing2d.current_semantics.writeJson(fullfile(folder,'training_manifest.json'),trainingSeal);
end
landing2d.current_semantics.writeJson(fullfile(folder,'execution.json'), ...
    struct('startedAtUtc',started,'phase','evaluation','options',options,'resumedFrom',resumedFrom));
results=landing2d.current_semantics.evaluate(runs,d,options.phase,false);
diagnostics=landing2d.current_semantics.semanticDiagnostics(runs,d);
for name=fieldnames(diagnostics)'
    results.(name{1})=diagnostics.(name{1});
end
decision=landing2d.current_semantics.gate(runs,results,d,options.phase);
for name=fieldnames(results)'
    if istable(results.(name{1}))
        writetable(results.(name{1}),fullfile(folder,[name{1},'.csv']));
    end
end
writetable(decision.validation,fullfile(folder,'validationBySeed.csv'));
save(fullfile(folder,'results.mat'),'results','decision','d','options','-v7.3');
landing2d.current_semantics.writeJson(fullfile(folder,'gate.json'),decision);
landing2d.current_semantics.verifySources(d.root,registration.sources);
finished=string(datetime('now','TimeZone','UTC'));
checkpoints=landing2d.current_semantics.checkpointRecords(runs);
landing2d.current_semantics.writeJson(fullfile(folder,'execution.json'), ...
    struct('startedAtUtc',started,'finishedAtUtc',finished,'phase','complete','options',options,'resumedFrom',resumedFrom));
outputs=dir(fullfile(folder,'*')); outputs=outputs(~[outputs.isdir]);
hashes=arrayfun(@(f)struct('file',string(f.name), ...
    'sha256',string(landing2d.bias_diagnostics.fileHash(fullfile(f.folder,f.name)))),outputs);
manifest=struct('version',d.version,'phase',options.phase,'startedAtUtc',started, ...
    'finishedAtUtc',finished,'matlab',string(version),'trainingSeeds',seeds, ...
    'models',numel(runs),'episodes',height(results.generalizationEpisodes), ...
    'checkpoints',checkpoints,'outputs',hashes,'gatePassed',decision.passed, ...
    'seedsExcluded',false,'performanceEvidence',true,'resumedEvaluation',logical(options.resumeEvaluation), ...
    'preservedAttempt',resumedFrom);
landing2d.current_semantics.writeJson(fullfile(folder,'manifest.json'),manifest);
landing2d.current_semantics.writeJson(fullfile(folder,'completed.json'), ...
    struct('finishedAtUtc',finished,'gatePassed',decision.passed,'goalComplete',decision.goalComplete));
out=struct('config',d.c,'d',d,'tests',tests,'runs',runs,'results',results, ...
    'gate',decision,'manifest',manifest,'isSmoke',false);
disp(results.primaryContrasts); disp(results.guardContrasts);
fprintf('[current semantics] %s finished; gate passed = %d\n',options.phase,decision.passed);
end

function archive = archiveEvaluation(folder)
% Preserve incomplete output and execution logs before deterministic reevaluation.
attempt=1;
while isfolder(fullfile(folder,sprintf('interrupted_evaluation_attempt_%03d',attempt)))
    attempt=attempt+1;
end
archive=fullfile(folder,sprintf('interrupted_evaluation_attempt_%03d',attempt));
mkdir(archive);
keep={'registration.json','training_complete.mat','training_manifest.json'};
files=dir(fullfile(folder,'*')); files=files(~[files.isdir]);
for k=1:numel(files)
    if ismember(files(k).name,keep), continue; end
    if strcmp(files(k).name,'execution.json')
        % Keep the live interruption marker until the new phase record is written.
        [ok,message]=copyfile(fullfile(folder,files(k).name),fullfile(archive,files(k).name));
    else
        [ok,message]=movefile(fullfile(folder,files(k).name),fullfile(archive,files(k).name));
    end
    assert(ok,'landing2d:CurrentSemanticsResume','Could not preserve an interrupted output: %s',message);
end
end
