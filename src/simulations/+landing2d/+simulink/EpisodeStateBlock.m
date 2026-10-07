classdef EpisodeStateBlock < landing2d.simulink.BlockBase
    % EPISODESTATEBLOCK  물리 스텝 사이에 확정된 환경 상태를 보관하는 메모리.
    %
    % 출력은 직전 물리 스텝에서 확정된 값입니다(직접 통과 없음). 초기값은
    % 매 에피소드 landing2d.environment.reset 결과에서 가져옵니다.
    %   clock = [환경 시각; 현재 결정 경과 시간; 결정 번호; 직전 결정 행동(2)]
    %   snapshot = [결정 시작 시점 드론(7); 결정 시작 시점 패드(5)]
    properties (Access = private)
        State
    end

    methods (Access = protected)
        function names = inputPorts(~)
            names = {'droneNext','padNext','measurementNext','trackNext', ...
                'statusNext','clockNext','snapshotNext'};
        end
        function ports = outputPorts(obj)
            ports = {'drone',obj.width('drone');'pad',obj.width('pad'); ...
                'measurement',obj.width('measurement'); ...
                'track',obj.width('track');'status',obj.width('status'); ...
                'clock',obj.width('clock');'snapshot',obj.width('snapshot')};
        end
        function resetImpl(obj)
            env = obj.currentEpisode().env;
            drone = obj.encode('drone',env.physicalState);
            pad = obj.encode('pad',env.pad);
            obj.State = {drone,pad,obj.encode('measurement',env.measurement), ...
                obj.encode('track',env.observationMemory), ...
                obj.encode('status',env.episodeStatus), ...
                [env.time;0;0;env.episodeStatus.previousNormalizedAction(:)], ...
                [drone;pad]};
        end
        function varargout = outputImpl(obj,varargin)
            varargout = obj.State;
        end
        function updateImpl(obj,varargin)
            obj.State = cellfun(@(x)double(x(:)),varargin,'UniformOutput',false);
        end
        function varargout = isInputDirectFeedthroughImpl(~,varargin)
            varargout = repmat({false},1,numel(varargin));
        end
        function s = saveObjectImpl(obj)
            s = saveObjectImpl@landing2d.simulink.BlockBase(obj);
            if isLocked(obj), s.State = obj.State; end
        end
        function loadObjectImpl(obj,s,wasLocked)
            if wasLocked, obj.State = s.State; end
            loadObjectImpl@landing2d.simulink.BlockBase(obj,s,wasLocked);
        end
    end
end
