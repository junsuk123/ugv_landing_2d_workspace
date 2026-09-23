function data = teacherDataset(c,rl,rs)
% TEACHERDATASET  기준 유도 법칙을 교사로 사용한 모방 학습용 시연 데이터.
% 관측은 강화학습 정책이 받는 것과 동일하고, 목표는 같은 시각의 교사 가속도 명령입니다.
% 여기서도 비가시 구간의 패드 참값은 관측에 넣지 않습니다.
%
% 실행에는 작은 잡음을 섞고 라벨은 잡음 없는 교사 명령을 사용합니다.
% 학생 정책이 교사 궤적에서 조금 벗어나도 따라올 수 있도록 주변 상태를 덮습니다.
nCases = size(c.scenarioSpeeds,1);
interval = rl.actionInterval;
dtAction = c.dt*interval;
% 상태 표현이 그래프인 경우 모방 학습도 같은 그래프를 받아야 합니다.
% 기준 모델에서는 state와 observation이 같은 값입니다.
[~,spec] = landing2d.graphstate.encoderInit(c.graphState,rl.observationDim, ...
    RandStream('threefry','Seed',0));
useGraph = ~strcmp(spec.mode,'baseline');
observations = cell(rl.bcEpisodes,1);
states = cell(rl.bcEpisodes,1);
commands = cell(rl.bcEpisodes,1);
for e = 1:rl.bcEpisodes
    index = mod(e-1,nCases)+1;
    [r,s] = landing2d.rl.makeEpisode(c,index,rl,rs,rl.teacherHeightRange);
    n = numel(r.time);
    capacity = ceil(n/interval);
    o = zeros(rl.observationDim,capacity);
    g = zeros(spec.stateDim,capacity);
    u = zeros(rl.actionDim,capacity);
    memory = landing2d.rl.initialMemory(r.vxUgv(1));
    count = 0;
    axExecuted = 0;
    azExecuted = 0;
    for k = 1:n
        xp = r.xUgv(k);
        vp = r.vxUgv(k);
        s = landing2d.environment.resolveContact(s,xp,vp,c);
        obs = landing2d.sensing.observePad(s,xp,vp,c);
        [s,ax,az] = landing2d.control.command(s,obs,c);
        if mod(k-1,interval) == 0
            axExecuted = landing2d.util.saturate( ...
                ax+rl.teacherNoise*c.axMax*randn(rs),c.axMax);
            azExecuted = landing2d.util.saturate( ...
                az+rl.teacherNoise*c.azMax*randn(rs),c.azMax);
            if s.mode < 3
                [observation,memory] = landing2d.rl.observation(s,obs,memory,c,dtAction);
                count = count+1;
                o(:,count) = observation;
                if useGraph
                    g(:,count) = landing2d.graphstate.situationGraph(s,obs,memory,c);
                else
                    g(:,count) = observation;
                end
                u(:,count) = landing2d.rl.commandFromAction(ax,az,c);
            end
        end
        if k < n
            s = landing2d.dynamics.stepDrone(s,axExecuted,azExecuted,xp, ...
                r.xUgv(k+1),r.vxUgv(k+1),c);
        end
    end
    observations{e} = o(:,1:count);
    states{e} = g(:,1:count);
    commands{e} = u(:,1:count);
end
data.observation = [observations{:}];
data.state = [states{:}];
data.command = [commands{:}];
data.sampleCount = size(data.observation,2);
end
