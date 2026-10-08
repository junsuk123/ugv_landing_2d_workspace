function rep = replaySensing(record,c,scale)
% REPLAYSENSING  기준 궤적의 같은 물리 상태에서 측정 단계부터 공통 관측을 다시 계산.
% 배율 SCALE의 시간 기준 잡음표(같은 표준정규 표본, 표준편차 x SCALE)로 마커 검출·
% 융합 측위를 다시 만들고, UGV 상태추정기(PnP·KF)·공통 관측·결정 문맥을 결정 순서대로
% 재계산합니다. 환경 step의 인지 경로와 같은 함수·같은 순서이므로 SCALE = 1이면 환경이
% 실제로 만든 관측·결정 문맥과 비트 단위로 같아야 합니다(selfTest probe-replay,
% landing2d.probe.buildBank). 오차는 측정 단계에만 들어가므로 위치·속도·가속 추세와
% 파생 그래프 특징 사이에 모순되는 독립 잡음이 생기지 않습니다.
% 출력 (결정 시점 k = 0..n, 열 k+1):
%   O                공통 관측 구조체 (그래프 특징 재계산용)
%   observation      정책 관측 벡터 (24 x n+1)
%   flags            관측 신뢰도: visionUpdated, estimateInitialized, poseValid,
%                    detectedCount, navigationValid, historyValid, visionAge
%                    안전 판단 경계: landingInhibited, abortRequested, finalDescentActive
%   perceptionError  평가 전용 UGV 추정 오차 (position, velocity: 2 x n+1)
co = c.experiment.commonObservation;
c.experiment.currentScenario = record.scenario;
G = landing2d.observation.staticContext(c);
noise = landing2d.sensing.exogenousNoise(c,record.base,record.scenario.deadline,scale);
m = numel(record.time);
memory = landing2d.observation.initialMemory();
status = landing2d.environment.initialStatus(numel(landing2d.environment.actionLimits(c)));
O = cell(1,m);
observation = zeros(size(record.observation,1),m);
flags = struct('visionUpdated',false(1,m),'estimateInitialized',false(1,m), ...
    'poseValid',false(1,m),'detectedCount',zeros(1,m),'navigationValid',false(1,m), ...
    'historyValid',false(1,m),'visionAge',inf(1,m),'landingInhibited',false(1,m), ...
    'abortRequested',false(1,m),'finalDescentActive',false(1,m));
perceptionError = struct('valid',false(1,m),'position',NaN(2,m),'velocity',NaN(2,m));
for k = 1:m
    t = record.time(k);
    x = record.state(:,k);
    state = struct('x',x(1),'z',x(2),'vx',x(3),'vz',x(4),'theta',x(5), ...
        'pitchRate',x(6),'collectiveThrust',x(7));
    p = record.pad(:,k);
    pad = struct('x',p(1),'z',p(2),'vx',p(3),'ax',p(4));
    frame = struct('dropout',record.frameDropout(k),'frameCaptured',record.frameCaptured(k));
    detections = landing2d.sensing.detectMarkers(state,pad,t,c.experiment.sensor,co, ...
        noise.marker(:,:,:,k),frame);
    navigation = landing2d.sensing.navigationEstimate(state,t,co.navigation, ...
        noise.navigation(:,k));
    [O{k},memory,detail] = landing2d.observation.capture(memory,detections,navigation,t,G);
    if record.frameCaptured(k)
        % The environment updates the decision context after every captured
        % frame (reset and each non-terminal decision).
        [~,track] = landing2d.environment.perceptionView(O{k},state,status,t, ...
            record.scenario,c);
        status = landing2d.environment.updateDecisionContext(status,track,t,c,state);
    end
    observation(:,k) = landing2d.observation.toVector(O{k},G);
    u = O{k}.ugv;
    flags.visionUpdated(k) = u.visionUpdated;
    flags.estimateInitialized(k) = u.estimateInitialized;
    flags.poseValid(k) = detail.pose.valid;
    flags.detectedCount(k) = numel(detections.ids);
    flags.navigationValid(k) = O{k}.drone.navigationValid;
    flags.historyValid(k) = O{k}.history.valid;
    flags.visionAge(k) = u.visionAge;
    flags.landingInhibited(k) = status.landingInhibited;
    flags.abortRequested(k) = status.abortRequested;
    flags.finalDescentActive(k) = isfield(status,'finalDescentActive') && status.finalDescentActive;
    e = landing2d.metrics.perceptionError(O{k},pad,G);
    perceptionError.valid(k) = e.valid;
    perceptionError.position(:,k) = e.position;
    perceptionError.velocity(:,k) = e.velocity;
end
rep = struct('scale',scale,'O',{O},'observation',observation,'flags',flags, ...
    'perceptionError',perceptionError,'context',G);
end
