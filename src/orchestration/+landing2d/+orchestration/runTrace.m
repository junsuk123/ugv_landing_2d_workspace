function output = runTrace(caseId,options)
% RUNTRACE  Decision trace of the trained TOSM R-GAT Actor on one controlled case.
%   landing2d.orchestration.runTrace('S4')                           % live dashboard
%   landing2d.orchestration.runTrace('S1',struct('visible',false))   % headless record + export
%   landing2d.orchestration.runTrace([],struct('replay',file))       % replay, no policy call
% Entry point: run_scenario(caseId,struct('trace',true,...)) and
% run_scenario([],struct('replay',file)). Options:
%   trainSeed      onto_rgat_ppo checkpoint (default registry.trainSeeds.depth4(1)
%                  = 21, the first relational-policy-v2.2 seed; fixed before
%                  looking at any trace, never chosen from S1-S4 results)
%   replicate      noise replicate r of the case (episode seed = factorial
%                  seed + r - 1, default 1, landing2d.evaluation.replicateSeeds)
%   deterministic  evaluation policy (default true); false also records the
%                  sampled action next to the mean-based preview
%   visible        open the dashboard (default true)
%   live           stream decisions into the dashboard while the episode runs
%                  (default = visible): the callback paces the episode to the
%                  display clock (simulation time / speed); actions, RNG and
%                  outcome do not depend on the display (A09)
%   speed, staged  playback speed (default 1) / explanatory staged sweep
%   outputDir      default results/trace
%   png, video     export a PNG (default true) / MP4 (default false)
%   mock           TEST ONLY: untrained agentInit weights, labeled so in every
%                  output; never reported as trained-policy inference
% The checkpoint is loaded with landing2d.rl.loadCheckpoint (training
% signature and graph hash verified); nothing is trained.
if nargin < 2, options = struct(); end
registry = landing2d.config.methodRegistry();
defaults = struct('trace',true,'replay','','trainSeed',registry.trainSeeds.depth4(1), ...
    'replicate',1,'deterministic',true,'visible',true,'live',[],'speed',1,'staged',false, ...
    'outputDir','','png',true,'video',false,'mock',false);
unknown = setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption','Unknown trace option: %s',strjoin(unknown,', '));
names = fieldnames(defaults);
for i = 1:numel(names)
    if ~isfield(options,names{i}), options.(names{i}) = defaults.(names{i}); end
end
if isempty(options.live), options.live = options.visible; end
root = landing2d.orchestration.projectRoot();
if isempty(options.outputDir), options.outputDir = fullfile(root,'results','trace'); end
if ~isempty(options.replay)
    output = replay(char(options.replay),options);
    return;
end
cfg = landing2d.config.primaryConfig(root);
specs = landing2d.evaluation.factorialCases(cfg);
if nargin < 1 || isempty(caseId), caseId = 'S4'; end
caseId = upper(char(caseId));
spec = specs(strcmp({specs.id},caseId));
assert(~isempty(spec),'landing2d:ScenarioId','caseId must be S1, S2, S3 or S4.');
seeds = landing2d.evaluation.replicateSeeds(cfg,cfg.evaluation.factorial.seed,options.replicate);
seed = seeds(end);
arm = landing2d.config.applyMethod(cfg,'onto_rgat_ppo',options.trainSeed);
identity = struct('runId','','methodId','onto_rgat_ppo','trainSeed',options.trainSeed, ...
    'scenarioId',caseId,'replicate',options.replicate,'checkpointFile','', ...
    'checkpointHash','','signatureHash',signatureHash(arm), ...
    'algorithmVersion',landing2d.rl.algorithmVersion(),'graphHash','', ...
    'sourceCommit','','sourceDirty','','command','','modelStatus','');
[identity.sourceCommit,identity.sourceDirty] = sourceCommit(root);
if options.mock
    agent = landing2d.rl.agentInit(arm.rl,RandStream('threefry','Seed',arm.rl.seed),arm.graphState);
    identity.modelStatus = 'TEST ONLY: untrained agentInit weights (not a trained policy)';
    dashboardMode = 'test'; suffix = '_TESTONLY';
else
    [agent,~,file] = landing2d.rl.loadCheckpoint(arm);
    runInfo = landing2d.rl.runIdentity(agent,arm,file);
    identity.checkpointFile = file; identity.checkpointHash = runInfo.CheckpointHash;
    identity.modelStatus = 'trained checkpoint (training signature + graph hash verified)';
    dashboardMode = 'live'; suffix = '';
end
identity.graphHash = agent.encoderSpec.graph.hash;
baseName = sprintf('%s_onto_rgat_ppo_s%02d_r%02d%s',caseId,options.trainSeed,options.replicate,suffix);
identity.runId = [baseName,'_',char(datetime('now','Format','yyyyMMdd_HHmmss'))];
identity.command = sprintf('run_scenario(''%s'',struct(''trace'',true,''trainSeed'',%d,''replicate'',%d))', ...
    caseId,options.trainSeed,options.replicate);
dashboard = [];
wallStart = [];
recordOptions = struct('deterministic',options.deterministic,'scenario',spec.scenario, ...
    'sensorEvents',spec.sensorEvents,'identity',identity);
if options.live
    recordOptions.onStart = @startDashboard;
    recordOptions.onRecord = @streamRecord;
end
decisionTrace = landing2d.trace.recordEpisode(agent,arm,seed,recordOptions);
files = landing2d.trace.exportTrace(decisionTrace,options.outputDir,baseName);
if isempty(dashboard) || ~isvalid(dashboard)
    dashboard = landing2d.viz.TosmTraceDashboard(decisionTrace,struct('mode',replayMode(dashboardMode), ...
        'visible',options.visible,'speed',options.speed,'staged',options.staged));
else
    dashboard.finalize(decisionTrace);
end
files = exportViews(dashboard,decisionTrace,files,options,baseName);
cadence = landing2d.trace.cadenceSummary(decisionTrace);
fprintf(['[trace] %s, onto_rgat_ppo seed %d (%s), episode seed %d: %d decisions, %s at %.2f s\n' ...
    '        trace %s\n'],caseId,options.trainSeed,identity.modelStatus,seed, ...
    numel(decisionTrace.records),decisionTrace.terminal.reason,decisionTrace.terminal.time,files.mat);
output = struct('trace',decisionTrace,'files',files,'cadence',cadence,'dashboard',dashboard);
if ~options.visible
    delete(dashboard); output.dashboard = [];
end

    function startDashboard(skeleton)
        dashboard = landing2d.viz.TosmTraceDashboard(skeleton,struct('mode',dashboardMode, ...
            'visible',options.visible,'speed',options.speed,'staged',options.staged));
        wallStart = tic;
    end

    function streamRecord(record)
    % Pace the episode to the display clock (simulation time / speed). The
    % record is a copy; nothing here reaches the policy or the environment.
        if isempty(dashboard) || ~isvalid(dashboard), return; end
        dashboard.appendRecord(record);
        target = record.time/max(dashboard.Speed,eps);
        while isvalid(dashboard) && toc(wallStart) < target
            pause(0.02);
        end
    end
end

function output = replay(file,options)
[decisionTrace,annotations] = landing2d.trace.loadTrace(file);
dashboardMode = 'replay';
if contains(decisionTrace.identity.modelStatus,'TEST ONLY'), dashboardMode = 'test'; end
dashboard = landing2d.viz.TosmTraceDashboard(decisionTrace,struct('mode',dashboardMode, ...
    'visible',options.visible,'speed',options.speed,'staged',options.staged));
[folder,baseName] = fileparts(file);
files = struct('mat',file);
files = exportViews(dashboard,decisionTrace,files,options,[baseName,'_replay']);
if ~isempty(folder) && ~strcmp(folder,options.outputDir), files.folder = folder; end
output = struct('trace',decisionTrace,'annotations',annotations,'files',files, ...
    'dashboard',dashboard);
if ~options.visible
    delete(dashboard); output.dashboard = [];
end
end

function files = exportViews(dashboard,decisionTrace,files,options,baseName)
% PNG of a fixed, result-independent view: the first decision inside the
% injected dropout window (S2, S4) or the middle decision (S1, S3), with the
% LandingCondition evidence chain selected.
if ~options.png && ~options.video, return; end
if ~isfolder(options.outputDir), mkdir(options.outputDir); end
records = decisionTrace.records;
evaluation = [records.evaluation];
k = find([evaluation.injectedDropout],1);
if isempty(k), k = ceil(numel(records)/2); end
dashboard.seek(records(k).time);
dashboard.select("node:7");
if options.png
    files.png = fullfile(options.outputDir,[baseName,'.png']);
    dashboard.exportPng(files.png);
end
if options.video
    files.video = fullfile(options.outputDir,[baseName,'.mp4']);
    dashboard.exportVideo(files.video);
end
end

function dashboardMode = replayMode(dashboardMode)
if strcmp(dashboardMode,'live'), dashboardMode = 'replay'; end
end

function hash = signatureHash(arm)
hash = '';
try
    hash = landing2d.util.sha256(jsonencode(landing2d.rl.trainingSignature(arm)));
catch
end
end

function [commit,dirty] = sourceCommit(root)
commit = 'unknown'; dirty = 'unknown';
previous = cd(root); restore = onCleanup(@()cd(previous));
[status,out] = system('git rev-parse HEAD');
if status == 0, commit = strtrim(out); end
[status,out] = system('git status --porcelain --untracked-files=no');
if status == 0, dirty = string(~isempty(strtrim(out))); dirty = char(dirty); end
end
