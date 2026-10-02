function rl = defaultRlConfig()
% DEFAULTRLCONFIG  유도 법칙 교사 모방학습 + PPO 미세조정 설정.
% 보상은 두 항만 사용합니다: 패드 포착 항과 착륙 지점 접근 항.
rl.seed = 20240501;          % 난수 시드. 같은 시드는 같은 학습 결과
rl.actionInterval = 10;      % 제어 주기 = dt*actionInterval [스텝]
rl.hiddenSize = 48;          % 은닉층 폭 (2개 층)
rl.observationDim = 11;      % rl.observation이 만드는 관측 차원
rl.actionDim = 2;            % [수평 가속, 수직 가속] 이전의 무한계 명령

%% 보상 (두 항)
rl.captureMode = 'margin';   % 포착 항 형태: 'margin' 시야 여유 기반, 'binary' 가시 여부
rl.captureWeight = 0.20;     % 포착 항 가중치
% FOV 밖에서도 수평 오차를 줄이는 행동에 학습 신호가 남도록 포화 대신
% 경계값에서 -1로 부드럽게 점근하는 capture curve를 사용합니다.
rl.captureBoundaryValue = -0.5;
rl.captureOutsideScale = 1.0;
rl.distanceWeight = 0.71;    % 접근 항 가중치
% 'hybrid'에서는 거리 자체 성분이 (1-distanceRateShare) 배로 줄어듭니다. 착륙을
% 성립시킨 유효 크기 0.50을 유지하려고 0.50/(1-0.30) = 0.71로 보정했습니다.
% 이 보정이 없으면 포착 항 대비 거리 항이 30%% 약해져 최적해가 제자리 선회로 바뀝니다.
% 접근 항 형태
%   'hybrid'    : 변화율과 거리 자체를 섞음 (기본).
%                 거리 자체 항이 "어디에 있어야 하는가"(목표)를 정의하고,
%                 변화율 항이 "지금 가까워지는가"(순간 방향)에 부호를 줍니다.
%                 변화율만 쓰면 어느 고도에 있든 가치가 같아져(망원경 합)
%                 고도를 포착 항이 혼자 결정하고, 정책이 높은 곳에 머뭅니다.
%   'rate'      : 변화율만. 가까워지면 +, 멀어지면 -.
%   'proximity' : 거리 자체만. 가까우면 +, 멀면 -.
rl.distanceMode = 'hybrid';
rl.distanceRateShare = 0.30; % 'hybrid'에서 변화율 성분의 비중
rl.distanceRateScale = 1.5;  % 변화율 정규화 기준 속도 [m/s]
rl.distanceScale = 6.0;      % 거리 자체 성분의 부호가 바뀌는 상대거리 [m]
rl.distanceExponent = 0.5;   % 'proximity'의 거리 지수

%% 모방 학습 (교사 = 기준 유도 법칙)
rl.useBehaviorClone = true;  % false면 교사 없이 무작위 초기 정책에서 PPO만 수행
rl.bcEpisodes = 30;          % 교사 시연 에피소드 수
rl.bcEpochs = 300;           % 지도학습 반복 수
rl.bcBatch = 256;
rl.bcLearnRate = 3e-3;
rl.teacherHeightRange = [0.5,2.6];   % 교사 시연 초기 고도 배율 (상승 한계 부근까지)
rl.teacherNoise = 0.15;      % 교사 시연 실행 잡음 비율. 라벨은 잡음 없는 PD 명령

%% PPO
rl.ppoIterations = 60;
rl.episodesPerIteration = 6;
rl.ppoEpochs = 8;
rl.miniBatch = 256;
rl.clipRatio = 0.2;
rl.gamma = 0.995;
% 0.999(지평선 1000 스텝, 에피소드 전체)로 늘려봤지만 포착 우세 배분은 여전히
% 착륙하지 못했고, 착륙하던 배분 0.220은 착륙이 24.3/30.5/36.7 s로 늦어지고
% 포착률이 0.846에서 0.691로 떨어졌습니다. 그래서 되돌립니다.
% 선회에 갇히는 원인은 감가 지평선이 아니라 하강 도중 포착 벌점이 쌓이는
% 골짜기 자체입니다(배분 0.30 이상에서 2500회를 돌려도 착륙이 나오지 않음).
rl.lambda = 0.95;
rl.policyLearnRate = 2e-4;
rl.valueLearnRate = 1e-3;
rl.entropyWeight = 0.002;
rl.initialLogStd = -1.6;     % 탐색 잡음 log 표준편차 (제한 이전 명령 기준)
rl.maxGradNorm = 1.0;
rl.valueWarmup = 2;          % 처음 몇 번은 가치망만 학습해 정책 붕괴를 줄임
rl.evaluateEvery = 3;        % 몇 번마다 결정론적 성능을 확인해 최고 정책 보관
% 조기 종료: 평가 점수가 이만큼 연속으로 나아지지 않으면 학습을 멈춥니다.
% 0이면 끕니다. ppoTrain은 이미 최고 점수의 정책을 따로 보관하므로, 멈추는 시점이
% 최고점 이후라면 결과가 달라지지 않고 시간만 줄어듭니다.
% 기본값을 0으로 두어, 이 항목이 생기기 전에 저장한 정책 파일을 그대로 씁니다
% (landing2d.rl.trainingSignature가 0일 때 지문에서 제외합니다).
rl.earlyStopPatience = 0;

%% 초기 조건 무작위화 (평가에는 사용하지 않음)
rl.initialHeightRange = [0.7,1.3];   % initialHeight 배율
rl.initialOffsetRange = [-2.0,2.0];  % 초기 수평 오차 [m]
rl.initialSpeedRange = [-1.0,1.0];   % 초기 수평 속도 오차 [m/s]
rl.initialOffsetFraction = 0;        % >0이면 시야 반폭 대비 비율로 초기 오차를 뽑음
rl.parallelEpisodes = true;          % 반복당 에피소드 수집을 parfor로 분산
rl.parallelWorkers = 0;              % 0이면 min(물리 코어, 에피소드 수)
% 학습 시간의 85%%가 에피소드 롤아웃입니다(반복당 0.378 s 중 0.445 s). 롤아웃은
% 에피소드끼리 독립이라 그대로 나눌 수 있습니다. 난수 흐름을 에피소드별로 미리
% 뽑으므로 직렬 실행과 결과가 같습니다.
rl.curriculumFraction = 0;           % 출발 고도를 넓히는 데 쓰는 학습 비율 (0이면 끔)
% 0.40으로 측정했더니 오히려 나빠졌습니다(배분 0.220 착륙률 100%% -> 0%%).
% initialHeightRange가 매 반복에서 0.7~1.3배를 섞어 뽑기 때문에 그 자체가
% 제한된 커리큘럼 역할을 합니다. scratch 설정도 첫 급가속(t=3 s)을 경험하도록
% 0.8배 이상에서 시작합니다. 기능은 남기되 기본값은 끕니다.
rl.curriculumStartHeight = 0.25;     % 학습 시작 시점의 출발 고도 배율 상한
% V2 순수-RL 전용: 초기에는 시야 복구를 더 오래 탐색하게 하고 공칭 3초
% prolonged-loss 한계로 점진적으로 복귀합니다. 0이면 항상 공칭 안전 한계입니다.
rl.abortCurriculumFraction = 0;
rl.abortCurriculumStart = 3.0;
rl.motionCurriculumFraction = 0;
rl.motionCurriculumStartScale = 1.0;
rl.curriculumMode = 'iteration';
rl.curriculumLandingThreshold = 0.05;
rl.curriculumStep = 0.10;
rl.curriculumRequiredWindows = 3;
rl.curriculumFloorStartFraction = 0.15;
rl.curriculumFullDifficultyFraction = 0.65;
rl.checkpointMinCurriculum = 1.0;
rl.curriculumEasyReplayFraction = 0.15;
rl.curriculumBridgeReplayFraction = 0.15;
rl.touchdownSpeedCurriculumScale = 1.0;
rl.unsafePenaltyCurriculumStart = -40;

%% 교사 없이 처음부터 학습할 때의 설정 (landing2d.rl.applyScratchSettings)
% 좋은 초기 정책이 없으므로 탐색을 키우고 학습량을 늘려야 합니다.
% 온톨로지 비교군이 이 설정을 사용합니다.
rl.scratch = struct( ...
    'useBehaviorClone',false, ...
    'initialLogStd',-1.1, ...    % safe-contact discovery noise
    'policyLearnRate',5e-4, ...  % 지킬 사전 정책이 없으므로 크게
    'entropyWeight',0.0025, ...
    'ppoIterations',2500, ...   % 교사 없이 착륙을 찾는 데 필요한 예산 상한
    'evaluateEvery',25, ...
    'earlyStopPatience',0, ...   % 조기 종료 끔. 아래 근거 참고
    'initialHeightRange',[0.80,1.30], ...  % t=3 s 급가속 사건 전에 착륙하지 않도록 함
    'initialOffsetFraction',0.5);          % 어떤 고도에서 출발해도 패드가 보이게
% PolicyNode/ValueNode와 terminal-outcome-v1을 함께 적용한 장기 학습 곡선은 아직
% 새로 산출해야 합니다. 과거 mean/max 정책의 정체 구간을 현재 구조의 근거로
% 재사용하지 않으며, 성급한 중단으로 새 결과를 왜곡하지 않도록 기본값은 0(끔)입니다.

%% 저장
rl.policyFile = 'rl_policy.mat';     % outputDir 기준 학습 결과 파일
rl.retrain = false;                  % true면 저장된 정책이 있어도 다시 학습
rl.verbose = true;
end
