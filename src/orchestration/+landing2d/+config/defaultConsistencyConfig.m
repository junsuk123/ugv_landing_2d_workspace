function cc = defaultConsistencyConfig()
% DEFAULTCONSISTENCYCONFIG  정책 일관성 검증 설정: 관측오차 배율·고정 probe·명령 로그.
% 평가 전용 설정이라 최상위 c.consistency에 두며 학습 서명·task fingerprint에
% 들어가지 않습니다. 고정 probe는 평면 공통 관측 계약 전용입니다.
cc.schemaVersion = 'policy_consistency_v1';
% 관측오차 표준편차 배율. 기존 센서 오차(마커 코너 0.5 px, 융합 측위 속도 0.05 m/s·
% 자세 0.5°, 평면 tracker 상대 위치·bearing)의 표준편차에 곱하고, 공분산은 배율의
% 제곱으로 바뀝니다. 같은 시간 기준 표준정규 잡음표를 배율만 바꿔 쓰므로 배율 간
% 잡음이 짝지어집니다. 시간 상관(백색)·dropout·pitch 외란 일정은 바꾸지 않으며,
% UGV 상태추정기의 잡음 가정(experiment.commonObservation.estimator)은 인지 모듈
% 설계값이라 그대로 둡니다.
cc.noiseScales = [0,0.5,1,2];
cc.nominalScale = 1;
% 기준 관측: 같은 상태·같은 측정 이력에서 잡음 배율 0으로 만든 관측.
cc.referenceScale = 0;
% 고정 probe: 비교군과 무관한 인과적 스크립트 구동기(landing2d.probe.referenceDriver)로
% 실제 환경을 비행해 도달 가능한 상태와 외생 사건을 기록하고, 측정 단계부터 배율별로
% 다시 계산합니다(UGV 추정기·공통 관측·그래프 특징 재계산). 정책 행동은 기준 궤적에
% 되먹이지 않습니다.
cc.probe = struct( ...
    'driver','causal_tracking_v1', ...
    'driverNoise',0.10, ...        % 구동기 명령 잡음 표준편차 [행동 한계 비율], 상태 다양화
    'randomOffset',6000000, ...    % 구동기 잡음 전용 난수열 (기존 난수열과 분리)
    'stride',5, ...                % probe 간격 [결정 시점]
    'validationEpisodeCount',100, ...
    'testEpisodeCount',100);
% 폐루프 명령 로그 (landing2d.rl.rolloutEpisodeV2의 commandLog).
cc.log = struct('physicsSteps',true);
% 학습 진행 스냅샷 수: PPO 중간 정책을 약 이 개수만큼(시작점 포함) 저장해 학습
% 진행(누적 환경 스텝)에 따른 일관성 지표를 계산합니다. 학습 결과에는 영향이 없습니다.
cc.trainingSnapshots = 10;
% 독립 유효 판정기 (landing2d.metrics.behaviorValidity). 고정 명령 예측 horizon과
% 과업 후퇴 허용 비율 kappa(같은 상태에서 안전한 격자 명령이 내는 결과 범위 대비)는
% 후보 중에서 validation probe만으로 고르고(landing2d.consistency.calibrateValidity)
% test 전에 동결합니다. 선택 기준은 비교군 정책과 무관합니다: 적용 가능 probe
% 비율 >= minimumApplicable이고, 비교군과 무관한 인과적 기준 구동기의 실제 명령이
% minimumDriverValid 이상 유효한(유능한 제어기를 무효로 몰지 않는) 후보 중에서
% 격자 행동의 비허용 비율(판별력)이 가장 큰 것. 접촉·제동·시야 여유의 허용 임계값은
% 계약 값 그대로(여유 >= 0)입니다.
cc.validity = struct( ...
    'horizonCandidates',[0.3,0.5,1.0,1.5,2.0], ... % 고정 명령 예측 horizon 후보 [s]
    'kappaCandidates',[0.25,0.5,0.75], ... % 과업 후퇴 허용 비율 후보
    'gridPoints',7, ...                    % 행동 격자 점 수 (축마다)
    'minimumApplicable',0.90, ...          % 적용 가능 probe 비율 하한
    'minimumDriverValid',0.95, ...         % 기준 구동기 명령 유효 비율 하한
    'minimumContextSamples',10);           % C_valid 문맥 평균에 넣는 최소 표본 수
% 정상 추종 구간 (J_policy): 외생 사건 일정만으로 정의합니다. UGV 등가속 구간,
% dropout, pitch 외란과 각 사건 뒤 settling 시간, 시작 과도 구간을 빼고, 에피소드
% 종료에서 자릅니다. 떨어진 구간은 잇지 않고 구간 안에서만 차분합니다.
cc.jerk = struct('initialTransient',1.0,'settling',2.0,'minimumWindow',1.0); % [s]
end
