function co = defaultCommonObservationConfig(padHeight)
% DEFAULTCOMMONOBSERVATIONCONFIG  최소 공통 관측 o_t(12차원)와 부가 정보 Gamma의 기본값.
%   G_t  UGV 추정 상태 (6): 위치 x,z, 속도 vx,vz, 영상 보정 여부, 마지막 영상 보정 후 경과시간
%   D_t  드론 융합 측위 (9): x, z, vx, vz, sin/cos pitch, pitch rate, 측위 유효, 측위 경과시간
%   H_t  직전 운동 기록 (9): 직전 결정 시점의 UGV·드론 위치·속도, 기록 유효
% 인지 경로: ArUco 코너 -> 평면 PnP(카메라 기준 패드 자세) -> 드론 측위·장착 관계로
% 로컬 UGV 위치 관측 -> 등속 칼만 필터 -> UGV 위치·속도. 미검출 시 예측만 수행합니다.
% PADHEIGHT(scenario.padHeight)는 UGV 기준점(패드 중심 아래 지면)에서 패드 상면까지의 높이입니다.
% 평면 계약(spatialDimension=2) 전용입니다. 세 비교군의 정책 입력이고, 같은 UGV
% 추정이 안전 감독기·착륙 승인을 구동하므로 설정 전체가 task fingerprint·학습 서명에
% 포함됩니다.
co.schemaVersion = 'minimal_common_observation_v3';
% 시간 기준 센서 잡음 (landing2d.sensing.exogenousNoise). reset에서 전용 난수열로
% 결정 시점 k와 물리 스텝 j로 색인한 표준정규 잡음표를 한 번 만들고, 마커 코너·융합
% 측위·평면 tracker 측정이 같은 시각에 같은 표 값을 씁니다. 같은 시각의 잡음 실현값은
% 검출된 마커, 정책, 조기 종료와 무관합니다. 기존 센서 난수열(sensorOffset)은 외생
% 사건(dropout·pitch 외란) 표본에만 씁니다.
co.randomStreams = struct('indexing','time_indexed_v1', ...
    'markerOffset',3000000,'navigationOffset',4000000,'trackerOffset',5000000);
% 마커 카메라 보정 (Gamma, OpenCV 규약). 논문 설정: 512x320, 수평 FOV 90도,
% 전방축 기준 아래 60도 장착. 좌표계:
%   B  기체: x 전방, y 좌측, z 추력축(위). 월드 기준 자세 R_WB = R_y(theta).
%   C  카메라 광학: x 영상 오른쪽, y 영상 아래, z 광축.
%   intrinsicMatrix  K = [fx s cx; 0 fy cy; 0 0 1], 0 기준 픽셀
%   distortion       d = [k1 k2 p1 p2 k3] (plumb_bob), 보정 자료 미확보로 0
%   bodyToCamera     BT_C = [R_BC t_BC; 0 0 0 1], p_B = R_BC*p_C + t_BC (고정 장착 관계)
% 평면 실험의 카메라는 이 마커 카메라 하나입니다. tracker 측정(experiment.sensor)도
% 이 보정에서 계산한 x-z 기하를 씁니다(landing2d.sensing.planarCameraGeometry).
W = 512; H = 320; horizontalFov = deg2rad(90);
f = (W-1)/2/tan(horizontalFov/2);
co.camera = struct( ...
    'calibrationId','sim_paper_forward60_v1', ...
    'imageSize',[W,H], ...
    'intrinsicMatrix',[f,0,(W-1)/2; 0,f,(H-1)/2; 0,0,1], ...
    'distortion',zeros(1,5), ...
    'bodyToCamera',forwardDownMount(deg2rad(60)));
% 시뮬레이션 검출기 특성 (Gamma 아님, 센서 모델 내부)
co.detector = struct( ...
    'pixelNoiseStd',0.5, ...     % 코너 좌표 잡음 [px]
    'minimumSidePixels',10, ...  % 최소 변 길이 [px], 미만이면 미검출
    'borderPixels',2);           % 네 코너 모두 영상 경계에서 이만큼 안쪽이어야 검출 [px]
% 시뮬레이션 융합 측위 잡음 (논문 설정, 1σ 평균 0 가우시안으로 해석, 센서 모델 내부).
% 위치·pitch rate 잡음은 논문에 제시되지 않아 넣지 않습니다.
co.navigation = struct( ...
    'velocityNoiseStd',0.05, ...         % 기체 좌표계 속도 [m/s]
    'attitudeNoiseStd',deg2rad(0.5));    % pitch [rad]
% 마커 구성·기하 (Gamma). 좌표는 패드 기준 (x 전방, y 좌측) [m], 모든 마커는
% 패드 축과 정렬. 1 m x 1 m 패드(padHalfLength = 0.5)에 중앙 대형 마커 1개와
% 모서리 소형 마커 4개. markerIds의 순서가 ID -> 고정 슬롯 대응입니다.
co.pad = struct( ...
    'padId',0, ...
    'markerIds',[10,11,12,13,14], ...
    'markerCenters',[0,0; 0.375,0.375; 0.375,-0.375; -0.375,-0.375; -0.375,0.375], ...
    'markerSides',[0.50,0.15,0.15,0.15,0.15]);
% UGV 장착 관계 (Gamma). 수평 지면 직선 주행 가정: UGV pitch·pitch rate = 0, R_WG = I.
% padOffset = r_{G->P}: UGV 기준점(패드 중심 아래 지면)에서 패드 상면 중심까지 [x; z] [m].
co.ugv = struct('padOffset',[0;padHeight]);
% 인지 기반 착륙 승인의 최종 하강 단계 (안전 감독기 설정, Gamma 아님).
% 전방 아래 60도 카메라는 패드 위 약 0.3-0.45 m 아래에서 마커 코너를 영상에 담지
% 못해 마지막 하강이 사각지대입니다. 최근 영상 보정(recentTrackGrace) 상태로 진입
% 고도 이하에 들어오면 접촉까지 승인을 유지합니다(3차원 옵션의 최종 하강과 같은 규칙).
% 최대 유지 시간은 prolongedLoss 이하입니다.
co.finalDescent = struct( ...
    'enterHeight',0.5, ...  % 진입 고도 (패드 면 기준) [m]
    'exitHeight',0.7, ...   % 이 고도를 넘으면 해제 [m]
    'maxDuration',3.0);     % 진입 후 최대 유지 시간 [s]
% UGV 상태추정기 설계값 (Gamma). 논문이 공개한 수치가 아니라 이번 설계의 선택입니다.
% 가속도 잡음·코너 잡음 가정·초기 속도 표준편차는 검증 시드(2001-2040)의 스크립트
% 비행에서 위치 RMSE + 속도 RMSE가 최소인 격자점입니다(시험 시드 미사용).
% z축 가속도 잡음이 작은 것은 수평 주행 UGV의 수직 가속도가 작다는 사전값이며,
% z 위치·속도를 고정하지는 않습니다. 초기 속도는 속도 정합 reset 계약의 드론 속도입니다.
co.estimator = struct( ...
    'cornerNoiseStd',1.0, ...            % PnP 관측 공분산에 쓰는 코너 잡음 가정 [px]
    'attitudeNoiseStd',deg2rad(0.5), ... % 관측 공분산에 쓰는 측위 자세 잡음 가정 [rad]
    'accelerationNoiseStd',[0.5,0.05], ... % 등속 모델 축별 백색 가속도 잡음 [x, z] [m/s^2]
    'initialVelocityStd',0.5, ...        % 초기화 시 속도 표준편차 [m/s]
    'maxReprojectionError',2.0, ...      % PnP 채택 상한 (재투영 RMS) [px]
    'pnpIterations',20);                 % Gauss-Newton 정련 반복 수
% 관측 벡터 정규화 척도 x/(|x|+s), 경과시간 t/(t+s). 로컬 x는 에피소드 중
% 수백 m까지 커지므로 현재 드론 x 기준 상대값으로 정규화합니다(병진 불변,
% drone_x 슬롯은 0). 척도 3 m는 기존 causal packet의 수평 오차 척도와 같습니다.
% 속도·각속도 척도는 c.vxMax, c.vzMax, experiment.dynamics.pitchRateLimit입니다.
co.normalization = struct( ...
    'relativePositionScale',3, ... % 현재 드론 x 기준 x [m]
    'heightScale',8, ...           % 로컬 z [m]
    'ageScale',3);                 % 경과시간 [s]
end

function T = forwardDownMount(alpha)
% 광축 = 기체 전방에서 alpha만큼 아래, 영상 오른쪽 = 기체 우측 -y.
% alpha = 90도이면 수직 하향(영상 위쪽 = 기체 전방)입니다.
c = cos(alpha); s = sin(alpha);
T = [0,-s,c,0; -1,0,0,0; 0,-c,-s,0; 0,0,0,1];
end
