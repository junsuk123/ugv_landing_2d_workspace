classdef PadTrajectoryBlock < landing2d.simulink.BlockBase
    % PADTRAJECTORYBLOCK  UGV 패드의 CV-CA-CV 궤적 (landing2d.scenario.evaluateTrajectory).
    % 출력 pad = [x; z; vx; ax; 구간 번호], 시각은 이번 물리 스텝 끝 시각입니다.
    methods (Access = protected)
        function names = inputPorts(~)
            names = {'pad','timing'};
        end
        function ports = outputPorts(obj)
            ports = {'padNext',obj.width('pad')};
        end
        function padNext = stepImpl(obj,pad,timing)
            padNext = pad(:);
            if timing(4) == 0, return; end
            scenario = obj.currentEpisode().env.scenario;
            [x,vx,ax,phase] = landing2d.scenario.evaluateTrajectory(scenario,timing(3));
            padNext = [x;scenario.padHeight;vx;ax;phase];
        end
    end
end
