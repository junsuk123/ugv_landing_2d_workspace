function m = generateMeasurement(state,pad,t,sensor,rs,event)
% GENERATEMEASUREMENT  Noisy metric detector output with explicit validity.
% 3D projections add relativeY/bearingY; confidence uses the off-axis angle.
% RS is a RandStream (drawn only on detection, in the order relativeX,
% relativeY, bearing, bearingY; 3D option) or a numeric vector of standard
% normals indexed by time ([relativeX; bearing], planar contract,
% landing2d.sensing.exogenousNoise) whose values do not depend on detection.
if nargin < 6 || isempty(event), event = struct('dropout',false); end
p = landing2d.sensing.projectPad(state,pad,sensor);
spatial = isfield(p,'ey');
dropout = isfield(event,'dropout') && event.dropout;
detected = p.visible && ~dropout;
m = struct('timestamp',t,'detected',detected,'valid',detected, ...
    'bearingValid',detected,'relativeX',0,'bearing',0,'confidence',0, ...
    'projection',p);
if spatial
    m.relativeY = 0;
    m.bearingY = 0;
end
if detected
    m.relativeX = p.ex+sensor.relativePositionNoiseStd*standardNormal(rs,1);
    if spatial
        m.relativeY = p.ey+sensor.relativePositionNoiseStd*standardNormal(rs,2);
    end
    m.bearing = p.bearing+sensor.bearingNoiseStd*standardNormal(rs,2+spatial);
    if spatial
        m.bearingY = p.bearingY+sensor.bearingNoiseStd*standardNormal(rs,4);
        normalized = hypot(m.bearing,m.bearingY)/(sensor.fov/2);
    else
        normalized = abs(m.bearing)/(sensor.fov/2);
    end
    m.confidence = max(sensor.confidenceFloor,1-min(1,normalized^2));
end
end

function z = standardNormal(rs,index)
if isnumeric(rs)
    z = rs(index);
else
    z = randn(rs);
end
end
