function measurement = generateMeasurement(state,pad,t,sensor,rs,event)
% GENERATEMEASUREMENT  Noisy metric detector output with explicit validity.
% RS is a RandStream (drawn only on detection) or a numeric vector of standard
% normals indexed by time ([relativeX; bearing], planar contract,
% landing2d.sensing.exogenousNoise) whose values do not depend on detection.
if nargin < 6 || isempty(event), event = struct('dropout',false); end
projection = landing2d.sensing.projectPad(state,pad,sensor);
dropout = isfield(event,'dropout') && event.dropout;
detected = projection.visible && ~dropout;
measurement = struct('timestamp',t,'detected',detected,'valid',detected, ...
    'bearingValid',detected,'relativeX',0,'bearing',0,'confidence',0, ...
    'projection',projection);
if detected
    measurement.relativeX = projection.ex+sensor.relativePositionNoiseStd*standardNormal(rs,1);
    measurement.bearing = projection.bearing+sensor.bearingNoiseStd*standardNormal(rs,2);
    % confidence: simulated detector score from the off-axis angle (not a
    % calibrated reliability or a measurement covariance).
    normalized = abs(measurement.bearing)/(sensor.fov/2);
    measurement.confidence = max(sensor.confidenceFloor,1-min(1,normalized^2));
end
end

function z = standardNormal(rs,index)
if isnumeric(rs)
    z = rs(index);
else
    z = randn(rs);
end
end
