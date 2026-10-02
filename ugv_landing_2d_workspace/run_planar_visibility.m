function [comparison,summaryTable,cfg] = run_planar_visibility(options)
% RUN_PLANAR_VISIBILITY  Primary A/B/C experiment using the common V2 API.
% Default is a bounded integration smoke run, not a performance claim.
if nargin < 1, options=struct(); end
projectRoot=setup_project();
cfg=landing2d.config.primaryConfig(projectRoot);
executionMode='smoke';
if isfield(options,'executionMode')
    executionMode=char(options.executionMode); options=rmfield(options,'executionMode');
end
if isfield(options,'rlRetrain')
    cfg.rl.retrain=logical(options.rlRetrain); options=rmfield(options,'rlRetrain');
end
if isfield(options,'ppoIterations')
    cfg.rl.ppoIterations=options.ppoIterations; options=rmfield(options,'ppoIterations');
end
cfg=landing2d.config.applyOptions(cfg,options);
switch executionMode
    case 'smoke'
        cfg.rl.ppoIterations=min(cfg.rl.ppoIterations,1);
        cfg.rl.episodesPerIteration=1;
        cfg.rl.ppoEpochs=1;
        cfg.rl.miniBatch=64;
        cfg.rl.evaluateEvery=1;
        cfg.rl.valueWarmup=0;
        cfg.rl.parallelEpisodes=false;
        cfg.rl.verbose=false;
        cfg.experiment.validationEpisodeCount=1;
        cfg.makeFinalPlots=false;
        fprintf(['planar_visibility_v2 bounded smoke: 3 methods, 1 PPO ' ...
            'iteration each. This is not convergence/performance validation.\n']);
    case 'full'
        cfg.experiment.validationEpisodeCount=5;
        warning('landing2d:LongTraining', ...
            'Explicit full mode can take a long time and writes checkpoints.');
    otherwise
        error('landing2d:ExecutionMode','Use executionMode smoke or full.');
end
landing2d.config.validateConfig(cfg);
dashboardOn=cfg.showLiveDashboard && cfg.figureVisible;
if dashboardOn, landing2d.viz.liveDashboard('init',cfg); end
modes={'baseline','context_flat','context_rgat'};
labels={'Low-level MLP PPO','Semantic-flat MLP PPO','Ontology R-GAT PPO'};
agents=cell(1,3); histories=cell(1,3); results=cell(1,3); infos=cell(1,3);
profiles=cell(1,3);
fingerprints=cell(1,3);
for i=1:3
    arm=landing2d.graphstate.applyStateRepresentation(cfg,modes{i});
    arm.graphState.stateRepresentation=modes{i};
    arm.rl.policyFile=sprintf('ppo_%s_planar_visibility_v2.mat',modes{i});
    fingerprints{i}=landing2d.environment.taskFingerprint(arm);
    fprintf('[%d/3] %s (%s)\n',i,labels{i},modes{i});
    if strcmp(executionMode,'full')
        [agents{i},histories{i}]=landing2d.rl.loadOrTrainAgent(arm);
    else
        rs=RandStream('threefry','Seed',arm.rl.seed);
        agents{i}=landing2d.rl.agentInit(arm.rl,rs,arm.graphState);
        [agents{i},history]=landing2d.rl.ppoTrain(agents{i},arm,rs);
        histories{i}=struct('history',history,'smokeOnly',true);
    end
    [results{i},~,infos{i}]=landing2d.rl.evaluateV2(agents{i},arm,[]);
    profiles{i}=landing2d.rl.profileAgent(agents{i},arm,1,25);
end
assert(all(strcmp(fingerprints,fingerprints{1})), ...
    'landing2d:TaskFingerprint','A/B/C do not share the same task contract.');
meanReturn=cellfun(@(x)x.meanReturn,infos)';
successRate=cellfun(@(x)x.landingRate,infos)';
unsafeRate=cellfun(@(x)x.unsafeRate,infos)';
safeAbortRate=cellfun(@(x)x.safeAbortRate,infos)';
parameterCount=cellfun(@(x)x.parameterCount,profiles)';
inferenceMs=cellfun(@(x)x.totalInferenceMs,profiles)';
summaryTable=table(labels',modes',meanReturn,successRate,unsafeRate,safeAbortRate, ...
    parameterCount,inferenceMs, ...
    'VariableNames',{'Method','StateRepresentation','MeanReturn', ...
    'SuccessRate','UnsafeRate','SafeAbortRate','ParameterCount','InferenceMs'});
disp(summaryTable);
comparison=struct('schemaVersion','planar_visibility_comparison_v2', ...
    'executionMode',executionMode,'agents',{agents},'training',{histories}, ...
    'results',{results},'info',{infos},'profiles',{profiles}, ...
    'taskFingerprint',fingerprints{1});
comparison.rewardAudit=landing2d.rl.rewardAudit(cfg);
if cfg.saveResults
    if ~exist(cfg.outputDir,'dir'), mkdir(cfg.outputDir); end
    writetable(summaryTable,fullfile(cfg.outputDir, ...
        sprintf('planar_visibility_%s_summary.csv',executionMode)));
    writetable(comparison.rewardAudit,fullfile(cfg.outputDir,'reward_audit_v2.csv'));
    save(fullfile(cfg.outputDir,sprintf('planar_visibility_%s.mat',executionMode)), ...
        'comparison','summaryTable','cfg');
end
if dashboardOn
    landing2d.viz.liveDashboard('done',struct('message', ...
        sprintf('planar_visibility_v2 %s complete',executionMode)));
end
end
