function x = normalizePacket(packet,c)
% NORMALIZEPACKET  Signed, finite normalization shared by all policy branches.
e = c.experiment;
s = e.sensor;
q = packet;
q.h = signedScale(q.h,8);
q.vx = signedScale(q.vx,c.vxMax);
q.vz = signedScale(q.vz,c.vzMax);
q.pitchRate = signedScale(q.pitchRate,e.dynamics.pitchRateLimit);
q.exEstimate = signedScale(q.exEstimate,3);
q.relativeVxEstimate = signedScale(q.relativeVxEstimate,3);
q.padVxEstimate = signedScale(q.padVxEstimate,10);
q.padAxEstimate = signedScale(q.padAxEstimate,2);
q.positionStd = unitScale(q.positionStd,5);
q.velocityStd = unitScale(q.velocityStd,5);
q.accelerationStd = unitScale(q.accelerationStd,3);
q.measuredBearing = signedScale(q.measuredBearing,s.fov/2);
q.timeSinceLastDetection = unitScale(q.timeSinceLastDetection, ...
    e.safety.prolongedLoss);
q.predictedBearing = signedScale(q.predictedBearing,s.fov/2);
q.predictedFovMargin = signedScale(q.predictedFovMargin,s.fov/2);
q.remainingMissionTime = min(max(q.remainingMissionTime/e.maxMissionTime,0),1);
x = landing2d.sensing.packetVector(q,e.observationSchema);
end

function y = signedScale(x,scale)
y = x/(abs(x)+max(scale,eps));
end

function y = unitScale(x,scale)
y = min(max(x,0)/(max(x,0)+max(scale,eps)),1);
end
