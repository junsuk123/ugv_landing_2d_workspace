function out = runAll(options)
% RUNALL inductive_bias_diagnostics_v1 end to end (frozen v5 policies; no training).
%   landing2d.bias_diagnostics.runAll()                       -> results/inductive_bias_diagnostics_v1/
%   landing2d.bias_diagnostics.runAll(struct('smoke',true))   one-seed implementation check in tempdir
% Never overwrites an existing output folder and never opens 9101-9200.
if nargin<1, options = struct(); end
smoke = isfield(options,'smoke') && options.smoke;
d = landing2d.bias_diagnostics.config();
startedAtUtc = datetime('now','TimeZone','UTC');
seeds = struct('rollout',d.rollout.seeds,'branch',d.branch.seeds,'swap',d.typingSwap.seeds);
if smoke
    d.outputDir = fullfile(tempdir,'inductive_bias_diagnostics_smoke');
    if isfolder(d.outputDir), rmdir(d.outputDir,'s'); end
    d.reference.seeds = d.reference.seeds(1); d.reference.stride = 40; d.reference.noiseReplicates = 2;
    seeds = struct('rollout',d.rollout.seeds(1),'branch',d.branch.seeds(1),'swap',d.typingSwap.seeds(1));
else
    assert(~isfolder(d.outputDir),'landing2d:BiasDiagnosticsOverwrite', ...
        'Preserve %s; a new version needs a new folder.',d.outputDir);
end
folders = {'states','q1_state_similarity','q2_state_dependent_action','q3_reward_density', ...
    'q4_action_topology','p6_relation_effect','figures'};
for f = folders, mkdir(fullfile(d.outputDir,f{1})); end
package = dir(fullfile(fileparts(mfilename('fullpath')),'*.m'));
code = arrayfun(@(f)struct('path',string(relativePath(d.root,fullfile(f.folder,f.name))), ...
    'sha256',string(landing2d.bias_diagnostics.fileHash(fullfile(f.folder,f.name)))),package);
if isempty(gcp('nocreate')), parpool('threads'); end
tests = landing2d.bias_diagnostics.selfTest(d);
runs = landing2d.bias_diagnostics.models(d);
fprintf('[bias] reference states\n'); S = landing2d.bias_diagnostics.referenceStates(d);
fprintf('[bias] %d reference states; open-loop probes\n',height(S.states));
[P,importance] = landing2d.bias_diagnostics.probeResponses(runs,S,d);
fprintf('[bias] closed-loop rollouts\n');
[phases,episodes] = landing2d.bias_diagnostics.closedLoop(runs,d,seeds.rollout);
fprintf('[bias] snapshot branches\n'); B = landing2d.bias_diagnostics.branchRollouts(runs,d,seeds.branch);
fprintf('[bias] relation-typing swap\n'); X = landing2d.bias_diagnostics.typingSwap(runs,d,seeds.swap);
fprintf('[bias] tables and figures\n');
tables = landing2d.bias_diagnostics.tables(d,S,P,importance,phases,episodes,B,X,runs);
write(d.outputDir,'states','reference_states',S.states);
names = fieldnames(tables);
for i = 1:numel(names)
    parts = split(string(names{i}),'__');
    write(d.outputDir,char(parts(1)),char(parts(2)),tables.(names{i}));
end
figures = landing2d.bias_diagnostics.plots(tables,d,fullfile(d.outputDir,'figures'));
finishedAtUtc = datetime('now','TimeZone','UTC');
inputs = [string(fullfile(d.root,'results','generalization_v2_calibration','protocol_registration.json')), ...
    string(fullfile(d.v2Evaluation,'generalizationEpisodes.csv')),string(fullfile(d.v2Evaluation,'runManifest.csv')), ...
    string(fullfile(d.v2Evaluation,'generalizationBySeed.csv')),string(fullfile(d.v2Evaluation,'primaryBySeed.csv')), ...
    string(d.ablationSummary)];
evidence = arrayfun(@(p)struct('path',relativePath(d.root,char(p)), ...
    'sha256',string(landing2d.bias_diagnostics.fileHash(char(p)))),inputs);
checkpoints = arrayfun(@(r)struct('MethodId',string(r.id),'TrainSeed',r.trainSeed, ...
    'file',relativePath(d.root,char(r.file)),'fileSha256',r.fileSha256, ...
    'identityHash',string(r.identity.CheckpointHash)),runs);
configuration = rmfield(d,{'c','root'});
configuration.environmentSeedsUsed = struct('reference',d.reference.seeds,'rollout',seeds.rollout, ...
    'branch',seeds.branch,'typingSwap',seeds.swap);
outputs = dir(fullfile(d.outputDir,'**','*.*')); outputs = outputs(~[outputs.isdir]);
written = arrayfun(@(f)struct('path',relativePath(d.outputDir,fullfile(f.folder,f.name)), ...
    'sha256',string(landing2d.bias_diagnostics.fileHash(fullfile(f.folder,f.name)))),outputs);
manifest = struct('version',d.version,'smoke',smoke,'startedAtUtc',string(startedAtUtc), ...
    'finishedAtUtc',string(finishedAtUtc),'matlab',string(version),'configuration',configuration, ...
    'code',code,'checkpoints',checkpoints,'inputs',evidence,'selfTest',tests, ...
    'outputs',written,'training',false,'rewardChanged',false,'confirmationOpened',false, ...
    'referenceStates',height(S.states),'probeRows',height(P), ...
    'closedLoopEpisodes',height(episodes),'branchRows',height(B),'typingSwapEpisodes',height(X));
fid = fopen(fullfile(d.outputDir,'manifest.json'),'w','n','UTF-8'); assert(fid>=0);
fwrite(fid,jsonencode(manifest,'PrettyPrint',true),'char'); fclose(fid);
out = struct('d',d,'tests',tests,'S',S,'probes',P,'phases',phases,'episodes',episodes, ...
    'branches',B,'typingSwap',X,'tables',tables,'figures',figures,'manifest',manifest);
fprintf('[bias] COMPLETE (smoke=%d): %s\n',smoke,d.outputDir);
end

function write(root,folder,name,T)
writetable(T,fullfile(root,folder,[name,'.csv']));
end

function p = relativePath(root,file)
p = strrep(erase(string(file),string(root)+filesep),'\','/');
end
