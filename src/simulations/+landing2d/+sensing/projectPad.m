function projection = projectPad(state,pad,sensor)
% PROJECTPAD  Body-fixed downward camera projection in the world x-z plane.
% A 3D state/pad (field y) uses the conical-FOV spatial projection below.
if isfield(state,'y') && isfield(pad,'y')
    projection = projectSpatial(state,pad,sensor);
    return;
end
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

function projection = projectSpatial(state,pad,sensor)
% Camera axis is the negative thrust axis n(theta,roll); image axes are the
% body forward axis (bearing, same sign as the planar bearing) and the body
% side axis (bearingY). The FOV is a cone: off-axis angle < fov/2. With
% ey = 0 and roll = 0 every quantity equals the planar projection.
ex = pad.x-state.x;
ey = pad.y-state.y;
h = state.z-pad.z;
thetaCamera = state.theta+sensor.cameraPitchOffset;
roll = state.roll;
d = [ex;ey;-h];
bCamera = -[cos(roll)*sin(thetaCamera);sin(roll);cos(roll)*cos(thetaCamera)];
bForward = [cos(thetaCamera);0;-sin(thetaCamera)];
bSide = [-sin(roll)*sin(thetaCamera);cos(roll);-sin(roll)*cos(thetaCamera)];
depth = dot(d,bCamera);
lateral = dot(d,bForward);
lateralY = dot(d,bSide);
range = norm([ex,ey,h]);
if depth > 0 && range > eps
    beta = atan2(lateral,depth);
    betaY = atan2(lateralY,depth);
    offAxis = atan2(hypot(lateral,lateralY),depth);
else
    beta = NaN; betaY = NaN; offAxis = NaN;
end
visible = depth > 0 && range <= sensor.maxRange && isfinite(offAxis) ...
    && offAxis < sensor.fov/2;
projection = struct('ex',ex,'ey',ey,'h',h,'depth',depth,'lateral',lateral, ...
    'lateralY',lateralY,'range',range,'bearing',beta,'bearingY',betaY, ...
    'offAxis',offAxis,'visible',visible,'fovMargin',sensor.fov/2-offAxis);
end
