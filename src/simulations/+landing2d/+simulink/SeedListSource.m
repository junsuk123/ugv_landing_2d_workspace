classdef SeedListSource < handle
    % SEEDLISTSOURCE  고정 seed 목록을 차례로 내주는 평가용 에피소드 공급원.
    %
    % 평가는 커리큘럼 없는 공칭 설정을 쓰고, 결과는 Outcomes에 쌓입니다.
    % actions(2 x 결정 수, 선택)는 Action player 모델이 그대로 재생합니다.
    % resetOptions(선택)는 seed별 environment.reset 옵션으로, 대표 시나리오의
    % 고정 scenario·sensorEvents를 지정할 때 씁니다.
    properties
        Config
        Seeds
        Actions = {}
        ResetOptions = {}
        Index = 0
        Outcomes = {}
    end
    methods
        function obj = SeedListSource(config,seeds,actions,resetOptions)
            obj.Config = config;
            obj.Seeds = seeds(:)';
            if nargin >= 3 && ~isempty(actions), obj.Actions = actions; end
            if nargin >= 4 && ~isempty(resetOptions), obj.ResetOptions = resetOptions; end
        end
        function spec = next(obj)
            obj.Index = obj.Index+1;
            assert(obj.Index <= numel(obj.Seeds),'landing2d:SeedListSource', ...
                'Seed list exhausted after %d episodes.',numel(obj.Seeds));
            spec = struct('config',obj.Config,'seed',obj.Seeds(obj.Index), ...
                'resetOptions',struct(),'actions',[]);
            if ~isempty(obj.Actions)
                spec.actions = obj.Actions{obj.Index};
            end
            if ~isempty(obj.ResetOptions)
                spec.resetOptions = obj.ResetOptions{obj.Index};
            end
        end
        function record(obj,outcome)
            obj.Outcomes{end+1} = outcome;
        end
    end
end
