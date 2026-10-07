classdef DroneDynamicsBlock < landing2d.simulink.BlockBase
    % DRONEDYNAMICSBLOCK  평면 피치·추력 지연 동역학 (landing2d.dynamics.stepPlanar).
    %
    % 피치 외란 사건은 reset이 뽑은 sensorEvents 일정을 따릅니다. 이 블록은
    % 물리 간격 dt 동안 상태를 한 번 적분하고, 비활성 스텝에서는 상태를 유지합니다.
    methods (Access = protected)
        function names = inputPorts(~)
            names = {'drone','aApplied','timing'};
        end
        function ports = outputPorts(obj)
            ports = {'droneNext',obj.width('drone');'hardViolation',1};
        end
        function [droneNext,hardViolation] = stepImpl(obj,drone,applied,timing)
            droneNext = drone(:);
            hardViolation = 0;
            if timing(4) == 0, return; end
            env = obj.currentEpisode().env;
            events = env.sensorEvents;
            t0 = timing(1);
            dt = timing(2);
            pitchDisturbance = 0;
            if t0 >= events.pitchStart && t0 < events.pitchEnd
                pitchDisturbance = events.pitchRate*dt;
            end
            [next,info] = landing2d.dynamics.stepPlanar(obj.decode('drone',drone), ...
                applied(:),dt,env.config.experiment.dynamics,pitchDisturbance);
            droneNext = obj.encode('drone',next);
            hardViolation = double(info.hardEnvelopeViolation);
        end
    end
end
