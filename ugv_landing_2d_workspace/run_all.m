function [comparison, summaryTable, cfg] = run_all(options)
% RUN_ALL  모든 비교군의 전체 시나리오와 학습을 한 번에 실행하는 통합 진입점.
%
%   1) PN guidance    비례 항법 유도 (기준)
%   2) PPO RL         PN 유도를 교사로 모방 학습 + PPO. 기준 모델(baseline)
%   3) Onto Graph RL  같은 보상/행동/환경/PPO에, 상태 표현만 온톨로지 그래프 +
%                     R-GAT + 그래프 수준 읽기로 바꾼 제안 모델
%
% 2)와 3)의 유일한 차이는 PPO가 받는 상태 표현입니다.
%   기준 모델 : landing2d.rl.observation의 11차원 관측 벡터
%   제안 모델 : 같은 관측 정보로 만든 온톨로지 그래프 G_t를 R-GAT으로 부호화하고
%               모든 노드를 읽어 만든 그래프 수준 표현 g_t
% 보상 함수와 계수, 행동 정의와 한계, 환경, 종료 조건, PPO 알고리즘과
% 하이퍼파라미터, 학습 반복 수, 시드는 두 비교군이 완전히 같습니다.
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
%   run_all(struct('controller','pd'));        % 기준을 기존 PD로 바꿔 실행
%   run_all(struct('stateRepresentation','gat'));        % 제거 실험으로 바꿔 실행
%   run_all(struct('useLegacyOntologyReward',true));     % 옛 보상 설계 비교군 포함
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

%% 1) 기준 유도 법칙
stage(1,nStages,'%s 유도로 %d개 시나리오 실행', ...
    upper(cfg.controller),size(cfg.scenarioSpeeds,1));
guidanceResults = landing2d.simulation.run(cfg);

%% 2) 기준 모델: 관측 벡터를 그대로 받는 PPO
stage(2,nStages,'기준 모델 PPO (상태: 관측 벡터 %d차원, 보상: capture %.3f / distance %.3f)', ...
    cfg.rl.observationDim,cfg.rl.captureWeight,cfg.rl.distanceWeight);
baselineCfg = landing2d.graphstate.applyStateRepresentation(cfg,'baseline');
[baselineAgent,baselineTraining] = landing2d.rl.loadOrTrainAgent(baselineCfg);
baselineResults = landing2d.rl.evaluate(baselineAgent,baselineCfg);

%% 3) 제안 모델: 온톨로지 그래프 상태 표현을 받는 PPO
proposedCfg = landing2d.graphstate.applyStateRepresentation(cfg,stateRepresentation);
% 보상과 행동이 기준 모델과 같은지 여기서 한 번 확인하고 넘어갑니다.
landing2d.graphstate.assertSameProblem(baselineCfg,proposedCfg);
stage(3,nStages,['제안 모델 PPO (상태: %s, 보상/행동/PPO 설정은 기준 모델과 동일)'], ...
    stateRepresentation);
[proposedAgent,proposedTraining] = landing2d.rl.loadOrTrainAgent(proposedCfg);
proposedResults = landing2d.rl.evaluate(proposedAgent,proposedCfg);

runs = struct( ...
    'results',{guidanceResults,baselineResults,proposedResults}, ...
    'label',{guidanceLabel(cfg),'PPO RL (baseline state)', ...
        sprintf('PPO RL (%s state)',stateRepresentation)}, ...
    'note',{'',stateNote(baselineCfg),stateNote(proposedCfg)});

comparison = struct('runs',[],'baselineAgent',baselineAgent, ...
    'baselineTraining',baselineTraining,'proposedAgent',proposedAgent, ...
    'proposedTraining',proposedTraining, ...
    'stateRepresentation',stateRepresentation,'seconds',0);

%% (선택) 옛 제안 모델: 온톨로지 R-GAT이 보상 가중치를 설계하던 경로
% 새 제안 모델과 섞이지 않도록 완전히 분리해 둔 경로입니다.
if useLegacy
    stage(4,nStages,'[legacy] 온톨로지 R-GAT 보상 가중치 설계');
    [design,designInfo] = landing2d.ontology.loadOrDesignWeights(cfg);
    legacyCfg = landing2d.ontology.applyDesign(cfg,design);
    legacyCfg = landing2d.graphstate.applyStateRepresentation(legacyCfg,'baseline');
    stage(5,nStages,'[legacy] PPO (보상 가중치: capture %.3f / distance %.3f)', ...
        legacyCfg.rl.captureWeight,legacyCfg.rl.distanceWeight);
    [legacyAgent,legacyTraining] = landing2d.rl.loadOrTrainAgent(legacyCfg);
    legacyResults = landing2d.rl.evaluate(legacyAgent,legacyCfg);
    runs(end+1) = struct('results',legacyResults, ...
        'label','Onto R-GAT (legacy reward)', ...
        'note',sprintf('capture %.3f / distance %.3f', ...
            legacyCfg.rl.captureWeight,legacyCfg.rl.distanceWeight));
    comparison.design = design;
    comparison.designInfo = designInfo;
    comparison.legacyAgent = legacyAgent;
    comparison.legacyTraining = legacyTraining;
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

function note = stateNote(cfg)
note = sprintf('state %s | capture %.3f / distance %.3f', ...
    cfg.graphState.stateRepresentation,cfg.rl.captureWeight,cfg.rl.distanceWeight);
end
