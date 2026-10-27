function out = runDevelopment(options)
% RUNDEVELOPMENT Registered relational_residual_v6 development: 451-455 x four methods, protocol v2.
%   landing2d.residual_soft.runDevelopment()                      registered run
%   landing2d.residual_soft.runDevelopment(struct('smoke',true))  seed 451, 1 update, 1 episode/cell, tempdir
% Requires development/registration.json (landing2d.residual_soft.register);
% refuses a changed registered source, an existing checkpoint of these seeds or
% a completed run. Trains 20 fresh models once, evaluates the 12,000 protocol-v2
% development episodes (9001-9100) and applies the registered development gate.
% The confirmation is never opened here.
if nargin<1, options = struct(); end
smoke = isfield(options,'smoke') && options.smoke;
d = landing2d.residual_soft.config();
folder = fullfile(d.outputDir,'development');
if smoke
    d.c = landing2d.orchestration.smokeConfig(d.c); d.developmentSeeds = 451;
    d.outputDir = fullfile(tempdir,'relational_residual_v6_smoke'); d.c.outputDir = d.outputDir;
    if isfolder(d.outputDir), rmdir(d.outputDir,'s'); end
    folder = fullfile(d.outputDir,'development'); mkdir(folder);
    registration = struct('sources',struct('path',{},'sha256',{}));
else
    registration = jsondecode(fileread(fullfile(folder,'registration.json')));
    assert(~isfile(fullfile(folder,'completed.json')),'landing2d:ResidualV6Done','Preserve the completed development.');
    assert(isequal(registration.trainSeeds(:)',d.developmentSeeds),'landing2d:ResidualV6Seeds','Registered seeds differ.');
end
verifySources(d.root,registration.sources);
arms = [];
for s = d.developmentSeeds
    arms = [arms,landing2d.config.comparisonArms(d.c,struct('methods',{d.methods},'trainSeed',s))]; %#ok<AGROW>
end
for j = 1:numel(arms)
    assert(~isfile(fullfile(d.c.outputDir,arms(j).config.rl.policyFile)),'landing2d:ResidualV6Checkpoint', ...
        'A checkpoint exists before training: %s.',arms(j).config.rl.policyFile);
end
startedAtUtc = string(datetime('now','TimeZone','UTC'));
writeJson(fullfile(folder,'execution.json'),struct('startedAtUtc',startedAtUtc,'phase','training'));
fprintf('[v6] development training: 20 fresh models, seeds %s\n',mat2str(d.developmentSeeds));
runs = landing2d.orchestration.trainRuns(d.c,struct('trainSeeds',d.developmentSeeds,'methods',{d.methods}, ...
    'concurrentRuns',d.training.concurrentRuns,'concurrentPool',d.training.concurrentPool, ...
    'liveTraining',false,'retrain',false));
assert(numel(runs)==4*numel(d.developmentSeeds));
trainedAtUtc = string(datetime('now','TimeZone','UTC'));
verifySources(d.root,registration.sources);
fprintf('[v6] evaluating the protocol-v2 development episodes\n');
results = landing2d.minimal.evaluate(runs,d.c,false);
expected = numel(runs)*size(d.c.evaluation.generalization.conditions,2)*2*d.c.evaluation.generalization.episodes;
assert(height(results.generalizationEpisodes)==expected && all(ismember(results.generalizationEpisodes.EpisodeSeed,d.developmentEnvironments)));
gate = landing2d.residual_soft.developmentGate(runs,results,d.developmentSeeds);
for name = fieldnames(results)'
    if istable(results.(name{1})), writetable(results.(name{1}),fullfile(folder,[name{1},'.csv'])); end
end
writetable(gate.validation,fullfile(folder,'validation_gate.csv'));
figures = landing2d.minimal.plotResults(results,d.c,false,fullfile(folder,'figures'));
save(fullfile(folder,'results.mat'),'results','gate','-v7.3');
verifySources(d.root,registration.sources);
checkpoints = arrayfun(@(r)struct('MethodId',string(r.id),'TrainSeed',r.trainSeed, ...
    'file',relativePath(d.root,char(r.file)),'sha256',string(landing2d.bias_diagnostics.fileHash(r.file)), ...
    'identityHash',string(r.identity.CheckpointHash)),runs);
summary = struct('learnabilityPassed',gate.learnabilityPassed,'oodMeanDirectionPassed',gate.oodMeanDirectionPassed, ...
    'robustMeanDirectionPassed',gate.robustMeanDirectionPassed,'passed',gate.passed, ...
    'primaryContrasts',results.primaryContrasts(:,{'MethodA','MethodB','Delta_OODSuccess','PrimaryLower','PrimaryUpper'}));
writeJson(fullfile(folder,'gate.json'),summary);
outputs = dir(fullfile(folder,'**','*.*')); outputs = outputs(~[outputs.isdir]);
written = arrayfun(@(f)struct('path',relativePath(folder,fullfile(f.folder,f.name)), ...
    'sha256',string(landing2d.bias_diagnostics.fileHash(fullfile(f.folder,f.name)))),outputs);
finishedAtUtc = string(datetime('now','TimeZone','UTC'));
manifest = struct('version',d.version,'phase','development','smoke',smoke,'startedAtUtc',startedAtUtc, ...
    'trainedAtUtc',trainedAtUtc,'finishedAtUtc',finishedAtUtc,'matlab',string(version), ...
    'checkpoints',checkpoints,'episodes',height(results.generalizationEpisodes),'gatePassed',gate.passed, ...
    'outputs',written,'confirmationOpened',false,'retrained',false,'seedsExcluded',false);
writeJson(fullfile(folder,'manifest.json'),manifest);
writeJson(fullfile(folder,'completed.json'),struct('finishedAtUtc',finishedAtUtc,'gatePassed',gate.passed));
writeJson(fullfile(folder,'execution.json'),struct('startedAtUtc',startedAtUtc,'phase','complete','finishedAtUtc',finishedAtUtc));
out = struct('d',d,'runs',runs,'results',results,'gate',gate,'figures',figures,'manifest',manifest);
disp(gate.validation); disp(results.primaryContrasts(:,{'MethodA','MethodB','Delta_OODSuccess','PrimaryLower','PrimaryUpper'}));
fprintf('[v6] development gate passed = %d\n[v6] COMPLETE: %s\n',gate.passed,folder);
end

function verifySources(root,files)
for k = 1:numel(files)
    assert(strcmp(landing2d.bias_diagnostics.fileHash(fullfile(root,files(k).path)),files(k).sha256), ...
        'landing2d:ResidualV6Source','Registered source changed: %s',files(k).path);
end
end

function writeJson(file,value)
fid = fopen(file,'w','n','UTF-8'); assert(fid>=0,'landing2d:ResidualV6File','Cannot write %s.',file);
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char'); fclose(fid);
end

function p = relativePath(root,file)
p = strrep(erase(string(file),string(root)+filesep),'\','/');
end
