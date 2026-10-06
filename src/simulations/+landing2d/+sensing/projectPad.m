function projection = projectPad(state,pad,sensor)
% PROJECTPAD  Body-fixed downward camera projection in the world x-z plane.
ex = pad.x-state.x;
h = state.z-pad.z;
thetaCamera = state.theta+sensor.cameraPitchOffset;
d = [ex;-h];
bCamera = [-sin(thetaCamera);-cos(thetaCamera)];
bRight = [cos(thetaCamera);-sin(thetaCamera)];
depth = dot(d,bCamera);
lateral = dot(d,bRight);
range = hypot(ex,h);
if depth > 0 && range > eps
    beta = atan2(lateral,depth);
else
    beta = NaN;
end
visible = depth > 0 && range <= sensor.maxRange && isfinite(beta) ...
    && abs(beta) < sensor.fov/2;
projection = struct('ex',ex,'h',h,'depth',depth,'lateral',lateral, ...
    'range',range,'bearing',beta,'visible',visible, ...
    'fovMargin',sensor.fov/2-abs(beta));
end
