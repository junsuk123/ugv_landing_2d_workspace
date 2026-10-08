classdef PacketBuilderBlock < landing2d.simulink.BlockBase
    % PACKETBUILDERBLOCK  물리 스텝마다 안전 감독기가 보는 causal packet 생성.
    % 출력은 정규화 이전 packet으로 observationSchema 순서를 따릅니다.
    % 평면 공통 관측 계약에서는 environment.step과 같이 감독기가 결정 시점 UGV
    % 추정(landing2d.environment.perceptionView)을 보므로, 감독기가 읽는 항목
    % (h, 착륙 금지·복구 요청, 추정 초기화, 상대 위치·속도 추정)을 그 값으로 바꿉니다.
    methods (Access = protected)
        function names = inputPorts(~)
            names = {'drone','track','measurement','status','clock','perception'};
        end
        function ports = outputPorts(obj)
            ports = {'packet',obj.width('packet')};
        end
        function packet = stepImpl(obj,drone,track,measurement,status,clock,perception)
            env = obj.currentEpisode().env;
            droneState = obj.decode('drone',drone);
            statusState = obj.decode('status',status);
            p = landing2d.sensing.buildPacket(droneState, ...
                obj.decode('track',track),obj.decode('measurement',measurement), ...
                statusState,env.scenario,clock(1),env.config);
            if ~isempty(env.commonMemory)
                q = obj.perceptionOf(perception);
                view = landing2d.environment.perceptionView(q.O,droneState, ...
                    statusState,clock(1),env.scenario,env.config);
                for name = {'h','abortRequested','landingInhibited', ...
                        'trackInitialized','exEstimate','relativeVxEstimate'}
                    p.(name{1}) = view.(name{1});
                end
            end
            packet = obj.encode('packet',p);
        end
    end
end
