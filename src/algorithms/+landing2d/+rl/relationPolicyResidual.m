function [residual,slope,detail] = relationPolicyResidual(W,spec,raw,context)
% RELATIONPOLICYRESIDUAL  Typed graph correction with a semantic descent gate.
% Horizontal recovery and vertical landing corrections are separate output
% channels. A negative vertical correction means additional descent and is
% therefore admitted only in proportion to the causal DescentEligibility
% node. Positive braking/climb corrections are never suppressed.
% The vertical channel is the last action row ([a_x,a_z] or [a_x,a_y,a_z]).
scale=1;
if isfield(spec,'relationResidualScale')
    scale=spec.relationResidualScale;
end
linear = scale*(W*context);
v = size(linear,1);
residual = linear;
slope = ones(size(linear));
eligibility = ones(1,size(linear,2));
if ~strcmp(spec.readout,'observation_plus_groups') ...
        && size(linear,1)>=2 && isfield(spec,'descentEligibilityIndex') ...
        && ~isempty(spec.descentEligibilityIndex)
    eligibility = min(max(raw(spec.descentEligibilityIndex,:),0),1);
    descending = linear(v,:)<0;
    residual(v,descending) = eligibility(descending).*linear(v,descending);
    slope(v,descending) = eligibility(descending);
end
detail = struct('linear',linear,'slope',slope, ...
    'descentEligibility',eligibility,'verticalGateActive', ...
    v>=2 & linear(v,:)<0 & eligibility<1);
end
