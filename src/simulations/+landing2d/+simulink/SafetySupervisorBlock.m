classdef SafetySupervisorBlock < landing2d.simulink.BlockBase
    % SAFETYSUPERVISORBLOCK  세 비교군 공통 안전 감독기 (landing2d.control.safetySupervisor).
    methods (Access = protected)
        function names = inputPorts(~)
            names = {'aRequest','drone','packet'};
        end
        function ports = outputPorts(~)
            ports = {'aApplied',2;'intervened',1};
        end
        function [applied,intervened] = stepImpl(obj,aRequest,drone,packet)
            env = obj.currentEpisode().env;
            if isfield(env.config.experiment,'actionApplication') ...
                    && strcmp(env.config.experiment.actionApplication,'direct_policy_v1')
                applied = aRequest(:);
                intervened = 0;
            else
                [applied,info] = landing2d.control.safetySupervisor(aRequest(:), ...
                    obj.decode('drone',drone),obj.decode('packet',packet),env.config);
                intervened = double(info.intervened);
            end
        end
    end
end
