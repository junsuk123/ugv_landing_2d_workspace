function out = runAll(options)
% RUNALL response_gain_r1_v1 (D1): frozen Q2 probes and branches, R1 versus v5.
%   landing2d.response_gain.runAll()                      -> results/response_gain_r1_v1/
%   landing2d.response_gain.runAll(struct('smoke',true))  seed 421, one reference and branch seed, tempdir
% registration.json (code, checkpoints, rules) is written before any probe.
% Integrity: the Q2 code equals the SHA-256 in the inductive_bias_diagnostics_v1
% manifest; the regenerated reference states equal reference_states.csv; the
% v5 probe means reproduce q2 by_seed.csv; the v5 branch PPO/421/9001
% reproduces branch_rows.csv; every branch keeps its Delta = 0 replay check.
% Never overwrites an existing output folder; never opens 9101-9200.
if nargin<1, options = struct(); end
smoke = isfield(options,'smoke') && options.smoke;
d = landing2d.response_gain.config();
trainSeeds = d.trainSeeds; branchSeeds = d.branch.seeds;
if smoke
    d.outputDir = fullfile(tempdir,'response_gain_smoke');
    if isfolder(d.outputDir), rmdir(d.outputDir,'s'); end
    trainSeeds = trainSeeds(1); branchSeeds = branchSeeds(1);
    d.reference.seeds = d.reference.seeds(1);
else
    assert(~isfolder(d.outputDir),'landing2d:ResponseGainOverwrite','Preserve %s.',d.outputDir);
end
mkdir(d.outputDir); mkdir(fullfile(d.outputDir,'figures'));
startedAtUtc = string(datetime('now','TimeZone','UTC'));
q2Manifest = jsondecode(fileread(fullfile(d.q2Results,'manifest.json')));
for k = 1:numel(q2Manifest.code)
    file = fullfile(d.root,q2Manifest.code(k).path);
    assert(strcmp(landing2d.bias_diagnostics.fileHash(file),q2Manifest.code(k).sha256), ...
        'landing2d:ResponseGainQ2Code','Q2 code changed since the inductive diagnostics: %s',q2Manifest.code(k).path);
end
package = dir(fullfile(fileparts(mfilename('fullpath')),'*.m'));
codeFiles = [arrayfun(@(f)fullfile(f.folder,f.name),package,'UniformOutput',false); ...
    {which('landing2d.accel_range.config');which('landing2d.accel_range.evaluationRuns')}];
code = cellfun(@(p)struct('path',relativePath(d.root,p),'sha256',string(landing2d.bias_diagnostics.fileHash(p))),codeFiles);
[v5,r1] = landing2d.response_gain.models(d,trainSeeds);
checkpoints = [arrayfun(@(r)struct('Model',"v5",'MethodId',string(r.id),'TrainSeed',r.trainSeed, ...
    'fileSha256',r.fileSha256,'identityHash',string(r.identity.CheckpointHash)),v5); ...
    arrayfun(@(r)struct('Model',"r1",'MethodId',string(r.id),'TrainSeed',r.trainSeed, ...
    'fileSha256',r.fileSha256,'identityHash',string(r.identity.CheckpointHash)),r1)];
rules = struct('primaryFamily',d.primaryFamily,'primary',{d.primary},'secondary',{d.secondary}, ...
    'confidence',d.confidence,'directionConfidence',d.directionConfidence, ...
    'labels',{{'increase in the reference direction: Bonferroni low > 0', ...
        'decrease in the reference direction: Bonferroni high < 0','no change detected: otherwise'}}, ...
    'branchReproduction',d.branchReproduction,'branchDelta','normalized a_x +/-0.25 for 5 decisions, clipped', ...
    'link','Spearman dRugvX/dRposX/dRdroneXNeg (motion_v2) vs R1 motion OOD dS, descriptive');
registration = struct('version',d.version,'smoke',smoke,'registeredAtUtc',startedAtUtc, ...
    'approval','User "1" (2026-10-26): run D1; no training, no checkpoint reselection, R1 verdict unchanged.', ...
    'decision','Codex REVISE incorporated (gain vector, Bonferroni, branch pairing, state arrays)', ...
    'trainSeeds',trainSeeds,'referenceSeeds',d.reference.seeds,'branchSeeds',branchSeeds, ...
    'rules',rules,'code',code,'checkpoints',checkpoints,'q2Code',q2Manifest.code, ...
    'training',false,'confirmationOpened',false);
writeJson(fullfile(d.outputDir,'registration.json'),registration);
if isempty(gcp('nocreate')), parpool('threads'); end

fprintf('[gain-r1] reference states\n');
S = landing2d.bias_diagnostics.referenceStates(d);
stored = readtable(fullfile(d.q2Results,'states','reference_states.csv'),'TextType','string');
stored = stored(ismember(stored.EnvironmentSeed,d.reference.seeds),:);
statesEqual(S.states,stored,d.reproductionTolerance);
save(fullfile(d.outputDir,'reference_arrays.mat'),'S','-v7.3');

fprintf('[gain-r1] probes: %d v5 and %d R1 models\n',numel(v5),numel(r1));
[P0,~] = landing2d.bias_diagnostics.probeResponses(v5,S,d);
[P1,~] = landing2d.bias_diagnostics.probeResponses(r1,S,d);
q2Stored = readtable(fullfile(d.q2Results,'q2_state_dependent_action','by_seed.csv'),'TextType','string');
if ~smoke, probeReproduced(P0,q2Stored,d); end

fprintf('[gain-r1] branches: R1 on %d environments, v5 reproduction %s/%d/%d\n',numel(branchSeeds), ...
    d.branchReproduction.MethodId,d.branchReproduction.TrainSeed,d.branchReproduction.EnvironmentSeed);
B1 = landing2d.bias_diagnostics.branchRollouts(r1,d,branchSeeds);
B0 = readtable(fullfile(d.q2Results,'q2_state_dependent_action','branch_rows.csv'),'TextType','string');
B0 = B0(ismember(B0.TrainSeed,trainSeeds) & ismember(B0.EnvironmentSeed,branchSeeds),:);
target = v5(strcmp({v5.id},d.branchReproduction.MethodId) & [v5.trainSeed]==d.branchReproduction.TrainSeed);
replay = landing2d.bias_diagnostics.branchRollouts(target,d,d.branchReproduction.EnvironmentSeed);
branchReproduced(replay,B0,d);

link = readtable(fullfile(d.r1Results,'byModel.csv'),'TextType','string');
link = link(ismember(link.TrainSeed,trainSeeds),:);
if smoke, d.trainSeeds = trainSeeds; end
A = landing2d.response_gain.analyze(P0,P1,B0,B1,link,d);
writetable(P0,fullfile(d.outputDir,'probe_rows_v5.csv')); writetable(P1,fullfile(d.outputDir,'probe_rows_r1.csv'));
writetable(B1,fullfile(d.outputDir,'branch_rows_r1.csv'));
names = {'byModel','bySeed','summary','direction','verdicts','levels','byMethod','branchModel', ...
    'branchCommon','branchCounts','branchSeed','branchSummary','link','correlation'};
for i = 1:numel(names), writetable(A.(names{i}),fullfile(d.outputDir,[names{i},'.csv'])); end
figures = landing2d.response_gain.plots(A,d,fullfile(d.outputDir,'figures'));
finishedAtUtc = string(datetime('now','TimeZone','UTC'));
outputs = dir(fullfile(d.outputDir,'**','*.*')); outputs = outputs(~[outputs.isdir]);
written = arrayfun(@(f)struct('path',relativePath(d.outputDir,fullfile(f.folder,f.name)), ...
    'sha256',string(landing2d.bias_diagnostics.fileHash(fullfile(f.folder,f.name)))),outputs);
manifest = struct('version',d.version,'smoke',smoke,'startedAtUtc',startedAtUtc,'finishedAtUtc',finishedAtUtc, ...
    'matlab',string(version),'referenceStates',height(S.states),'probeRows',[height(P0),height(P1)], ...
    'branchRowsR1',height(B1),'verdicts',A.verdicts,'outputs',written,'training',false, ...
    'checkpointReselection',false,'confirmationOpened',false);
writeJson(fullfile(d.outputDir,'manifest.json'),manifest);
out = struct('d',d,'S',S,'P0',P0,'P1',P1,'B0',B0,'B1',B1,'analysis',A,'figures',figures,'manifest',manifest);
disp(A.verdicts);
fprintf('[gain-r1] COMPLETE (smoke=%d): %s\n',smoke,d.outputDir);
end

function statesEqual(T,stored,tol)
T.Family = string(T.Family); T.Class = string(T.Class);
assert(height(T)==height(stored),'landing2d:ResponseGainStates','%d states, stored %d.',height(T),height(stored));
for v = stored.Properties.VariableNames
    a = T.(v{1}); b = stored.(v{1});
    if isstring(b), ok = all(string(a)==b);
    else, ok = all(abs(double(a)-double(b))<=tol*max(1,abs(double(b))));
    end
    assert(ok,'landing2d:ResponseGainStates','Reference state column %s differs.',v{1});
end
end

function probeReproduced(P,stored,d)
P.MethodId = string(P.MethodId); P.Family = string(P.Family);
metrics = {'RugvX','RdroneX','RposX','StaleDeltaX','AgreeUgvX','AgreeDroneX','AgreePosX'};
[g,T] = findgroups(P(:,{'MethodId','TrainSeed','Family'}));
for m = metrics, T.(m{1}) = splitapply(@(x)mean(x,'omitnan'),double(P.(m{1})),g); end
reference = renamevars(stored(:,[{'MethodId','TrainSeed','Family'},metrics]),metrics,strcat('Stored',metrics));
J = innerjoin(T,reference,'Keys',{'MethodId','TrainSeed','Family'});
assert(height(J)==height(T) && height(J)==40,'landing2d:ResponseGainProbe','v5 probe rows must pair with by_seed.csv.');
for m = metrics
    assert(max(abs(J.(m{1})-J.(['Stored',m{1}])))<=d.reproductionTolerance, ...
        'landing2d:ResponseGainProbe','v5 %s does not reproduce the stored Q2 value.',m{1});
end
end

function branchReproduced(replay,B0,d)
k = d.branchReproduction;
S0 = B0(B0.MethodId==k.MethodId & B0.TrainSeed==k.TrainSeed & B0.EnvironmentSeed==k.EnvironmentSeed,:);
replay.Point = string(replay.Point);
assert(height(replay)==height(S0) && height(S0)>0,'landing2d:ResponseGainBranch','Branch rows must match.');
for i = 1:height(replay)
    s = S0(S0.Point==replay.Point(i) & abs(S0.Delta-replay.Delta(i))<1e-12,:);
    assert(height(s)==1 && s.Success==replay.Success(i) ...
        && abs(s.ReturnToGo-replay.ReturnToGo(i))<=d.reproductionTolerance*max(1,abs(s.ReturnToGo)), ...
        'landing2d:ResponseGainBranch','v5 branch %s Delta %g differs from the stored row.',replay.Point(i),replay.Delta(i));
end
end

function writeJson(file,value)
fid = fopen(file,'w','n','UTF-8'); assert(fid>=0);
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char'); fclose(fid);
end

function p = relativePath(root,file)
p = strrep(erase(string(file),string(root)+filesep),'\','/');
end
