function [value,detail] = captureSignal(s,obs,xp,rl)
% CAPTURESIGNAL  Bounded capture reward with gradient outside the camera FOV.
%
% For q = |x_pad-x_drone|/FOV_half, margin mode is continuous and strictly
% decreasing in q. It is +1 at the optical axis, equals the configured
% boundary value at q=1, and approaches -1 without clipping outside FOV.
if s.mode == 3
    value = 1;
    detail = struct('normalizedError',0,'region','landed');
    return;
end
if strcmp(rl.captureMode,'binary')
    value = 2*double(obs.visible)-1;
    detail = struct('normalizedError',NaN,'region','binary');
    return;
end

q = abs(xp-s.x)/max(obs.halfWidth,1e-6);
b = rl.captureBoundaryValue;
if q <= 1
    value = 1-(1-b)*q;
    region = 'inside';
else
    outside = q-1;
    value = b-(1+b)*outside/(outside+rl.captureOutsideScale);
    region = 'outside';
end
value = min(max(value,-1),1);
detail = struct('normalizedError',q,'region',region);
end
