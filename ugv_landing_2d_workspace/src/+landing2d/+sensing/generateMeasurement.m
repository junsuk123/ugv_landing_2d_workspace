function m = generateMeasurement(state,pad,t,sensor,rs,event)
% GENERATEMEASUREMENT  Noisy metric detector output with explicit validity.
if nargin < 6 || isempty(event), event = struct('dropout',false); end
p = landing2d.sensing.projectPad(state,pad,sensor);
dropout = isfield(event,'dropout') && event.dropout;
detected = p.visible && ~dropout;
m = struct('timestamp',t,'detected',detected,'valid',detected, ...
    'bearingValid',detected,'relativeX',0,'bearing',0,'confidence',0, ...
    'projection',p);
if detected
    m.relativeX = p.ex+sensor.relativePositionNoiseStd*randn(rs);
    m.bearing = p.bearing+sensor.bearingNoiseStd*randn(rs);
    normalized = abs(m.bearing)/(sensor.fov/2);
    m.confidence = max(sensor.confidenceFloor,1-min(1,normalized^2));
end
end
