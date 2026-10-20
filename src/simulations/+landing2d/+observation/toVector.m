function observationVector = toVector(O,G)
% TOVECTOR Convert the registered sensor estimate to the minimal 10-D input
% (landing2d.observation.vectorSchema; the constant navigation validity/age
% entries are not part of it since relational-policy-v2.3).
% ex, h [m] and relativeVx [m/s] are physical values before the bounded
% normalization x/(|x|+s) with the scales of Gamma (G.normalization).
scales = G.normalization;
ugv = O.ugv; drone = O.drone;
ex = ugv.positionXZ(1)-drone.positionXZ(1);
h = drone.positionXZ(2)-(ugv.positionXZ(2)+G.ugv.padOffset(2));
relativeVx = ugv.velocityXZ(1)-drone.velocityXZ(1);
observationVector = [signedScale(ex,scales.relativePosition);signedScale(h,scales.height); ...
    signedScale(relativeVx,scales.vx);signedScale(ugv.velocityXZ(1),scales.vx); ...
    signedScale(drone.velocityXZ(2),scales.vz);drone.pitchSinCos(:); ...
    signedScale(drone.pitchRate,scales.pitchRate);double(ugv.visionUpdated); ...
    ageScale(ugv.visionAge,scales.age)];
if ~ugv.estimateInitialized
    observationVector(1:4) = 0;
end
assert(numel(observationVector) == landing2d.observation.vectorSchema(G).dimension ...
    && all(isfinite(observationVector)), ...
    'landing2d:CommonObservation','Common observation vector is malformed.');
end

function y = signedScale(x,scale)
y = x/(abs(x)+max(scale,eps));
end

function y = ageScale(age,scale)
if ~isfinite(age)
    y = 1;
else
    y = max(age,0)/(max(age,0)+max(scale,eps));
end
end
