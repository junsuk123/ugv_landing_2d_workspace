classdef PerceptionUpdateBlock < landing2d.simulink.BlockBase
    % PERCEPTIONUPDATEBLOCK  결정 구간 끝의 마커 카메라 영상·융합 측위·공통 관측 갱신 (평면).
    %
    % environment.step의 물리 루프 뒤 부분과 같은 일을 합니다. 확정된 물리 스텝이
    % 결정 구간을 끝냈으면(경과 시간 >= policyDt 또는 이번 스텝의 종료 사건):
    %   landing2d.sensing.detectMarkers / navigationEstimate (결정 시점 k의 시간 기준
    %   잡음표 열 k+1) -> landing2d.observation.capture -> 종료 사건이 없으면
    %   landing2d.environment.perceptionView + updateDecisionContext.
    % 종료 사건 시점에는 새 영상이 없습니다(frameCaptured = false). 공통 관측이
    % 없는 설정에서는 status와 perception을 그대로 통과시킵니다.
    methods (Access = protected)
        function names = inputPorts(~)
            names = {'droneCommit','padCommit','clockCommit','statusCommit', ...
                'perception','timing'};
        end
        function ports = outputPorts(obj)
            ports = {'perceptionNext',obj.width('perception'); ...
                'statusNext',obj.width('status')};
        end
        function [perceptionNext,statusNext] = stepImpl(obj,drone,pad,clock, ...
                status,perception,timing)
            perceptionNext = perception(:);
            statusNext = status(:);
            if timing(4) == 0, return; end
            env = obj.currentEpisode().env;
            if isempty(env.commonMemory), return; end
            c = env.config; e = c.experiment;
            s = obj.decode('status',status);
            eventOccurred = s.terminated;   % active step: not terminated before it
            if ~eventOccurred && clock(2) < e.policyDt-1e-12, return; end
            t = clock(1);
            k = clock(3);
            state = obj.decode('drone',drone);
            padState = obj.decode('pad',pad);
            p = obj.perceptionOf(perception);
            frame = struct('dropout',t >= env.sensorEvents.dropoutStart ...
                && t < env.sensorEvents.dropoutEnd,'frameCaptured',~eventOccurred);
            detections = landing2d.sensing.detectMarkers(state,padState,t,e.sensor, ...
                e.commonObservation,env.noise.marker(:,:,:,k+1),frame);
            navigation = landing2d.sensing.navigationEstimate(state,t, ...
                e.commonObservation.navigation,env.noise.navigation(:,k+1));
            [O,memory] = landing2d.observation.capture(p.memory,detections, ...
                navigation,t,env.observationContext);
            if ~eventOccurred
                [~,track] = landing2d.environment.perceptionView(O,state,s,t, ...
                    env.scenario,c);
                s = landing2d.environment.updateDecisionContext(s,track,t,c,state);
            end
            perceptionNext = obj.perceptionVector(O,memory);
            statusNext = obj.encode('status',s);
        end
    end
end
