function [comparison, summaryTable, cfg] = run_all(options)
% RUN_ALL  모든 비교군의 전체 시나리오와 학습을 한 번에 실행하는 통합 진입점.
%
%   1) PN guidance    비례 항법 유도 (기준)
%   2) PPO RL         PN 유도를 교사로 모방 학습 + PPO. 기준 모델(baseline)
%   3) Onto Graph RL  같은 보상/행동/환경/PPO에, 상태 표현만 온톨로지 그래프 +
%                     R-GAT + 그래프 수준 읽기로 바꾼 제안 모델
%
% 2)와 3)이 PPO에 넣는 상태가 다릅니다.
%   기준 모델 : landing2d.rl.observation의 11차원 관측 벡터
%   제안 모델 : 같은 관측 정보로 만든 온톨로지 그래프 G_t를 R-GAT으로 부호화하고
%               모든 노드를 읽어 만든 그래프 수준 표현 g_t
%
% 보상 함수와 계수, 행동 정의와 한계, 환경, 종료 조건은 두 비교군이 완전히 같고
% landing2d.graphstate.assertSameProblem이 실행 중에 이를 강제합니다.
%
% 학습 조건은 기본값에서 다릅니다. 기준 모델은 PN 유도를 교사로 모방 학습한 뒤
% PPO로 미세조정하고, 제안 모델은 교사 없이 처음부터 학습합니다
% (cfg.graphState.useScratchSettings = true). 모방 학습으로 초기화하면 정책이
% 유도 법칙의 거동을 물려받아 비가시 구간에서도 유도 법칙과 같은 움직임을 보이기
% 때문입니다. 대신 상태 표현 외의 변수가 함께 달라지므로, 달라진 항목을
% 실행 중에 목록으로 출력합니다. 상태 표현만 비교하려면 useScratchSettings를
% false로 두거나 기준 모델에도 landing2d.rl.applyScratchSettings를 적용하십시오.
%
% 옛 제안 모델(온톨로지 R-GAT으로 보상 가중치를 설계하던 경로)은 지우지 않고
% cfg.useLegacyOntologyReward = true일 때만 실행하도록 남겨 두었습니다.
% 새 제안 모델은 그 경로를 전혀 쓰지 않습니다.
%
% 모든 비교군의 제어 명령은 수평/수직 **가속도** [m/s^2]이며,
% 센서, 상태기계, 접촉 판정, 동역학은 완전히 같은 함수를 씁니다.
%
%   run_all;                                   % 필요한 학습만 수행하고 전체 비교
%   run_all(struct('rlRetrain',true));         % 정책을 다시 학습
%   run_all(struct('figureVisible',false));    % 창 없이 계산과 저장만
%   run_all(struct('showLiveDashboard',false)); % 실시간 대시보드만 끄기
%   run_all(struct('controller','pd'));        % 기준을 기존 PD로 바꿔 실행
%   run_all(struct('stateRepresentation','gat'));        % 제거 실험으로 바꿔 실행
%   run_all(struct('useLegacyOntologyReward',true));     % 옛 보상 설계 비교군 포함
%   run_all(struct('scratchBaseline',true));             % 두 비교군 모두 교사 없이 학습
%                                                        % (실험 변수 = 상태 표현 하나)
%
% 학습 결과는 results에 저장하고, 설정 지문이 같으면 다시 씁니다.
if nargin < 1
    options = struct();
end
if ~(isstruct(options) && isscalar(options))
    error('landing2d:InvalidOptions','options must be a scalar struct.');
end
projectRoot = setup_project();
cfg = landing2d.config.defaultConfig(projectRoot);
if isfield(options,'rlRetrain')
    cfg.rl.retrain = logical(options.rlRetrain);
    options = rmfield(options,'rlRetrain');
end
if isfield(options,'ontologyRedesign')
    cfg.ontology.redesign = logical(options.ontologyRedesign);
    options = rmfield(options,'ontologyRedesign');
end
% 제안 모델의 상태 표현 방식. 기본값은 제안 모델(ontology_rgat)이며
% 'node_pool' / 'gat'로 바꾸면 같은 PPO 코드로 제거 실험을 돌립니다.
stateRepresentation = 'ontology_rgat';
if isfield(options,'stateRepresentation')
    stateRepresentation = options.stateRepresentation;
    options = rmfield(options,'stateRepresentation');
end
if ~isfield(options,'animate')
    % 모든 비교군을 계산하므로 실시간 표시는 기본으로 끕니다.
    options.animate = false;
end
cfg = landing2d.config.applyOptions(cfg,options);
landing2d.config.validateConfig(cfg);
useLegacy = cfg.useLegacyOntologyReward;
nStages = 4+2*double(useLegacy);
started = tic;
dashboardOn = cfg.showLiveDashboard && cfg.figureVisible;
if dashboardOn
    landing2d.viz.liveDashboard('init',cfg);
end

%% 1) 기준 유도 법칙
stage(1,nStages,'%s 유도로 %d개 시나리오 실행', ...
    upper(cfg.controller),size(cfg.scenarioSpeeds,1));
guidanceResults = landing2d.simulation.run(cfg);
guidanceMc = [];
if dashboardOn
    guidanceMc = landing2d.simulation.evaluateMonteCarlo(cfg,guidanceLabel(cfg));
end

%% 2) 기준 모델: 관측 벡터를 그대로 받는 PPO
stage(2,nStages,'기준 모델 PPO (상태: 관측 벡터 %d차원, 보상: capture %.3f / distance %.3f)', ...
    cfg.rl.observationDim,cfg.rl.captureWeight,cfg.rl.distanceWeight);
baselineCfg = landing2d.graphstate.applyStateRepresentation(cfg,'baseline');
if cfg.scratchBaseline
    % 기준 모델도 교사 없이 학습해 실험 변수를 상태 표현 하나로 남깁니다.
    % 교사로 만든 정책과 섞이지 않도록 저장 파일 이름을 나눕니다.
    baselineCfg.rl = landing2d.rl.applyScratchSettings(baselineCfg.rl);
    baselineCfg.rl.policyFile = 'rl_policy_baseline_scratch.mat';
    fprintf('기준 모델도 교사 없이 학습합니다 (PPO %d반복).\n', ...
        baselineCfg.rl.ppoIterations);
end
baselineCfg.dashboardAgentLabel = 'PPO RL (baseline state)';
[baselineAgent,baselineTraining] = landing2d.rl.loadOrTrainAgent(baselineCfg);
baselineResults = landing2d.rl.evaluate(baselineAgent,baselineCfg);
baselineMc = [];
if dashboardOn
    baselineMc = landing2d.rl.evaluateMonteCarlo( ...
        baselineAgent,baselineCfg,baselineCfg.dashboardAgentLabel);
end

%% 3) 제안 모델: 온톨로지 그래프 상태 표현을 받는 PPO
proposedCfg = landing2d.graphstate.applyStateRepresentation(cfg,stateRepresentation);
% 보상, 행동, 환경, 종료 조건이 기준 모델과 같은지 확인합니다.
% 학습 조건이 다르면 멈추지 않고 목록으로 돌려주므로, 아래에 함께 출력합니다.
trainingDiff = landing2d.graphstate.assertSameProblem(baselineCfg,proposedCfg);
stage(3,nStages,'제안 모델 PPO (상태: %s, 보상/행동/환경/종료 조건은 기준 모델과 동일)', ...
    stateRepresentation);
reportTrainingDifferences(trainingDiff);
proposedCfg.dashboardAgentLabel = sprintf('PPO RL (%s state)',stateRepresentation);
[proposedAgent,proposedTraining] = landing2d.rl.loadOrTrainAgent(proposedCfg);
proposedResults = landing2d.rl.evaluate(proposedAgent,proposedCfg);
proposedMc = [];
if dashboardOn
    proposedMc = landing2d.rl.evaluateMonteCarlo( ...
        proposedAgent,proposedCfg,proposedCfg.dashboardAgentLabel);
end

runs = struct( ...
    'results',{guidanceResults,baselineResults,proposedResults}, ...
    'label',{guidanceLabel(cfg),'PPO RL (baseline state)', ...
        sprintf('PPO RL (%s state)',stateRepresentation)}, ...
    'note',{'',stateNote(baselineCfg),stateNote(proposedCfg)});

comparison = struct('runs',[],'baselineAgent',baselineAgent, ...
    'baselineTraining',baselineTraining,'proposedAgent',proposedAgent, ...
    'proposedTraining',proposedTraining, ...
    'stateRepresentation',stateRepresentation,'seconds',0, ...
    'monteCarlo',struct('guidance',guidanceMc,'baseline',baselineMc, ...
        'proposed',proposedMc));

%% (선택) 옛 제안 모델: 온톨로지 R-GAT이 보상 가중치를 설계하던 경로
% 새 제안 모델과 섞이지 않도록 완전히 분리해 둔 경로입니다.
if useLegacy
    stage(4,nStages,'[legacy] 온톨로지 R-GAT 보상 가중치 설계');
    [design,designInfo] = landing2d.ontology.loadOrDesignWeights(cfg);
    legacyCfg = landing2d.ontology.applyDesign(cfg,design);
    legacyCfg = landing2d.graphstate.applyStateRepresentation(legacyCfg,'baseline');
    stage(5,nStages,'[legacy] PPO (보상 가중치: capture %.3f / distance %.3f)', ...
        legacyCfg.rl.captureWeight,legacyCfg.rl.distanceWeight);
    legacyCfg.dashboardAgentLabel = 'Onto R-GAT (legacy reward)';
    [legacyAgent,legacyTraining] = landing2d.rl.loadOrTrainAgent(legacyCfg);
    legacyResults = landing2d.rl.evaluate(legacyAgent,legacyCfg);
    legacyMc = [];
    if dashboardOn
        legacyMc = landing2d.rl.evaluateMonteCarlo( ...
            legacyAgent,legacyCfg,legacyCfg.dashboardAgentLabel);
    end
    runs(end+1) = struct('results',legacyResults, ...
        'label','Onto R-GAT (legacy reward)', ...
        'note',sprintf('capture %.3f / distance %.3f', ...
            legacyCfg.rl.captureWeight,legacyCfg.rl.distanceWeight));
    comparison.design = design;
    comparison.designInfo = designInfo;
    comparison.legacyAgent = legacyAgent;
    comparison.legacyTraining = legacyTraining;
    comparison.monteCarlo.legacy = legacyMc;
    [comparison.designTable,comparison.nodeTable] = ...
        landing2d.io.saveRewardDesign(design,cfg);
    disp(comparison.designTable);
end

%% 4) 비교표와 그림
stage(nStages,nStages,'비교 요약과 그림 생성');
summaryTable = landing2d.metrics.makeComparisonSummary(runs,cfg);
disp(summaryTable);
comparison.runs = runs;
if cfg.saveResults
    landing2d.io.saveComparison(runs,summaryTable,cfg,'comparison');
end
if cfg.makeFinalPlots
    landing2d.viz.plotRunSummary(runs,cfg,'scenario_%d_comparison', ...
        'comparison_tabs','Guidance vs baseline state vs ontology graph state');
end
comparison.seconds = toc(started);
if dashboardOn
    landing2d.viz.liveDashboard('done',struct('message', ...
        sprintf('전체 실행 완료 · %.1f s',comparison.seconds)));
end
fprintf('\n전체 소요 시간: %.1f s\n',comparison.seconds);
if cfg.saveResults
    fprintf('결과 저장 폴더: %s\n',cfg.outputDir);
end
end

function stage(index,total,format,varargin)
fprintf('\n[%d/%d] %s\n%s\n',index,total,sprintf(format,varargin{:}), ...
    repmat('-',1,62));
end

function label = guidanceLabel(cfg)
if strcmpi(cfg.controller,'pn')
    label = 'PN guidance';
else
    label = 'PD control';
end
end

function reportTrainingDifferences(differences)
% 상태 표현 외에 함께 달라진 학습 조건을 결과와 같은 화면에 남깁니다.
% 결과를 해석할 때 이 목록이 보이지 않으면 교란 변수를 놓치기 쉽습니다.
if isempty(differences)
    fprintf('학습 조건: 기준 모델과 동일 (실험 변수는 상태 표현 하나)\n\n');
    return;
end
fprintf(['학습 조건도 함께 다릅니다. 아래 %d개 항목은 상태 표현과 별개의 ' ...
    '변수이므로\n결과를 해석할 때 반드시 함께 밝혀야 합니다.\n'],numel(differences));
for i = 1:numel(differences)
    fprintf('  %s\n',differences{i});
end
fprintf('  (상태 표현만 비교하려면 cfg.graphState.useScratchSettings = false)\n\n');
end

function note = stateNote(cfg)
note = sprintf('state %s | capture %.3f / distance %.3f', ...
    cfg.graphState.stateRepresentation,cfg.rl.captureWeight,cfg.rl.distanceWeight);
end
