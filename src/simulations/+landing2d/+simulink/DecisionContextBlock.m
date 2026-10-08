classdef DecisionContextBlock < landing2d.simulink.BlockBase
    % DECISIONCONTEXTBLOCK  하강 금지·중단 요청 문맥 (updateDecisionContext).
    % tracker 기반 설정에서는 물리 스텝마다 갱신합니다. 평면 공통 관측 계약에서는
    % environment.step과 같이 결정 구간 끝에서만 갱신하므로(PerceptionUpdateBlock)
    % 그대로 통과시킵니다.
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
            if ~isempty(env.commonMemory), return; end
            s = landing2d.environment.updateDecisionContext( ...
                obj.decode('status',status),obj.decode('track',trackNext), ...
                timing(3),env.config);
            statusNext = obj.encode('status',s);
        end
    end
end
