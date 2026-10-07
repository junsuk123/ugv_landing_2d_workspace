classdef TerminationBlock < landing2d.simulink.BlockBase
    % TERMINATIONBLOCK  접촉·안전 범위·중단·시간 초과 판정 (evaluateTermination).
    %
    % environment.step처럼 한 물리 스텝에서 두 번 쓰입니다. 첫 판정은 직전
    % 결정 문맥으로 접촉을 보고, 측정 갱신 뒤 두 번째 판정은 갱신된 문맥으로
    % 봅니다. priorEvent가 이미 발생했으면 판정하지 않습니다.
    methods (Access = protected)
        function names = inputPorts(~)
            names = {'drone','droneNext','pad','padNext','status','timing', ...
                'hardViolation','priorEvent'};
        end
        function ports = outputPorts(obj)
            ports = {'event',obj.width('event')};
        end
        function event = stepImpl(obj,drone,droneNext,pad,padNext,status, ...
                timing,hardViolation,priorEvent)
            if timing(4) == 0 || priorEvent(1) ~= 0
                event = obj.encode('event',noEvent(timing(1)+timing(2)));
                return;
            end
            env = obj.currentEpisode().env;
            e = landing2d.environment.evaluateTermination( ...
                obj.decode('drone',drone),obj.decode('drone',droneNext), ...
                obj.decode('pad',pad),obj.decode('pad',padNext), ...
                obj.decode('status',status),timing(1),timing(2),env.config, ...
                struct('hardEnvelopeViolation',hardViolation ~= 0));
            event = obj.encode('event',e);
        end
    end
end

function event = noEvent(t)
event = struct('occurred',false,'reason','','time',t,'alpha',1, ...
    'physicalContact',false,'authorized',false,'mechanicallySafe',false, ...
    'preImpact',struct());
end
