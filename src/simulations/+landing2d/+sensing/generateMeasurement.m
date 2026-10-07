function m = generateMeasurement(state,pad,t,sensor,rs,event)
% GENERATEMEASUREMENT  Noisy metric detector output with explicit validity.
% 3D projections add relativeY/bearingY; confidence uses the off-axis angle.
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
    m.relativeX = p.ex+sensor.relativePositionNoiseStd*randn(rs);
    if spatial
        m.relativeY = p.ey+sensor.relativePositionNoiseStd*randn(rs);
    end
    m.bearing = p.bearing+sensor.bearingNoiseStd*randn(rs);
    if spatial
        m.bearingY = p.bearingY+sensor.bearingNoiseStd*randn(rs);
        normalized = hypot(m.bearing,m.bearingY)/(sensor.fov/2);
    else
        normalized = abs(m.bearing)/(sensor.fov/2);
    end
    m.confidence = max(sensor.confidenceFloor,1-min(1,normalized^2));
end
end
