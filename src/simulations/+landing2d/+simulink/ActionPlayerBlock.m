classdef ActionPlayerBlock < landing2d.simulink.BlockBase
    % ACTIONPLAYERBLOCK  기록된 정책 명령 u(2 x 결정 수)를 결정마다 재생.
    % 환경 블록 등가성 검증 전용입니다. 명령은 에피소드 spec.actions에서 읽습니다.
    properties (Access = private)
        Index = 0
    end

    methods (Access = protected)
        function names = inputPorts(~)
            names = {};
        end
        function ports = outputPorts(~)
            ports = {'u',2};
        end
        function resetImpl(obj)
            obj.Index = 0;
        end
        function s = saveObjectImpl(obj)
            s = saveObjectImpl@landing2d.simulink.BlockBase(obj);
            if isLocked(obj), s.Index = obj.Index; end
        end
        function loadObjectImpl(obj,s,wasLocked)
            if wasLocked, obj.Index = s.Index; end
            loadObjectImpl@landing2d.simulink.BlockBase(obj,s,wasLocked);
        end
        function u = stepImpl(obj)
            actions = obj.currentEpisode().spec.actions;
            obj.Index = obj.Index+1;
            u = actions(:,min(obj.Index,size(actions,2)));
        end
    end
end
