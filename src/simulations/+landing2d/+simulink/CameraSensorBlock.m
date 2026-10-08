classdef CameraSensorBlock < landing2d.simulink.BlockBase
    % CAMERASENSORBLOCK  tracker 카메라 검출: 투영, 시야각, dropout, 측정 잡음.
    %
    % landing2d.sensing.generateMeasurement를 호출합니다. 평면 공통 관측 계약의
    % 잡음은 reset이 만든 시간 기준 잡음표에서 결정 번호 k(clock(3))와 결정 구간 안의
    % 물리 스텝 j(경과 시간 / physicsDt + 1)로 읽습니다(environment.step과 같은 색인).
    % 그 밖의 설정은 reset이 만든 threefry RandStream을 이어 써서 MATLAB 환경과 같은
    % 표본 순서를 갖습니다. 같은 스텝에 종료 사건이 났으면 측정하지 않습니다.
    properties (Access = private)
        Stream
    end

    methods (Access = protected)
        function names = inputPorts(~)
            names = {'measurement','droneNext','padNext','timing','event','clock'};
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
                timing,event,clock)
            measurementNext = measurement(:);
            if timing(4) == 0 || event(1) ~= 0, return; end
            env = obj.currentEpisode().env;
            events = env.sensorEvents;
            nextTime = timing(3);
            sensorEvent = struct('dropout',nextTime >= events.dropoutStart ...
                && nextTime < events.dropoutEnd);
            noise = obj.Stream;
            if ~isempty(env.noise)
                substep = round(clock(2)/env.config.experiment.physicsDt)+1;
                noise = env.noise.tracker(:,substep,clock(3)+1);
            end
            m = landing2d.sensing.generateMeasurement(obj.decode('drone',droneNext), ...
                obj.decode('pad',padNext),nextTime,env.config.experiment.sensor, ...
                noise,sensorEvent);
            measurementNext = obj.encode('measurement',m);
        end
    end
end
