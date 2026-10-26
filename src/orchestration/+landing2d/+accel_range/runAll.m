function out = runAll()
% RUNALL Registered acceleration_range_r1_v1: train 20 fresh models once, evaluate, judge.
% Requires registration.json (landing2d.accel_range.register) and refuses when
% a registered source changed, a new checkpoint already exists or the run was
% completed. Training: seeds 421-425 x four methods, concurrent threads.
% Evaluation: protocol-v2 cells on the v5 environment, 12,000 episodes,
% paired with the stored v5 episodes. No retraining, no seed exclusion.
d = landing2d.accel_range.config();
registrationFile = fullfile(d.outputDir,'registration.json');
registration = jsondecode(fileread(registrationFile));
assert(~isfile(fullfile(d.outputDir,'completed.json')),'landing2d:AccelRangeDone','Preserve the completed run.');
verifySources(d.root,registration.sources);
arms = [];
for s = d.trainSeeds
    arms = [arms,landing2d.config.comparisonArms(d.c,struct('methods',{d.methods},'trainSeed',s))]; %#ok<AGROW>
end
for j = 1:numel(arms)
    assert(~isfile(fullfile(d.c.outputDir,arms(j).config.rl.policyFile)), ...
        'landing2d:AccelRangeCheckpoint','A checkpoint exists before training: %s.',arms(j).config.rl.policyFile);
end
startedAtUtc = string(datetime('now','TimeZone','UTC'));
writeJson(fullfile(d.outputDir,'execution.json'),struct('startedAtUtc',startedAtUtc,'phase','training'));
fprintf('[accel] training 20 fresh models (a2Range %s)\n',mat2str(d.c.experiment.scenario.a2Range));
runs = landing2d.orchestration.trainRuns(d.c,struct('trainSeeds',d.trainSeeds,'methods',{d.methods}, ...
    'concurrentRuns',d.training.concurrentRuns,'concurrentPool',d.training.concurrentPool, ...
    'liveTraining',false,'retrain',false));
assert(numel(runs)==20,'landing2d:AccelRangeRuns','Expected 20 trained runs.');
trainedAtUtc = string(datetime('now','TimeZone','UTC'));
verifySources(d.root,registration.sources);
learning = landing2d.accel_range.learningGate(runs,d);
fprintf('[accel] training done; evaluating 12,000 episodes on the v5 environment\n');
evalRuns = landing2d.accel_range.evaluationRuns(runs,d);
results = landing2d.minimal.evaluate(evalRuns,d.v5,false);
assert(height(results.generalizationEpisodes)==12000);
v5Episodes = readtable(fullfile(d.v5Evaluation,'generalizationEpisodes.csv'),'TextType','string');
A = landing2d.accel_range.analyze(results.generalizationEpisodes,v5Episodes,learning,d);
writetable(results.generalizationEpisodes,fullfile(d.outputDir,'generalizationEpisodes.csv'));
writetable(results.runManifest,fullfile(d.outputDir,'runManifest.csv'));
writetable(results.learningBySeed,fullfile(d.outputDir,'learningBySeed.csv'));
writetable(results.learningCurves,fullfile(d.outputDir,'learningCurves.csv'));
names = {'pairs','byModel','bySeed','cells','risk','byMethod','levels','didBySeed','did', ...
    'learning','failures','checks'};
for i = 1:numel(names)
    writetable(A.(names{i}),fullfile(d.outputDir,[names{i},'.csv']));
end
mkdir(fullfile(d.outputDir,'figures'));
figures = landing2d.accel_range.plots(A,d,fullfile(d.outputDir,'figures'));
save(fullfile(d.outputDir,'results.mat'),'results','A','learning','-v7.3');
verifySources(d.root,registration.sources);
checkpoints = arrayfun(@(r)struct('MethodId',string(r.id),'TrainSeed',r.trainSeed, ...
    'file',relativePath(d.root,char(r.file)),'sha256',string(landing2d.bias_diagnostics.fileHash(r.file)), ...
    'identityHash',string(r.identity.CheckpointHash)),runs);
verdict = struct('verdict',A.verdict,'flags',A.flags, ...
    'note','Development-stage paired comparison on opened seeds; not confirmation, not a TOSM advantage.');
writeJson(fullfile(d.outputDir,'verdict.json'),verdict);
outputs = dir(fullfile(d.outputDir,'**','*.*'));
outputs = outputs(~[outputs.isdir] & ~contains({outputs.folder},'checkpoints'));
written = arrayfun(@(f)struct('path',relativePath(d.outputDir,fullfile(f.folder,f.name)), ...
    'sha256',string(landing2d.bias_diagnostics.fileHash(fullfile(f.folder,f.name)))),outputs);
finishedAtUtc = string(datetime('now','TimeZone','UTC'));
manifest = struct('version',d.version,'startedAtUtc',startedAtUtc,'trainedAtUtc',trainedAtUtc, ...
    'finishedAtUtc',finishedAtUtc,'matlab',string(version),'checkpoints',checkpoints, ...
    'episodes',height(results.generalizationEpisodes),'verdict',A.verdict,'flags',A.flags, ...
    'outputs',written,'confirmationOpened',false,'retrained',false,'seedsExcluded',false);
writeJson(fullfile(d.outputDir,'manifest.json'),manifest);
writeJson(fullfile(d.outputDir,'completed.json'),struct('finishedAtUtc',finishedAtUtc,'verdict',A.verdict));
writeJson(fullfile(d.outputDir,'execution.json'),struct('startedAtUtc',startedAtUtc,'phase','complete', ...
    'finishedAtUtc',finishedAtUtc));
out = struct('d',d,'runs',runs,'results',results,'analysis',A,'figures',figures,'manifest',manifest);
fprintf('[accel] verdict: %s\n[accel] COMPLETE: %s\n',A.verdict,d.outputDir);
end

function verifySources(root,files)
for k = 1:numel(files)
    assert(strcmp(landing2d.bias_diagnostics.fileHash(fullfile(root,files(k).path)),files(k).sha256), ...
        'landing2d:AccelRangeSource','Registered source changed: %s',files(k).path);
end
end

function writeJson(file,value)
fid = fopen(file,'w','n','UTF-8'); assert(fid>=0,'landing2d:AccelRangeFile','Cannot write %s.',file);
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char'); fclose(fid);
end

function p = relativePath(root,file)
p = strrep(erase(string(file),string(root)+filesep),'\','/');
end
