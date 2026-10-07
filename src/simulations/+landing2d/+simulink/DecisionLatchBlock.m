classdef DecisionLatchBlock < landing2d.simulink.BlockBase
    % DECISIONLATCHBLOCK  결정 경계 처리와 물리 스텝 시간 간격 계산.
    %
    % 새 결정 번호가 들어오면 environment.step의 결정 시작과 같은 일을 합니다:
    % 직전 결정 행동을 status에 기록하고, 경과 시간을 0으로, 결정 시작 상태를
    % snapshot에 저장합니다. 물리 간격은 step과 같은 식입니다.
    %   dt = min([physicsDt, policyDt-경과, 마감-시각])
    %   timing = [t0; dt; t0+dt; 활성 여부]
    methods (Access = protected)
        function names = inputPorts(~)
            names = {'drone','pad','status','clock','snapshot','aNorm', ...
                'decisionIndex'};
        end
        function ports = outputPorts(obj)
            ports = {'status',obj.width('status');'clock',obj.width('clock'); ...
                'snapshot',obj.width('snapshot');'timing',obj.width('timing')};
        end
        function [statusOut,clockOut,snapshotOut,timing] = stepImpl(obj, ...
                drone,pad,status,clock,snapshot,aNorm,decisionIndex)
            episode = obj.currentEpisode();
            e = episode.env.config.experiment;
            s = obj.decode('status',status);
            clockOut = clock(:);
            snapshotOut = snapshot(:);
            if ~s.terminated && decisionIndex ~= clock(3)
                s.previousNormalizedAction = clock(4:5);
                clockOut(2) = 0;
                clockOut(3) = decisionIndex;
                clockOut(4:5) = min(max(aNorm(:),-1),1);
                snapshotOut = [drone(:);pad(:)];
            end
            time = clockOut(1);
            elapsed = clockOut(2);
            active = ~s.terminated && elapsed < e.policyDt-1e-12;
            dt = min([e.physicsDt,e.policyDt-elapsed, ...
                episode.env.scenario.deadline-time]);
            timing = [time;dt;time+dt;double(active)];
            statusOut = obj.encode('status',s);
        end
    end
end
