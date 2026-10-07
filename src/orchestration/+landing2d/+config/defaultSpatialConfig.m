function s = defaultSpatialConfig()
% DEFAULTSPATIALCONFIG  3차원(spatialDimension=3) 확장 옵션의 기본값.
% 평면 계약(planar_visibility_v2)에 측방 y축과 roll 축을 더한 값만 둡니다.
% 2차원 기본 실행은 이 파일을 읽지 않으므로 2차원 수치·체크포인트 서명은 그대로입니다.
s.dimension = 3;
s.schemaVersion = 'spatial_visibility_v1';
% 패드는 x(진행) 방향 반길이 padHalfLength, y(측방) 방향 반폭 padHalfWidth의 직사각형.
s.padHalfWidth = 0.5;                 % [m]
% 측방 가속도 행동 한계. 수평 axMax와 같은 기체 권한을 가정합니다.
s.lateralAccelerationLimit = 2.5;     % [m/s^2]
% UGV 측방 운동: 진행 방향과 같은 구간 시각(T1, T2)의 CV-CA-CV.
% 결과적으로 지면 궤적은 직선-포물선-직선(방향 전환)입니다.
s.lateralV1Range = [-0.5,0.5];        % 첫 구간 측방 속도 [m/s]
s.lateralA2Range = [-0.6,0.6];        % CA 구간 측방 가속도 [m/s^2]
s.y0 = 0;                             % 패드 초기 측방 위치 [m]
% 최종 하강 단계 (결정 문맥). 패드 중심점 투영 모델에서는 고도 10 cm 이하의
% 카메라 시야 반경이 5 cm 미만이라, 패드 바로 위에서도 두 축 오차가 조금만
% 생기면 검출이 끊기고 착지 승인이 해제됩니다. 실기체의 blind final descent처럼
% 신뢰 검출 상태로 이 고도대에 들어오면 접촉까지 승인을 유지합니다.
s.finalDescentHeight = 0.15;      % 진입 고도 (패드 면 기준) [m]
s.finalDescentExitHeight = 0.25;  % 이 고도를 넘으면 해제 [m]
s.finalDescentMaxDuration = 3.0;  % 진입 후 최대 유지 시간 [s]
% 보상: 결정 간 정규화 행동 변화량 비용 (세 비교군 공통, 3차원 전용).
% 두 축 자세 각속도가 동시에 착지 허용치 안에 있어야 하므로 채터링을 억제합니다.
s.actionChangeWeight = 10;
% 3차원 체크포인트는 2차원 체크포인트와 섞이지 않도록 하위 폴더에 저장합니다.
s.outputSubdir = 'spatial3d';

%% 3차원 학습 설정 (세 비교군 공통, 학습 에피소드 전용, 평가는 공칭 계약)
% 평면 탐색 설정 그대로의 3차원 PPO는 baseline·semantic-flat 각 2500회에서
% 착륙 0%였습니다. 착지 조건이 pitch·roll 두 축의 자세·각속도와 원뿔 시야 안의
% 최근 신뢰 검출을 동시에 요구해, 초기 착지 시도가 거의 모두 실패하고 정책이
% 상승·중단(SAFE_ABORT) 또는 패드 위 체공(TASK_TIMEOUT)에 수렴했습니다.
% 아래 네 항목을 함께 쓸 때만 착륙 학습이 나타났습니다(통제 실험, docs/SPATIAL_3D_KO.md).
s.initialLogStd = -1.6;                   % a_x·a_z 초기 탐색 잡음 (평면 -1.1)
s.lateralInitialLogStd = -2.3;            % a_y 초기 탐색 잡음
s.touchdownAttitudeCurriculumScale = 2.0; % 착지 자세·각속도 허용치 초기 배율 -> 1
s.trackAuthorizationCurriculumScale = 2.0;% 최근 검출 허용 x2, 최소 신뢰도 /2 -> 1
end
