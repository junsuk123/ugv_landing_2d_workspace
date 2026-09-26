function cfg = defaultConfig(projectRoot)
% DEFAULTCONFIG  수정 가능한 설정을 모은 단일 파일.
% 기존 단일 파일 버전의 제어 이득/동역학/시나리오 기본값을 유지합니다.
if nargin < 1
    projectRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end

cfg.dt = 0.01;                    % 수치 적분 간격 [s]
cfg.tEnd = 70;                    % 전체 모사 시간 [s]
cfg.segmentTimes = [3, 15];       % 2구간 / 3구간 시작 시각 [s]
% 첫 전환은 최소 착륙 시간(약 5초)보다 앞에 둡니다. 그래야 어떤 제어기도
% 교란 이전에 착륙해 시야 이탈 구간을 건너뛸 수 없습니다.
cfg.scenarioSpeeds = [1.0, 4.0, 1.5; ...
                      1.5, 5.5, 2.0; ...
                      2.0, 7.0, 2.5]; % 각 행: [1구간, 2구간, 3구간] [m/s]
cfg.ugvAccelMax = 4.0;            % 구간 전환 시 UGV 가/감속 한계 [m/s^2]
cfg.padHeight = 0.6;              % 지면 기준 UGV 위 패드 높이 [m]
cfg.padHalfLength = 0.5;          % 진행 방향 패드 반길이 [m]
cfg.initialHeight = 6.0;          % 초기 패드 상대 고도 [m]
cfg.maxHeight = 18.0;             % 상승 탐색의 목표 상한 고도 [m]
% 운용 고도 상한. 동역학에서 강제하는 물리 제약입니다.
% 이것이 없으면 학습 정책이 고도를 올려 시야를 공짜로 확보하는 해를 찾습니다.
% 유도 법칙은 maxHeight에서 상승을 멈추므로 이 값에 닿지 않습니다.
cfg.ceilingHeight = 25.0;         % 드론이 올라갈 수 있는 최대 패드 상대 고도 [m]
cfg.cameraFovDeg = 50;            % 카메라 전체 시야각 [deg]

cfg.controller = 'pn';            % 'pn' 비례 항법 유도(기본), 'pd' 기존 PD 회귀 경로

%% 비례 항법 유도 (출력은 가속도 명령)
cfg.pnGain = 3.0;                 % 비례 항법 이득 N
cfg.pnApproachSpeed = 0.7;        % 최대 접근 속도 [m/s]
cfg.pnApproachGain = 0.60;        % 접근 속도 기준 = min(pnApproachSpeed, gain*거리) [1/s]
cfg.pnClosingGain = 1.2;          % 접근 속도 오차 -> 시선 방향 가속도 [1/s]
cfg.pnSpeedMatchGain = 2.0;       % 재포착 구간 수평 속도 정합 이득 [1/s]
cfg.pnRecoveryGain = 0.7;         % 재포착 구간 시선 정렬 이득 [1/s]
cfg.pnVerticalGain = 2.0;         % 상승 속도 추종 이득 [1/s]
cfg.pnHeightGain = 1.0;           % 상승 한계 부근 감속 이득 [1/s]
cfg.pnMinClosing = 0.3;           % 직교 성분에 쓰는 상대 속도 하한 [m/s]
cfg.pnMinRange = 0.05;            % 시선각 계산의 거리 하한 [m]

%% 기존 PD 제어 (controller='pd'일 때만 사용)
cfg.kpX = 1.4;                    % 수평 위치 P 이득 [s^-2]
cfg.kdX = 2.0;                    % 수평 속도 D 이득 [s^-1]
cfg.kpZ = 3.0;                    % 고도 위치 P 이득 [s^-2]
cfg.kdZ = 3.0;                    % 고도 속도 D 이득 [s^-1]
cfg.axMax = 1.2;                  % 드론 수평 가속도 한계 [m/s^2]
cfg.azMax = 2.0;                  % 드론 수직 가속도 한계 [m/s^2]
cfg.vxMax = 10.0;                 % 드론 수평 속도 한계 [m/s]
cfg.vzMax = 1.5;                  % 드론 수직 속도 한계 [m/s]
cfg.climbSpeed = 1.2;             % 재포착 상승 기준 속도 [m/s]
cfg.descentSpeed = 0.4;           % 착륙 하강 기준 최대 속도 [m/s]
cfg.nearPadDescentGain = 0.6;      % 패드 근처 하강 감속: min(vDesc, gain*h)
cfg.alignPositionTol = 0.30;      % 하강을 허용하는 수평 오차 [m]
cfg.alignSpeedTol = 0.35;         % 하강을 허용하는 상대 수평 속도 [m/s]
cfg.reacquireInnerRatio = 0.75;   % FOV 중앙 75% 이내에서 재포착 확인
cfg.reacquireHoldTime = 0.25;     % 재포착 확인을 위한 연속 관측 시간 [s]
cfg.touchdownHeight = 0.04;       % 패드 면과의 수치 접촉 허용 높이 [m]
cfg.touchdownSpeedX = 0.35;       % 착륙 시 허용 상대 수평 속도 [m/s]
cfg.touchdownSpeedZ = 0.30;       % 착륙 시 허용 수직 속도 [m/s]

cfg.animate = true;              % 실시간 2차원 애니메이션 표시
cfg.makeFinalPlots = true;       % 종료 후 최종 그래프 생성의 전체 스위치
cfg.playbackSpeed = 1;            % 1: 실제 시간, 4: 4배속, Inf: 대기 없이
cfg.animationHz = 20;             % 애니메이션 갱신 주파수 [Hz]
cfg.saveResults = true;           % MAT / CSV / 최종 PNG 저장
cfg.outputDir = fullfile(projectRoot, 'results');


%% 최종 시각화: 세 시나리오에서 같은 구간 색상 사용
cfg.makeDetailPlots = false;      % true: 위치/속도 4패널 등 상세 그림 추가 생성
cfg.makeTrajectoryPlots = true;   % 상세 그림에서 x-z 궤적 그래프 추가 여부
cfg.trajectoryFlightOnly = true;  % 착륙/실패 시점까지의 비행 궤적 표시
cfg.segmentColors = [0.27,0.56,0.88; ... % S1: 파랑
                     0.96,0.61,0.22; ... % S2: 주황
                     0.32,0.72,0.54];    % S3: 초록
cfg.segmentAlpha = 0.16;           % patch FaceAlpha: 0=완전 투명, 1=불투명
cfg.showSegmentLabels = true;      % 배경 상단에 S1/S2/S3 + 목표 속도 표시
cfg.showEventLines = true;         % 시야 이탈, 재포착, 착륙 사건 표시
cfg.figureVisible = true;          % false: 창은 숨기되 저장은 수행 가능
cfg.figureResolution = 200;        % PNG 해상도 [dpi]
cfg.saveFig = true;                % 편집 가능한 MATLAB FIG도 함께 저장

%% 통합 실시간 대시보드 (run_all)
% PPO 학습 곡선, 현재 온톨로지 그래프 노드 값, 평가 중 에이전트 궤적을
% 한 창에서 갱신합니다. 수치 계산과 저장되는 정책에는 영향을 주지 않습니다.
cfg.showLiveDashboard = true;
cfg.evaluationMonteCarloRuns = 20;          % 최종 평가의 무작위 초기조건 반복 수
cfg.evaluationMonteCarloSeed = 20240924;    % 모든 비교군이 공유하는 평가 표본 시드
cfg.evaluationHeightRange = [0.8,1.2];      % 초기 고도 배율 범위
cfg.evaluationOffsetRange = [-1.0,1.0];     % 초기 수평 오차 범위 [m]
cfg.evaluationSpeedRange = [-0.5,0.5];      % 초기 상대 수평 속도 범위 [m/s]

%% 온톨로지 탭 (읽기 전용 시각화)
% 결과 요약 창의 탭 그룹에 '온톨로지' 탭 하나를 덧붙입니다.
% 저장이 끝난 뒤에 붙으므로 시나리오별 PNG와 FIG 내용은 달라지지 않습니다.
cfg.showOntologyTab = true;
% 탭이 처음 열 때 읽는 표시 대상.
%   'ontology'        landing2d.ontology.nodeSchema('core')   온톨로지 의미 그래프
%   'ontology_design' landing2d.ontology.nodeSchema('design') 보상 가중치 설계용 확장
%   'graphstate'      landing2d.graphstate.schemaFor(...)     강화학습 입력 그래프
% 탭 안의 표시 대상 선택창에서 언제든 바꿀 수 있습니다.
cfg.ontologyViewSource = 'ontology';

%% 비교군 1: 유도 법칙 교사 모방 학습 + PPO 강화학습 (run_all에서 사용)
cfg.rl = landing2d.rl.defaultRlConfig();

%% 비교군 2: 온톨로지 기반 R-GAT 보상 가중치 설계 (run_all에서 사용)
cfg.ontology = landing2d.ontology.defaultOntologyConfig();

%% 비교군 3: 온톨로지 그래프 상태 표현 (제안 모델, run_all에서 사용)
% 기본값은 'baseline'이므로 이 항목을 건드리지 않는 기존 실행은 그대로입니다.
cfg.graphState = landing2d.graphstate.defaultGraphStateConfig();

% 옛 제안 모델(온톨로지 R-GAT이 보상 가중치를 설계하던 경로)의 스위치입니다.
% 새 제안 모델은 기준 모델과 같은 보상을 써야 하므로 기본값이 false입니다.
% true로 두면 run_all이 그 비교군을 예전처럼 함께 실행합니다.
% 코드는 +ontology 패키지에 그대로 남아 있고 지우지 않았습니다.
cfg.useLegacyOntologyReward = false;

% 기준 모델도 교사 없이 처음부터 학습할지 여부.
%
% false: 기준 모델은 PN 유도를 교사로 모방 학습 + PPO, 제안 모델은 교사 없이
%   학습합니다. 제안 모델이 유도 법칙의 거동을 물려받지 않게 하려는 설정이지만,
%   상태 표현 외에 학습 조건도 함께 달라집니다.
% true (기본): 두 비교군 모두 교사 없이 학습합니다. 실험 변수가 **상태 표현 하나**로
%   남으므로 비교가 가장 깔끔합니다. 대신 기준 모델도 다시 학습해야 합니다.
%
% 세 가지 조합이 가능합니다.
%   scratchBaseline=false, graphState.useScratchSettings=false -> 둘 다 교사 사용
%   scratchBaseline=false, graphState.useScratchSettings=true  -> 혼합 (과거 재현용)
%   scratchBaseline=true,  graphState.useScratchSettings=true  -> 기본값, 둘 다 교사 없음
% Controlled comparison by default: both PPO arms start without behavior
% cloning and use the same scratch-training schedule.  Set false only when
% intentionally reproducing the legacy mixed-initialization experiment.
cfg.scratchBaseline = true;
end
