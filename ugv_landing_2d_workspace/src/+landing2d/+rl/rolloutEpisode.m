function [r,traj] = rolloutEpisode(agent,r,s,c,opts)
% ROLLOUTEPISODE  강화학습 정책으로 한 시나리오를 모사.
% 센서, 상태기계, 접촉 판정, 동역학은 PD 경로와 완전히 같은 함수를 사용하고
% 가속도 명령만 정책이 결정합니다. 학습과 평가가 같은 경로를 쓰도록 한 함수입니다.
%
%   opts.deterministic : true면 평균 행동 (평가와 최종 비교용)
%   opts.collect       : true면 학습용 전이와 보상 기록
%   opts.rs            : RandStream (deterministic=true면 사용하지 않음)
%
% 에피소드는 착륙/실패 후에도 tEnd까지 진행합니다. 착륙 상태는 계속 포착 중이고
% 거리가 0이므로 높은 보상이 유지되고, 실패 상태는 UGV가 멀어지며 벌점이 쌓입니다.
%
% 보상은 환경 참값으로 계산합니다. 참값은 보상과 로그에만 쓰고 정책 입력에는
% 넣지 않습니다(landing2d.rl.observation 참고).
rl = agent.rl;
% 상태 표현. 기준 모델은 관측 벡터를 그대로 쓰고, 제안 모델은 같은 관측 정보로
% 만든 온톨로지 그래프 X_t를 씁니다. 보상/행동/환경/종료 조건은 둘이 같습니다.
spec = agent.encoderSpec;
useGraph = ~strcmp(spec.mode,'baseline');
stateDim = spec.stateDim;
interval = rl.actionInterval;
dtAction = c.dt*interval;
t = r.time;
n = numel(t);
collect = opts.collect;
traj = struct('observation',[],'state',[],'command',[],'logProbability',[], ...
    'value',[],'reward',[],'count',0,'bootstrap',0, ...
    'captureRate',0,'return',0);
if collect
    capacity = ceil(n/interval)+1;
    % observation은 기록과 정보경계 점검용으로 항상 남깁니다. PPO가 학습에 쓰는
    % 것은 state이며, 기준 모델에서는 두 값이 같습니다.
    traj.observation = zeros(rl.observationDim,capacity);
    traj.state = zeros(stateDim,capacity);
    traj.command = zeros(rl.actionDim,capacity);
    traj.logProbability = zeros(1,capacity);
    traj.value = zeros(1,capacity);
    traj.reward = zeros(1,capacity);
end
memory = landing2d.rl.initialMemory(r.vxUgv(1));
o = zeros(rl.observationDim,1);
state = zeros(stateDim,1);
ax = 0; az = 0;
pending = 0;
previousDistance = 0;
capturedCount = 0;
decisionCount = 0;
for k = 1:n
    xp = r.xUgv(k);
    vp = r.vxUgv(k);
    [s,contact] = landing2d.environment.resolveContact(s,xp,vp,c);
    if contact.landed
        r.landingTime = t(k);
        r.status = 'Landed';
    elseif contact.failed
        r.failureTime = t(k);
        r.status = 'Unsafe contact / height violation';
    end
    obs = landing2d.sensing.observePad(s,xp,vp,c);
    [s,event] = landing2d.control.trackingMode(s,obs,c);
    if event == 1
        r.lossTimes(end+1) = t(k);
    elseif event == 2
        r.reacquireTimes(end+1) = t(k);
    end

    if mod(k-1,interval) == 0 || k == n
        captured = s.mode == 3 || obs.visible;
        decisionCount = decisionCount+1;
        capturedCount = capturedCount+double(captured);
        distance = hypot(xp-s.x,max(s.h,0));
        if collect && pending > 0
            % 보상 항 1: 착륙 패드 포착.  보상 항 2: 착륙 지점과의 상대거리.
            traj.reward(pending) = rl.captureWeight*captureSignal(s,obs,xp,rl) ...
                +rl.distanceWeight*distanceSignal(distance,previousDistance,dtAction,rl);
            pending = 0;
        end
        [o,memory] = landing2d.rl.observation(s,obs,memory,c,dtAction);
        if useGraph
            % 갱신된 memory를 그대로 넘깁니다. 관측이 쓰는 것과 같은 기억입니다.
            state = landing2d.graphstate.situationGraph(s,obs,memory,c);
        else
            state = o;
        end
        [u,logProbability] = landing2d.rl.policyAction(agent,state,opts.rs,opts.deterministic);
        [ax,az] = landing2d.rl.actionFromCommand(u,c);
        if s.mode >= 3
            ax = 0; az = 0;
        end
        if collect && k < n
            traj.count = traj.count+1;
            index = traj.count;
            traj.observation(:,index) = o;
            traj.state(:,index) = state;
            traj.command(:,index) = u;
            traj.logProbability(index) = logProbability;
            traj.value(index) = landing2d.rl.valueForward(agent,state);
            pending = index;
        end
    end

    r.xDrone(k) = s.x;
    r.zDrone(k) = c.padHeight+s.h;
    r.vxDrone(k) = s.vx;
    r.vzDrone(k) = s.vz;
    r.xError(k) = xp-s.x;
    r.fovHalfWidth(k) = obs.halfWidth;
    r.mode(k) = s.mode;
    r.visible(k) = obs.visible;
    r.descending(k) = s.mode < 3 && s.vz < 0;
    r.axCommand(k) = ax;
    r.azCommand(k) = az;
    % 강화학습에는 PD의 기준 궤적이 없으므로 실제 상대 고도를 기록.
    r.heightReference(k) = s.h;
    if k < n
        s = landing2d.dynamics.stepDrone(s,ax,az,xp,r.xUgv(k+1),r.vxUgv(k+1),c);
    end
end
if collect
    % 유한 지평선 부트스트랩: 마지막 관측의 가치로 잔여 보상을 근사.
    traj.bootstrap = landing2d.rl.valueForward(agent,state);
    count = traj.count;
    traj.observation = traj.observation(:,1:count);
    traj.state = traj.state(:,1:count);
    traj.command = traj.command(:,1:count);
    traj.logProbability = traj.logProbability(1:count);
    traj.value = traj.value(1:count);
    traj.reward = traj.reward(1:count);
    traj.return = sum(traj.reward);
end
traj.captureRate = capturedCount/max(decisionCount,1);
end

function value = distanceSignal(distance,previous,dtAction,rl)
% 보상 항 2. [-1, +1] 범위입니다.
%
% 두 성분을 섞습니다.
%   변화율   : (이전 거리 - 현재 거리)/dt 를 기준 속도로 정규화.
%              가까워지면 +, 멀어지면 -, 제자리면 0.
%   거리 자체: 가까우면 +, 멀면 -.
%
% 변화율만 쓰면 어느 고도에 있든 누적 가치가 같아집니다(망원경 합). 그러면 고도를
% 포착 항이 혼자 결정하고, 시야가 넓은 높은 곳에 머무는 해가 최적이 됩니다.
% 거리 자체 항이 있어야 "낮은 곳에 있는 것" 자체에 가치가 생겨 착륙이 목표가 됩니다.
% 즉 변화율은 유도(shaping), 거리 자체는 목표(objective) 역할입니다.
rate = landing2d.util.saturate( ...
    (previous-distance)/(dtAction*rl.distanceRateScale),1);
proximity = landing2d.util.saturate( ...
    1-(distance/rl.distanceScale)^rl.distanceExponent,1);
switch rl.distanceMode
    case 'hybrid'
        share = rl.distanceRateShare;
        value = share*rate+(1-share)*proximity;
    case 'rate'
        value = rate;
    case 'proximity'
        value = proximity;
    otherwise
        error('landing2d:UnknownDistanceMode', ...
            'Unknown distanceMode: %s',rl.distanceMode);
end
end

function value = captureSignal(s,obs,xp,rl)
% 포착 항의 값. [-1, +1] 범위입니다.
%
%   'margin' : 시야 중앙이면 +1, 시야 가장자리면 -1, 시야 밖이면 -1.
%              가시 여부만 보면 중앙으로 모을 유인이 없어, 정책이 시야 가장자리에
%              붙은 채 하강하지 못합니다. 시야 여유를 쓰면 중앙 정렬 자체에
%              보상이 붙고, 그 결과가 고도에 비례해 오차가 줄어드는 하강입니다.
%   'binary' : 이전 방식. 보이면 +1, 아니면 -1.
if s.mode == 3
    value = 1;   % 착륙 완료: 패드 위에 있으므로 최대
    return;
end
if strcmp(rl.captureMode,'binary')
    value = 2*double(obs.visible)-1;
    return;
end
margin = abs(xp-s.x)/max(obs.halfWidth,1e-6);
value = 1-2*min(margin,1);
end
