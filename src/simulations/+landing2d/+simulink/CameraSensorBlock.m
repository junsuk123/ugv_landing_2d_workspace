classdef CameraSensorBlock < landing2d.simulink.BlockBase
    % CAMERASENSORBLOCK  하향 카메라 검출: 투영, 시야각, dropout, 측정 잡음.
    %
    % landing2d.sensing.generateMeasurement를 호출합니다. 잡음은 reset이 만든
    % threefry RandStream을 이어 쓰므로 MATLAB 환경과 같은 표본 순서를 갖습니다.
    % 같은 스텝에 종료 사건이 났으면 측정하지 않고 난수도 소비하지 않습니다.
    properties (Access = private)
        Stream
    end

    methods (Access = protected)
        function names = inputPorts(~)
            names = {'measurement','droneNext','padNext','timing','event'};
        end
        function ports = outputPorts(obj)
            ports = {'measurementNext',obj.width('measurement')};
        end
        function resetImpl(obj)
            obj.Stream = obj.currentEpisode().env.sensorStream;
        end
        function s = saveObjectImpl(obj)
            % 난수 흐름은 매 에피소드 resetImpl에서 다시 받으므로 저장하지 않습니다.
            s = saveObjectImpl@landing2d.simulink.BlockBase(obj);
        end
        function loadObjectImpl(obj,s,wasLocked)
            loadObjectImpl@landing2d.simulink.BlockBase(obj,s,wasLocked);
        end
        function measurementNext = stepImpl(obj,measurement,droneNext,padNext, ...
                timing,event)
            measurementNext = measurement(:);
            if timing(4) == 0 || event(1) ~= 0, return; end
            env = obj.currentEpisode().env;
            events = env.sensorEvents;
            nextTime = timing(3);
            sensorEvent = struct('dropout',nextTime >= events.dropoutStart ...
                && nextTime < events.dropoutEnd);
            m = landing2d.sensing.generateMeasurement(obj.decode('drone',droneNext), ...
                obj.decode('pad',padNext),nextTime,env.config.experiment.sensor, ...
                obj.Stream,sensorEvent);
            measurementNext = obj.encode('measurement',m);
        end
    end
end
