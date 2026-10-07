classdef DecisionContextBlock < landing2d.simulink.BlockBase
    % DECISIONCONTEXTBLOCK  하강 금지·중단 요청 문맥 (updateDecisionContext).
    methods (Access = protected)
        function names = inputPorts(~)
            names = {'status','trackNext','timing','event'};
        end
        function ports = outputPorts(obj)
            ports = {'statusNext',obj.width('status')};
        end
        function statusNext = stepImpl(obj,status,trackNext,timing,event)
            statusNext = status(:);
            if timing(4) == 0 || event(1) ~= 0, return; end
            env = obj.currentEpisode().env;
            s = landing2d.environment.updateDecisionContext( ...
                obj.decode('status',status),obj.decode('track',trackNext), ...
                timing(3),env.config);
            statusNext = obj.encode('status',s);
        end
    end
end
