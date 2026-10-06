function [residual,slope,detail] = relationPolicyResidual(W,spec,raw,context)
% RELATIONPOLICYRESIDUAL  Typed graph correction with a semantic descent gate.
% Horizontal recovery and vertical landing corrections are separate output
% channels. A negative vertical correction means additional descent and is
% therefore admitted only in proportion to the causal DescentEligibility
% node. Positive braking/climb corrections are never suppressed.
linear = W*context;
residual = linear;
slope = ones(size(linear));
eligibility = ones(1,size(linear,2));
if size(linear,1)>=2 && isfield(spec,'descentEligibilityIndex') ...
        && ~isempty(spec.descentEligibilityIndex)
    eligibility = min(max(raw(spec.descentEligibilityIndex,:),0),1);
    descending = linear(2,:)<0;
    residual(2,descending) = eligibility(descending).*linear(2,descending);
    slope(2,descending) = eligibility(descending);
end
detail = struct('linear',linear,'slope',slope, ...
    'descentEligibility',eligibility,'verticalGateActive', ...
    size(linear,1)>=2 & linear(2,:)<0 & eligibility<1);
end
