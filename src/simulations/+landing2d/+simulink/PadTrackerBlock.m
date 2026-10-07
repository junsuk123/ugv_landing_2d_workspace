classdef PadTrackerBlock < landing2d.simulink.BlockBase
    % PADTRACKERBLOCK  인과 등가속도 패드 추정기 (landing2d.sensing.updatePadTrack).
    methods (Access = protected)
        function names = inputPorts(~)
            names = {'track','measurementNext','droneNext','timing','event'};
        end
        function ports = outputPorts(obj)
            ports = {'trackNext',obj.width('track')};
        end
        function trackNext = stepImpl(obj,track,measurementNext,droneNext, ...
                timing,event)
            trackNext = track(:);
            if timing(4) == 0 || event(1) ~= 0, return; end
            env = obj.currentEpisode().env;
            t = landing2d.sensing.updatePadTrack(obj.decode('track',track), ...
                obj.decode('measurement',measurementNext), ...
                obj.decode('drone',droneNext),timing(3), ...
                env.config.experiment.sensor);
            trackNext = obj.encode('track',t);
        end
    end
end
