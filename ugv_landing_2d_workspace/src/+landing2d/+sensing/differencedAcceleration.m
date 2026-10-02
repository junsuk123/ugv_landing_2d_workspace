function a = differencedAcceleration(vOld,vNew,tOld,tNew)
% DIFFERENCEDACCELERATION  Use measurement timestamps, never policy period.
dt = tNew-tOld;
assert(isfinite(dt) && dt > 0,'landing2d:MeasurementTimeOrder', ...
    'New measurement timestamp must be later than the previous timestamp.');
a = (vNew-vOld)/dt;
end
