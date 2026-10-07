classdef DescentGateLayer < nnet.layer.Layer
    % DESCENTGATELAYER  관계 residual의 추가 하강 성분만 DescentEligibility로 축소.
    % landing2d.rl.relationPolicyResidual과 같은 gate입니다. 수직 residual이
    % 음수(추가 하강)일 때만 g = clip(DescentEligibility 주 채널, 0, 1)을 곱하고,
    % 수평과 상승·제동 성분은 그대로 통과시킵니다.
    properties
        GateIndex   % s_t에서 DescentEligibility 주 크기 채널의 위치
    end

    methods
        function layer = DescentGateLayer(gateIndex,name)
            layer.Name = name;
            layer.Description = 'Descent-eligibility gate on relation residual';
            layer.NumInputs = 2;
            layer.InputNames = {'residual','state'};
            layer.GateIndex = gateIndex;
        end

        function Z = predict(layer,residual,X)
            g = min(max(X(layer.GateIndex,:),0),1);
            vertical = residual(2,:);
            value = vertical;
            if isa(value,'dlarray'), value = extractdata(value); end
            descending = double(value < 0);
            factor = 1+descending.*(g-1);
            Z = [residual(1,:);vertical.*factor];
        end
    end
end
