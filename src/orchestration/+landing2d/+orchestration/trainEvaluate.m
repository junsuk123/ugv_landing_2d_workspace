function [comparison,summaryTable,cfg] = trainEvaluate(options)
% TRAINEVALUATE  Train/load, validate, test, and summarize the three policies.
% Default is the full A/B/C PPO experiment. Use executionMode='smoke' for a
% bounded one-iteration integration check that is not a performance claim.
if nargin < 1, options=struct(); end
projectRoot=landing2d.orchestration.projectRoot();
cfg=landing2d.config.primaryConfig(projectRoot);
executionMode='full';
requestedModes={};
if isfield(options,'executionMode')
    executionMode=char(options.executionMode); options=rmfield(options,'executionMode');
end
if isfield(options,'modes')
    requestedModes=cellstr(options.modes); options=rmfield(options,'modes');
end
if isfield(options,'rlRetrain')
    cfg.rl.retrain=logical(options.rlRetrain); options=rmfield(options,'rlRetrain');
end
if isfield(options,'ppoIterations')
    cfg.rl.ppoIterations=options.ppoIterations; options=rmfield(options,'ppoIterations');
end
if isfield(options,'rlSeed')
    validateattributes(options.rlSeed,{'numeric'},{'scalar','integer','nonnegative'});
    cfg.rl.seed=double(options.rlSeed); options=rmfield(options,'rlSeed');
end
% 학습 실행 방식. 'simulink'는 같은 환경 계약을 Simulink 블록으로 돌리고
% RL Agent 블록 + rlPPOAgent로 학습하며, 체크포인트는 results/simulink에 둡니다.
trainingBackend='matlab';
if isfield(options,'trainingBackend')
    trainingBackend=char(options.trainingBackend);
    options=rmfield(options,'trainingBackend');
end
assert(ismember(trainingBackend,{'matlab','simulink'}), ...
    'landing2d:TrainingBackend','trainingBackend must be matlab or simulink.');
if isfield(options,'simulink')
    cfg.simulink=options.simulink; options=rmfield(options,'simulink');
end
cfg=landing2d.config.applyOptions(cfg,options);
% spatialDimension=3: 측방 y축·roll 추가, 체크포인트는 <outputDir>/spatial3d.
cfg=landing2d.config.applySpatialDimension(cfg);
assert(cfg.spatialDimension==2 || strcmp(trainingBackend,'matlab'), ...
    'landing2d:SpatialBackend', ...
    'spatialDimension=3 supports trainingBackend=''matlab'' only.');
trainer=@landing2d.rl.ppoTrain;
if strcmp(trainingBackend,'simulink')
    trainer=@landing2d.rlsim.ppoTrain;
    cfg.outputDir=fullfile(cfg.outputDir,'simulink');
end
if ~cfg.figureVisible, cfg.animate=false; end
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
        cfg.experiment.testEpisodeCount=1;
        cfg.graphState.pretrain.episodes=1;
        cfg.graphState.pretrain.maxDecisions=5;
        cfg.graphState.pretrain.epochs=1;
        cfg.graphState.pretrain.batchSize=16;
        cfg.makeFinalPlots=false;
        fprintf(['planar_visibility_v2 (%dD) bounded smoke: each method gets 1 PPO ' ...
            'iteration each. This is not convergence/performance validation.\n'], ...
            cfg.spatialDimension);
    case 'full'
        % Checkpoint selection sees validation only. The held-out test split
        % is evaluated once after training and never influences selection.
        cfg.experiment.validationEpisodeCount=100;
        cfg.experiment.testEpisodeCount=100;
        warning('landing2d:LongTraining', ...
            'Explicit full mode can take a long time and writes checkpoints.');
    otherwise
        error('landing2d:ExecutionMode','Use executionMode smoke or full.');
end
landing2d.config.validateConfig(cfg);
dashboardOn=cfg.showLiveDashboard && cfg.figureVisible;
if dashboardOn, landing2d.viz.liveDashboard('init',cfg); end
modes={'baseline','context_flat','context_rgat'};
if ~isempty(requestedModes), modes=requestedModes; end
validModes={'baseline','context_flat','context_node_pool','context_gat','context_rgat'};
assert(all(ismember(modes,validModes)),'landing2d:AblationMode', ...
    'Unsupported V2 comparison mode requested.');
labels=cellfun(@labelForMode,modes,'UniformOutput',false);
nMethods=numel(modes);
agents=cell(1,nMethods); histories=cell(1,nMethods);
results=cell(1,nMethods); infos=cell(1,nMethods);
testResults=cell(1,nMethods); testInfos=cell(1,nMethods);
profiles=cell(1,nMethods); fingerprints=cell(1,nMethods);
for i=1:nMethods
    arm=landing2d.graphstate.applyStateRepresentation(cfg,modes{i});
    arm.graphState.stateRepresentation=modes{i};
    arm.rl.policyFile=sprintf('ppo_%s_planar_visibility_v2.mat',modes{i});
    arm.dashboardAgentLabel=labels{i};
    fingerprints{i}=landing2d.environment.taskFingerprint(arm);
    fprintf('[%d/%d] %s (%s)\n',i,nMethods,labels{i},modes{i});
    if strcmp(executionMode,'full')
        [agents{i},histories{i}]=landing2d.rl.loadOrTrainAgent(arm,trainer);
    else
        [agents{i},trainInfo]=landing2d.rl.trainAgent(arm,trainer);
        histories{i}=trainInfo;
        histories{i}.smokeOnly=true;
    end
    [results{i},~,infos{i}]=landing2d.rl.evaluateV2(agents{i},arm,[]);
    testCount=min(arm.experiment.testEpisodeCount, ...
        numel(arm.experiment.manifest.testSeeds));
    testSeeds=arm.experiment.manifest.testSeeds(1:testCount);
    [testResults{i},~,testInfos{i}]=landing2d.rl.evaluateV2( ...
        agents{i},arm,testSeeds);
    profiles{i}=landing2d.rl.profileAgent(agents{i},arm,1,25);
    if dashboardOn
        landing2d.viz.liveDashboard('v2evaluation',struct( ...
            'label',labels{i},'results',results{i},'info',infos{i}));
    end
end

assert(all(strcmp(fingerprints,fingerprints{1})), ...
    'landing2d:TaskFingerprint','A/B/C do not share the same task contract.');
reportInfo=testInfos;
meanReturn=cellfun(@(x)x.meanReturn,reportInfo)';
successRate=cellfun(@(x)x.landingRate,reportInfo)';
unsafeRate=cellfun(@(x)x.unsafeRate,reportInfo)';
safeAbortRate=cellfun(@(x)x.safeAbortRate,reportInfo)';
timeoutRate=cellfun(@(x)x.timeoutRate,reportInfo)';
parameterCount=cellfun(@(x)x.parameterCount,profiles)';
inferenceMs=cellfun(@(x)x.policyInferenceMs,profiles)';
summaryTable=table(labels',modes',meanReturn,successRate,unsafeRate,safeAbortRate, ...
    timeoutRate,parameterCount,inferenceMs, ...
    'VariableNames',{'Method','StateRepresentation','MeanReturn', ...
    'SuccessRate','UnsafeRate','SafeAbortRate','TimeoutRate', ...
    'ParameterCount','InferenceMs'});
disp(summaryTable);
comparison=struct('schemaVersion','planar_visibility_comparison_v2', ...
    'executionMode',executionMode,'trainingBackend',trainingBackend, ...
    'agents',{agents},'training',{histories}, ...
    'results',{results},'info',{infos},'validationResults',{results}, ...
    'validationInfo',{infos},'testResults',{testResults}, ...
    'testInfo',{testInfos},'selectionSplit','validation', ...
    'reportedSplit','test','profiles',{profiles}, ...
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

if cfg.makeFinalPlots
    % Report the held-out test split, matching summaryTable. Validation
    % results stay in comparison for checkpoint-selection auditing.
    vizRuns=struct('results',testResults,'label',labels,'info',testInfos, ...
        'profile',profiles,'training',histories);
    replayOptions=struct('animate',false,'playbackSpeed',Inf);
    [fig,tabs,layouts]=landing2d.viz.replayPlanarVisibilityComparison( ...
        vizRuns,cfg,replayOptions);
    if cfg.saveResults
        names={'planar_visibility_monte_carlo'};
        if numel(tabs)>1, names{end+1}='spatial_trajectories_3d'; end
        landing2d.io.saveTabbedFigure(fig,tabs,layouts,cfg,names, ...
            'planar_visibility_comparison');
    end
end
if dashboardOn
    landing2d.viz.liveDashboard('done',struct('message', ...
        sprintf('planar_visibility_v2 %s complete',executionMode)));
end
end

function label=labelForMode(mode)
switch mode
    case 'baseline', label='Low-level PPO';
    case 'context_flat', label='Semantic-flat PPO';
    case 'context_node_pool', label='Ontology node-pool PPO';
    case 'context_gat', label='Single-relation GAT PPO';
    case 'context_rgat', label='Ontology R-GAT PPO';
    otherwise, label=mode;
end
end
