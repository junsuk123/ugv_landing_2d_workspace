function [value,components] = distanceSignal(distance,previous,dtAction,rl,terminalMode)
% DISTANCESIGNAL  Approach reward from consecutive decision-time distances.
%
%   rate = clip((d_(t-1)-d_t)/(dt*v_scale),-1,1)
%
% PREVIOUS is the distance at which the pending action started.  Keeping
% this calculation side-effect free makes the transition convention easy
% to test and prevents a zero-initialized pseudo-history from being used.
validateattributes(distance,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(previous,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(dtAction,{'numeric'},{'scalar','real','finite','positive'});
if nargin < 5
    terminalMode = 0;
end

% Distance zero alone must not reward an unsafe ground impact. Terminal
% outcome remains part of the distance term rather than becoming a third
% reward term: safe landing=+1, failed contact=-1.
if terminalMode == 3
    value = 1;
    components = struct('rate',NaN,'proximity',1,'terminal','landed');
    return;
elseif terminalMode == 4
    value = -1;
    components = struct('rate',NaN,'proximity',-1,'terminal','failed');
    return;
end

rate = landing2d.util.saturate( ...
    (previous-distance)/(dtAction*rl.distanceRateScale),1);
proximity = landing2d.util.saturate( ...
    1-(distance/rl.distanceScale)^rl.distanceExponent,1);
switch rl.distanceMode
    case 'hybrid'
        share = rl.distanceRateShare;
        value = share*rate+(1-share)*proximity;
    case 'rate'
        value = rate;
    case 'proximity'
        value = proximity;
    otherwise
        error('landing2d:UnknownDistanceMode', ...
            'Unknown distanceMode: %s',rl.distanceMode);
end
components = struct('rate',rate,'proximity',proximity,'terminal','ongoing');
end
