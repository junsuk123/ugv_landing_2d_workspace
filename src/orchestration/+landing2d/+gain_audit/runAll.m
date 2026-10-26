function out = runAll(options)
% RUNALL control_gain_audit_v1 end to end (frozen v5 policies; no training).
%   landing2d.gain_audit.runAll()                       -> results/control_gain_audit_v1/
%   landing2d.gain_audit.runAll(struct('smoke',true))   seed 421 x two environments, in tempdir
% registration.json (code, checkpoints, seeds, gains, criteria) is written
% before the first rollout. Never overwrites an existing output folder and
% never opens 9101-9200. 20 models x 6 cells x 2 gains x 50 environments.
if nargin<1, options = struct(); end
smoke = isfield(options,'smoke') && options.smoke;
d = landing2d.gain_audit.config();
startedAtUtc = datetime('now','TimeZone','UTC');
seeds = d.environmentSeeds; trainSeeds = d.trainSeeds;
if smoke
    d.outputDir = fullfile(tempdir,'control_gain_audit_smoke');
    if isfolder(d.outputDir), rmdir(d.outputDir,'s'); end
    seeds = seeds(1:2); trainSeeds = trainSeeds(1);
else
    assert(~isfolder(d.outputDir),'landing2d:GainAuditOverwrite', ...
        'Preserve %s; a new version needs a new folder.',d.outputDir);
end
mkdir(d.outputDir); mkdir(fullfile(d.outputDir,'figures'));
package = dir(fullfile(fileparts(mfilename('fullpath')),'*.m'));
reused = {'config','condition','models','fileHash'};
reusedFiles = cellfun(@(n)which(['landing2d.bias_diagnostics.',n]),reused,'UniformOutput',false);
codeFiles = [arrayfun(@(f)fullfile(f.folder,f.name),package,'UniformOutput',false);reusedFiles(:); ...
    {which('landing2d.rl.rolloutEpisodeV2');which('landing2d.evaluation.episodeMetrics')}];
code = cellfun(@(p)struct('path',relativePath(d.root,p), ...
    'sha256',string(landing2d.bias_diagnostics.fileHash(p))),codeFiles);
runs = landing2d.bias_diagnostics.models(d,trainSeeds);
checkpoints = arrayfun(@(r)struct('MethodId',string(r.id),'TrainSeed',r.trainSeed, ...
    'file',relativePath(d.root,char(r.file)),'fileSha256',r.fileSha256, ...
    'identityHash',string(r.identity.CheckpointHash)),runs);
storedEpisodes = fullfile(d.v2Evaluation,'generalizationEpisodes.csv');
registration = struct('version',d.version,'smoke',smoke,'registeredAtUtc',string(startedAtUtc), ...
    'decision','Codex GO 2026-10-26 (reduced O3: k in {1,2}, 12,000 episodes)', ...
    'intervention','a_x_norm = clip(k*tanh(mu_x),-1,1); a_z_norm = tanh(mu_z)', ...
    'gains',d.gains,'trainSeeds',trainSeeds,'methods',{d.methods},'cells',{d.cells}, ...
    'environmentSeeds',seeds,'forbiddenEnvironmentSeeds',d.forbiddenEnvironmentSeeds, ...
    'reproduction',d.reproduction,'criteria',d.criteria, ...
    'aggregation',['per model mean over environments of paired k=2-k=1 differences; ' ...
        'per training seed equal-weight mean of four methods; 95% t interval over 5 seed blocks (df=4)'], ...
    'storedEpisodes',struct('path',relativePath(d.root,storedEpisodes), ...
        'sha256',string(landing2d.bias_diagnostics.fileHash(storedEpisodes))), ...
    'code',code,'checkpoints',checkpoints,'training',false,'confirmationOpened',false);
writeJson(fullfile(d.outputDir,'registration.json'),registration);
if isempty(gcp('nocreate')), parpool('threads'); end
tests = landing2d.gain_audit.selfTest(d);
fprintf('[gain] self-test passed; %d models x %d cells x %d gains x %d environments\n', ...
    numel(runs),size(d.cells,1),numel(d.gains),numel(seeds));
E = landing2d.gain_audit.episodes(runs,d,seeds);
R = landing2d.gain_audit.reproduce(E,d);
fprintf('[gain] k = 1 reproduces %d stored v2 episodes (max aim difference %.3g m)\n', ...
    height(R),max(R.AimAbsDiff_m));
A = landing2d.gain_audit.analyze(E,d);
writetable(E,fullfile(d.outputDir,'episodes.csv'));
writetable(R,fullfile(d.outputDir,'reproduction.csv'));
names = {'pairs','byModel','bySeed','cells','byMethod','levels','didBySeed','did','failures','checks'};
for i = 1:numel(names)
    writetable(A.(names{i}),fullfile(d.outputDir,[names{i},'.csv']));
end
figures = landing2d.gain_audit.plots(A,d,fullfile(d.outputDir,'figures'));
after = arrayfun(@(r)string(landing2d.bias_diagnostics.fileHash(r.file)),runs);
assert(isequal(after(:),[runs.fileSha256]'),'landing2d:GainAuditCheckpoint', ...
    'Checkpoint files changed during the audit.');
finishedAtUtc = datetime('now','TimeZone','UTC');
verdict = struct('verdict',A.verdict,'flags',A.flags,'smoke',smoke, ...
    'note','Exploratory frozen-policy audit on opened development seeds; not confirmatory, not a TOSM advantage.');
writeJson(fullfile(d.outputDir,'verdict.json'),verdict);
outputs = dir(fullfile(d.outputDir,'**','*.*')); outputs = outputs(~[outputs.isdir]);
written = arrayfun(@(f)struct('path',relativePath(d.outputDir,fullfile(f.folder,f.name)), ...
    'sha256',string(landing2d.bias_diagnostics.fileHash(fullfile(f.folder,f.name)))),outputs);
manifest = struct('version',d.version,'smoke',smoke,'startedAtUtc',string(startedAtUtc), ...
    'finishedAtUtc',string(finishedAtUtc),'matlab',string(version),'selfTest',tests, ...
    'episodes',height(E),'reproduced',height(R),'verdict',A.verdict,'flags',A.flags, ...
    'checkpointsUnchanged',true,'outputs',written,'training',false,'rewardChanged',false, ...
    'confirmationOpened',false);
writeJson(fullfile(d.outputDir,'manifest.json'),manifest);
out = struct('d',d,'tests',tests,'episodes',E,'reproduction',R,'analysis',A, ...
    'figures',figures,'manifest',manifest);
fprintf('[gain] verdict: %s\n[gain] COMPLETE (smoke=%d): %s\n',A.verdict,smoke,d.outputDir);
end

function writeJson(file,value)
fid = fopen(file,'w','n','UTF-8'); assert(fid>=0,'landing2d:GainAuditFile','Cannot write %s.',file);
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char'); fclose(fid);
end

function p = relativePath(root,file)
p = strrep(erase(string(file),string(root)+filesep),'\','/');
end
