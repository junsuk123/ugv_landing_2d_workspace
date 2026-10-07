classdef PacketBuilderBlock < landing2d.simulink.BlockBase
    % PACKETBUILDERBLOCK  물리 스텝마다 안전 감독기가 보는 causal packet 생성.
    % 출력은 정규화 이전 packet으로 observationSchema 순서를 따릅니다.
    methods (Access = protected)
        function names = inputPorts(~)
            names = {'drone','track','measurement','status','clock'};
        end
        function ports = outputPorts(obj)
            ports = {'packet',obj.width('packet')};
        end
        function packet = stepImpl(obj,drone,track,measurement,status,clock)
            env = obj.currentEpisode().env;
            p = landing2d.sensing.buildPacket(obj.decode('drone',drone), ...
                obj.decode('track',track),obj.decode('measurement',measurement), ...
                obj.decode('status',status),env.scenario,clock(1),env.config);
            packet = obj.encode('packet',p);
        end
    end
end
