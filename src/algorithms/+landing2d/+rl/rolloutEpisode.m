function [r,traj] = rolloutEpisode(agent,r,s,c,opts)
% ROLLOUTEPISODE  강화학습 정책으로 한 시나리오를 모사.
% 센서, 상태기계, 접촉 판정, 동역학은 PD 경로와 완전히 같은 함수를 사용하고
% 가속도 명령만 정책이 결정합니다. 학습과 평가가 같은 경로를 쓰도록 한 함수입니다.
%
%   opts.deterministic : true면 평균 행동 (평가와 최종 비교용)
%   opts.collect       : true면 학습용 전이와 보상 기록
%   opts.rs            : RandStream (deterministic=true면 사용하지 않음)
%
% 표시 로그는 착륙/실패 뒤에도 tEnd까지 채우지만 PPO 전이는 종말에서 끝납니다.
% 가짜 post-terminal 전이를 만들지 않으면서 조기 실패로 미래 벌점을 회피하지
% 못하도록, 남은 유한 지평선의 흡수상태 보상을 마지막 전이에 lump-sum으로 넣습니다.
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
traceGraph = isfield(opts,'traceGraph') && opts.traceGraph && useGraph;
traj = struct('observation',[],'state',[],'command',[],'logProbability',[], ...
    'value',[],'reward',[],'count',0,'bootstrap',0, ...
    'captureRate',0,'return',0,'graphValues',[],'graphStates',[]);
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
if traceGraph
    graphSchema = landing2d.graphstate.schemaFor(spec.mode);
    graphCapacity = ceil(n/interval)+1;
    traj.graphValues = zeros(graphSchema.nNodes,graphCapacity);
    traj.graphStates = zeros(stateDim,graphCapacity);
    graphCount = 0;
end
memory = landing2d.rl.initialMemory(r.vxUgv(1));
o = zeros(rl.observationDim,1);
state = zeros(stateDim,1);
ax = 0; az = 0;
pending = 0;
terminalReached = false;
% Distance at the start of the pending action.  It is updated only after
% the preceding transition reward has been calculated.
previousDistance = NaN;
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
        if ~terminalReached
            decisionCount = decisionCount+1;
            capturedCount = capturedCount+double(captured);
        end
        distance = hypot(xp-s.x,max(s.h,0));
        if collect && pending > 0
            % 보상 항 1: 착륙 패드 포착.  보상 항 2: 착륙 지점과의 상대거리.
            captureReward = landing2d.rl.captureSignal(s,obs,xp,rl);
            distanceReward = landing2d.rl.distanceSignal( ...
                distance,previousDistance,dtAction,rl,s.mode);
            if s.mode >= 3
                % Equivalent to holding terminal capture/distance signals
                % for the remaining action-time horizon, without recording
                % invalid transitions after termination.
                remaining = floor((n-k)/interval);
                multiplier = discountedCount(remaining+1,rl.gamma);
                captureReward = multiplier*captureReward;
                distanceReward = multiplier*distanceReward;
            end
            traj.reward(pending) = rl.captureWeight*captureReward ...
                +rl.distanceWeight*distanceReward;
            pending = 0;
        end
        terminalReached = terminalReached || s.mode >= 3;
        [o,memory] = landing2d.rl.observation(s,obs,memory,c,dtAction);
        if useGraph
            % 갱신된 memory를 그대로 넘깁니다. 관측이 쓰는 것과 같은 기억입니다.
            if traceGraph && ~terminalReached
                [state,graphDetail] = landing2d.graphstate.situationGraph(s,obs,memory,c);
                graphCount = graphCount+1;
                traj.graphValues(:,graphCount) = graphDetail.values(:);
                traj.graphStates(:,graphCount) = state;
            elseif ~traceGraph
                state = landing2d.graphstate.situationGraph(s,obs,memory,c);
            end
        else
            state = o;
        end
        [u,logProbability] = landing2d.rl.policyAction(agent,state,opts.rs,opts.deterministic);
        [ax,az] = landing2d.rl.actionFromCommand(u,c);
        if s.mode >= 3
            ax = 0; az = 0;
        end
        if collect && k < n && ~terminalReached
            traj.count = traj.count+1;
            index = traj.count;
            traj.observation(:,index) = o;
            traj.state(:,index) = state;
            traj.command(:,index) = u;
            traj.logProbability(index) = logProbability;
            traj.value(index) = landing2d.rl.valueForward(agent,state);
            previousDistance = distance;
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
    if terminalReached
        traj.bootstrap = 0;
    else
        traj.bootstrap = landing2d.rl.valueForward(agent,state);
    end
    count = traj.count;
    traj.observation = traj.observation(:,1:count);
    traj.state = traj.state(:,1:count);
    traj.command = traj.command(:,1:count);
    traj.logProbability = traj.logProbability(1:count);
    traj.value = traj.value(1:count);
    traj.reward = traj.reward(1:count);
    traj.return = sum(traj.reward);
end
if traceGraph
    traj.graphValues = traj.graphValues(:,1:graphCount);
    traj.graphStates = traj.graphStates(:,1:graphCount);
end
traj.captureRate = capturedCount/max(decisionCount,1);
end

function value = discountedCount(count,gamma)
% Sum_{j=0}^{count-1} gamma^j, evaluated stably near gamma=1.
if count <= 0
    value = 0;
elseif abs(1-gamma) < 1e-12
    value = count;
else
    value = (1-gamma^count)/(1-gamma);
end
end
