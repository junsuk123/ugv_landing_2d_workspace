function x = toVector(O,G)
% TOVECTOR Convert the registered sensor estimate to the minimal 12-D input.
s = G.normalization;
u = O.ugv; d = O.drone;
ex = u.positionXZ(1)-d.positionXZ(1);
h = d.positionXZ(2)-(u.positionXZ(2)+G.ugv.padOffset(2));
rvx = u.velocityXZ(1)-d.velocityXZ(1);
x = [signedScale(ex,s.relativePosition);signedScale(h,s.height); ...
    signedScale(rvx,s.vx);signedScale(u.velocityXZ(1),s.vx); ...
    signedScale(d.velocityXZ(2),s.vz);d.pitchSinCos(:); ...
    signedScale(d.pitchRate,s.pitchRate);double(u.visionUpdated); ...
    ageScale(u.visionAge,s.age);double(d.navigationValid); ...
    ageScale(d.navigationAge,s.age)];
if ~u.estimateInitialized
    x(1:4) = 0;
end
assert(numel(x) == landing2d.observation.vectorSchema(G).dimension && all(isfinite(x)), ...
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
