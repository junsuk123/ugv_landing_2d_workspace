function [S,detail] = contextGraph(packet,c)
% CONTEXTGRAPH  Feature-rich causal graph; query nodes contain no labels.
% 3D option: magnitude channels use horizontal error/speed norms and the
% larger of pitch/roll; two lateral channels carry the signed y evidence.
mode = c.graphState.stateRepresentation;
dimension = landing2d.graphstate.graphDimension(c.graphState);
[schema,~] = landing2d.graphstate.contextSchema(mode,dimension);
landing2d.graphstate.assertCausalPacket(packet);
spatial = dimension == 3;
assert(spatial == isfield(packet,'eyEstimate'),'landing2d:SpatialPacket', ...
    'Packet and graph-state spatial dimensions differ.');
N = schema.nNodes; X = zeros(schema.inDim,N);
theta = atan2(packet.sinTheta,packet.cosTheta);
age = min(packet.timeSinceLastDetection/c.experiment.safety.prolongedLoss,1);
posU = min(packet.positionStd/5,1);
velU = min(packet.velocityStd/5,1);
accU = min(packet.accelerationStd/3,1);
remaining = packet.remainingMissionTime/c.experiment.maxMissionTime;
marginUrgency = max(0,-packet.predictedFovMargin)/(c.experiment.sensor.fov/2);
speedRisk = min(abs(packet.relativeVxEstimate)/3,1);
positionRisk = min(abs(packet.exEstimate)/3,1);
attitudeRisk = min(abs(theta)/c.experiment.dynamics.pitchLimit,1);
rateRisk = min(abs(packet.pitchRate)/c.experiment.dynamics.pitchRateLimit,1);
if spatial
    roll = atan2(packet.sinRoll,packet.cosRoll);
    speedRisk = min(hypot(packet.relativeVxEstimate,packet.relativeVyEstimate)/3,1);
    positionRisk = min(hypot(packet.exEstimate,packet.eyEstimate)/3,1);
    attitudeRisk = min(max(abs(theta),abs(roll))/c.experiment.dynamics.pitchLimit,1);
    rateRisk = min(max(abs(packet.pitchRate),abs(packet.rollRate))/ ...
        c.experiment.dynamics.pitchRateLimit,1);
end
trackConfidence = packet.detectionConfidence*double(packet.trackInitialized);
descentEvidence = trackConfidence*(1-positionRisk)*(1-speedRisk) ...
    *(1-attitudeRisk)*(1-rateRisk)*double(~packet.landingInhibited);
recoveryNeed = min(1,max([double(~packet.detected),age,marginUrgency]));
inhibit = max([double(packet.landingInhibited),double(packet.abortRequested), ...
    age,posU,velU]);

put(1,packet.detected,packet.measuredBearing,packet.predictedBearing, ...
    packet.predictedFovMargin,packet.bearingValid,packet.detectionConfidence, ...
    age,packet.predictedBearing,marginUrgency);
put(2,min(abs(packet.padVxEstimate)/10,1),packet.padVxEstimate/10, ...
    min(abs(packet.padAxEstimate)/2,1),packet.padAxEstimate/2, ...
    packet.trackInitialized,trackConfidence,max([velU,accU]), ...
    packet.padAxEstimate/2,accU);
put(3,min(packet.h/8,1),packet.vz/c.vzMax,min(abs(packet.vx)/c.vxMax,1), ...
    packet.vx/c.vxMax,1,1,0,packet.vz/c.vzMax,0);
put(4,attitudeRisk,theta/c.experiment.dynamics.pitchLimit,rateRisk, ...
    packet.pitchRate/c.experiment.dynamics.pitchRateLimit,1,1,0, ...
    packet.pitchRate/c.experiment.dynamics.pitchRateLimit,attitudeRisk);
put(5,positionRisk,packet.exEstimate/3,speedRisk, ...
    packet.relativeVxEstimate/3,packet.trackInitialized,trackConfidence, ...
    max(posU,velU),packet.relativeVxEstimate/3,marginUrgency);
correction = tanh(packet.exEstimate/3+0.5*packet.relativeVxEstimate/3);
correctionMagnitude = abs(correction);
if spatial
    correctionY = tanh(packet.eyEstimate/3+0.5*packet.relativeVyEstimate/3);
    correctionMagnitude = min(hypot(correction,correctionY),1);
end
put(6,correctionMagnitude,correction,speedRisk,-packet.relativeVxEstimate/3, ...
    packet.trackInitialized,trackConfidence,max(posU,velU), ...
    packet.padAxEstimate/2,positionRisk);
put(7,recoveryNeed,-sign(packet.predictedBearing)*recoveryNeed, ...
    marginUrgency,packet.predictedFovMargin/(c.experiment.sensor.fov/2), ...
    packet.trackInitialized,trackConfidence,max(age,posU), ...
    packet.predictedBearing/(c.experiment.sensor.fov/2),recoveryNeed);
put(8,descentEvidence,descentEvidence,1-speedRisk,-speedRisk, ...
    packet.trackInitialized,trackConfidence,max([posU,velU,age]), ...
    packet.vz/c.vzMax,1-descentEvidence);
put(9,inhibit,double(packet.abortRequested),age, ...
    double(packet.landingInhibited),1,1,max([posU,velU,age]), ...
    double(packet.abortRequested),inhibit);
if spatial
    halfFov = c.experiment.sensor.fov/2;
    X(10:11,1) = [packet.measuredBearingY;packet.predictedBearingY];
    X(10:11,2) = [packet.padVyEstimate/10;packet.padAyEstimate/2];
    X(10:11,3) = [packet.vy/c.vxMax;min(abs(packet.vy)/c.vxMax,1)];
    X(10:11,4) = [roll/c.experiment.dynamics.pitchLimit; ...
        packet.rollRate/c.experiment.dynamics.pitchRateLimit];
    X(10:11,5) = [packet.eyEstimate/3;packet.relativeVyEstimate/3];
    X(10:11,6) = [correctionY;-packet.relativeVyEstimate/3];
    X(10:11,7) = [-sign(packet.predictedBearingY)*recoveryNeed; ...
        packet.predictedBearingY/halfFov];
end
% Static channels are always the last three rows.
for node = 1:N
    X(schema.inDim-2,node) = remaining;
    X(schema.inDim-1,node) = 1;
    X(schema.inDim,node) = node/N;
end
X = min(max(X,-1),1);
S = X(:);
if nargout > 1
    detail = struct('X',X,'schema',schema,'packet',packet, ...
        'support',landing2d.graphstate.behaviorContext(packet,c));
end

    function put(node,p1,s1,p2,s2,valid,confidence,uncertainty,trend,urgency)
        X(1:9,node) = [p1;s1;p2;s2;valid;confidence;uncertainty;trend;urgency];
    end
end
