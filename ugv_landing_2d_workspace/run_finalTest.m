function [comparison,cfg,fig] = run_finalTest(options)
% RUN_FINALTEST  Replay the final V2 A/B/C checkpoints in one fixed-view GUI.
% This function never trains. It loads the low-level MLP, semantic-flat
% ablation, and ontology R-GAT checkpoints produced by run_all, evaluates
% them on identical held-out seeds, and displays full trajectories, actual
% body-fixed-camera FOV, CV/CA/CV phases, R-GAT attention, and MC statistics.
%
%   run_finalTest
%   run_finalTest(struct('playbackSpeed',4,'testEpisodeCount',5))
%   run_finalTest(struct('playbackSpeed',Inf))
if nargin<1, options=struct(); end
assert(isstruct(options) && isscalar(options),'landing2d:InvalidOptions', ...
    'options must be a scalar struct.');
projectRoot=setup_project();
cfg=landing2d.config.primaryConfig(projectRoot);

defaults=struct( ...
    'baselinePolicyFile','ppo_baseline_planar_visibility_v2.mat', ...
    'semanticPolicyFile','ppo_context_flat_planar_visibility_v2.mat', ...
    'ontologyPolicyFile','ppo_context_rgat_planar_visibility_v2.mat', ...
    'playbackSpeed',1,'testEpisodeCount',5,'figureVisible',true, ...
    'outputDir',cfg.outputDir);
names=fieldnames(defaults);
for i=1:numel(names)
    if ~isfield(options,names{i}), options.(names{i})=defaults.(names{i}); end
end
unknown=setdiff(fieldnames(options),names);
assert(isempty(unknown),'landing2d:UnknownOption', ...
    'Unknown run_finalTest option: %s',strjoin(unknown,', '));
validateattributes(options.testEpisodeCount,{'numeric'},{'scalar','integer','positive'});
cfg.figureVisible=logical(options.figureVisible);
cfg.playbackSpeed=options.playbackSpeed;
cfg.outputDir=char(options.outputDir);
cfg.animate=false; cfg.makeFinalPlots=false; cfg.saveResults=false;
landing2d.config.validateConfig(cfg);

modes={'baseline','context_flat','context_rgat'};
labels={'Low-level MLP PPO','Semantic-flat MLP PPO','Ontology R-GAT PPO'};
files={options.baselinePolicyFile,options.semanticPolicyFile,options.ontologyPolicyFile};
agents=cell(1,3); checkpointInfo=cell(1,3); checkpointPath=cell(1,3);
results=cell(1,3); infos=cell(1,3); profiles=cell(1,3);
n=min(options.testEpisodeCount,numel(cfg.experiment.manifest.testSeeds));
seeds=cfg.experiment.manifest.testSeeds(1:n);
for i=1:3
    arm=landing2d.graphstate.applyStateRepresentation(cfg,modes{i});
    arm.rl.policyFile=char(files{i});
    [agents{i},checkpointInfo{i},checkpointPath{i}]=landing2d.rl.loadCheckpoint(arm);
    fprintf('%s checkpoint: %s\n',labels{i},checkpointPath{i});
    [results{i},~,infos{i}]=landing2d.rl.evaluateV2(agents{i},arm,seeds);
    profiles{i}=landing2d.rl.profileAgent(agents{i},arm,1,25);
end

meanReturn=cellfun(@(x)x.meanReturn,infos)';
successRate=cellfun(@(x)x.landingRate,infos)';
unsafeRate=cellfun(@(x)x.unsafeRate,infos)';
safeAbortRate=cellfun(@(x)x.safeAbortRate,infos)';
captureRate=cellfun(@(x)x.meanCaptureRate,infos)';
inferenceMs=cellfun(@(x)x.totalInferenceMs,profiles)';
summaryTable=table(labels',modes',meanReturn,successRate,unsafeRate, ...
    safeAbortRate,captureRate,inferenceMs,'VariableNames', ...
    {'Method','StateRepresentation','MeanReturn','SuccessRate','UnsafeRate', ...
    'SafeAbortRate','CaptureRate','InferenceMs'});
disp(summaryTable);

runs=struct('results',results,'label',labels,'info',infos, ...
    'profile',profiles,'training',checkpointInfo);
oldFigures=findall(groot,'Type','figure','Tag','landing2dFinalTest');
if ~isempty(oldFigures), delete(oldFigures); end
[fig,~,~]=landing2d.viz.replayPlanarVisibilityComparison(runs,cfg, ...
    struct('animate',true,'playbackSpeed',options.playbackSpeed));
comparison=struct('schemaVersion','planar_visibility_final_test_v2', ...
    'runs',runs,'summaryTable',summaryTable,'agents',{agents}, ...
    'checkpointInfo',{checkpointInfo},'checkpoints',{checkpointPath}, ...
    'testSeeds',seeds);
end
