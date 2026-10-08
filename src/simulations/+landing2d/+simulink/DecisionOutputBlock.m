classdef DecisionOutputBlock < landing2d.simulink.BlockBase
    % DECISIONOUTPUTBLOCK  결정 주기(0.1 s)의 관측·보상·종료 신호.
    %
    % 직전 결정 구간이 끝난 확정 상태로 environment.step의 마지막 부분을
    % 계산합니다: causal packet, 비교군별 정책 상태, landing2d.rl.computeReward
    % 보상, 종료 여부. 정책 상태는 rolloutEpisodeV2와 같습니다: 평면 공통 관측
    % 계약은 24차원 공통 관측 벡터(일반 PPO) 또는 같은 o_t의 그래프(108차원),
    % 그 밖의 설정은 정규화 causal packet 또는 packet 그래프. 보상의 이전 행동은
    % 이번 결정 직전 결정의 행동입니다(environment.step의 previousNormalizedAction).
    % 첫 표본은 reset 관측이며 보상 0입니다.
    %   outcome = [seed; 커리큘럼 수준; 반복 수준; 종료 코드; return;
    %              결정 수; 시각; 종료 여부]  (학습 통계용, To Workspace로 기록)
    properties (Nontunable)
        StateDim = 12   % Overridden by buildModel for baseline/graph policy state.
    end
    properties (Access = private)
        CumulativeReward = 0
        Recorded = false
    end

    methods (Access = protected)
        function names = inputPorts(~)
            names = {'drone','pad','measurement','track','status','clock', ...
                'snapshot','aNormPrevious','perception'};
        end
        function ports = outputPorts(obj)
            ports = {'observation',obj.StateDim;'reward',1;'isdone',1; ...
                'episodeReturn',1;'outcome',8};
        end
        function resetImpl(obj)
            obj.CumulativeReward = 0;
            obj.Recorded = false;
        end
        function s = saveObjectImpl(obj)
            s = saveObjectImpl@landing2d.simulink.BlockBase(obj);
            if isLocked(obj)
                s.CumulativeReward = obj.CumulativeReward;
                s.Recorded = obj.Recorded;
            end
        end
        function loadObjectImpl(obj,s,wasLocked)
            if wasLocked
                obj.CumulativeReward = s.CumulativeReward;
                obj.Recorded = s.Recorded;
            end
            loadObjectImpl@landing2d.simulink.BlockBase(obj,s,wasLocked);
        end
        function [observation,reward,isdone,episodeReturn,outcome] = stepImpl(obj, ...
                drone,pad,measurement,track,status,clock,snapshot,aNormPrevious, ...
                perception)
            episode = obj.currentEpisode();
            env = episode.env;
            c = env.config;
            s = obj.decode('status',status);
            % 결정 래치가 status에 둔 값은 이번 결정 직전 결정의 행동입니다(보상 입력).
            actionBefore = s.previousNormalizedAction;
            % step.m은 결정이 끝날 때 이번 결정 행동을 status에 기록합니다.
            s.previousNormalizedAction = aNormPrevious(:);
            droneState = obj.decode('drone',drone);
            padState = obj.decode('pad',pad);
            m = obj.decode('measurement',measurement);
            packet = landing2d.sensing.buildPacket(droneState, ...
                obj.decode('track',track),m,s,env.scenario,clock(1),c);
            if isempty(env.commonMemory)
                observation = policyState(packet,c);
            else
                q = obj.perceptionOf(perception);
                observation = commonPolicyState(q.O,env.observationContext,c);
            end
            assert(numel(observation) == obj.StateDim,'landing2d:StateDim', ...
                'Policy state has %d elements, block expects %d.', ...
                numel(observation),obj.StateDim);
            reward = 0;
            isdone = 0;
            if clock(3) > 0
                start = obj.decode('snapshot',snapshot);
                event = struct('occurred',s.terminated,'reason',s.terminalReason);
                reward = landing2d.rl.computeReward(truthOf(start.drone,start.pad), ...
                    truthOf(droneState,padState),m,aNormPrevious(:),clock(2),event,c, ...
                    actionBefore);
                isdone = double(s.terminated);
            end
            obj.CumulativeReward = obj.CumulativeReward+reward;
            episodeReturn = obj.CumulativeReward;
            outcome = [episode.spec.seed;specField(episode.spec,'curriculumLevel'); ...
                specField(episode.spec,'iterationLevel');status(3); ...
                episodeReturn;clock(3);clock(1);isdone];
            landing2d.simulink.episodeServer('log',struct('time',clock(1), ...
                'decision',clock(3),'drone',drone(:),'pad',pad(:), ...
                'observation',observation,'reward',reward, ...
                'detected',m.detected,'terminated',s.terminated, ...
                'reason',s.terminalReason));
            if isdone && ~obj.Recorded
                obj.Recorded = true;
                landing2d.simulink.episodeServer('record',struct( ...
                    'seed',episode.spec.seed,'terminalReason',s.terminalReason, ...
                    'return',obj.CumulativeReward,'decisions',clock(3), ...
                    'time',clock(1)));
            end
        end
    end
end

function state = policyState(packet,c)
% rolloutEpisodeV2의 policyState와 같은 비교군별 정책 입력
mode = c.graphState.stateRepresentation;
if strcmp(mode,'baseline')
    state = landing2d.sensing.normalizePacket(packet,c);
else
    state = landing2d.graphstate.contextGraph(packet,c);
end
end

function state = commonPolicyState(O,G,c)
% rolloutEpisodeV2의 평면 정책 입력: 공통 관측 벡터 또는 같은 o_t의 그래프
if strcmp(c.graphState.stateRepresentation,'baseline')
    state = landing2d.observation.toVector(O,G);
else
    state = landing2d.graphstate.observationGraph(O,G,c);
end
end

function value = specField(spec,name)
value = NaN;
if isfield(spec,name) && ~isempty(spec.(name)), value = double(spec.(name)); end
end

function truth = truthOf(drone,pad)
% step.m의 previousTruth/truth와 같은 참값 (보상 계산 전용, 정책 입력 아님)
truth = struct('ex',pad.x-drone.x,'h',drone.z-pad.z, ...
    'relativeVx',pad.vx-drone.vx,'vz',drone.vz,'theta',drone.theta, ...
    'pitchRate',drone.pitchRate);
end
