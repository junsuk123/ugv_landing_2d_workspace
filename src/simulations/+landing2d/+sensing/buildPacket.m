function packet = buildPacket(state,track,measurement,status,scenario,t,c)
% BUILDPACKET  Causal shared packet for every learned policy branch.
% A 3D state (field y) adds the lateral/roll fields of causal_packet_v3_spatial.
sensor = c.experiment.sensor;
spatial = isfield(state,'y');
if track.initialized
    ex = track.padX-state.x;
    relativeVx = track.padVx-state.vx;
    futureEx = ex+relativeVx*sensor.predictionHorizon ...
        +0.5*track.padAx*sensor.predictionHorizon^2;
    h = state.z-scenario.padHeight;
    futureTheta = state.theta+state.pitchRate*sensor.predictionHorizon;
    fakeState = state; fakeState.x = 0; fakeState.z = h;
    fakeState.theta = futureTheta;
    fakePad = struct('x',futureEx,'z',0);
    if spatial
        ey = track.padY-state.y;
        relativeVy = track.padVy-state.vy;
        fakeState.y = 0;
        fakeState.roll = state.roll+state.rollRate*sensor.predictionHorizon;
        fakePad.y = ey+relativeVy*sensor.predictionHorizon ...
            +0.5*track.padAy*sensor.predictionHorizon^2;
    end
    predicted = landing2d.sensing.projectPad(fakeState,fakePad,sensor);
    predictedBearing = finiteOrZero(predicted.bearing);
    predictedMargin = finiteOrZero(predicted.fovMargin);
    if spatial, predictedBearingY = finiteOrZero(predicted.bearingY); end
else
    ex = 0; relativeVx = 0; predictedBearing = 0; predictedMargin = 0;
    ey = 0; relativeVy = 0; predictedBearingY = 0;
end
age = track.timeSinceLastDetection;
if ~isfinite(age), age = c.experiment.maxMissionTime; end
packet = struct( ...
    'h',state.z-scenario.padHeight,'vx',state.vx,'vz',state.vz, ...
    'sinTheta',sin(state.theta),'cosTheta',cos(state.theta), ...
    'pitchRate',state.pitchRate,'exEstimate',ex, ...
    'relativeVxEstimate',relativeVx,'padVxEstimate',track.padVx, ...
    'padAxEstimate',track.padAx,'positionStd',track.positionStd, ...
    'velocityStd',track.velocityStd,'accelerationStd',track.accelerationStd, ...
    'trackInitialized',track.initialized,'detected',measurement.detected, ...
    'measuredBearing',finiteOrZero(measurement.bearing), ...
    'bearingValid',measurement.bearingValid, ...
    'detectionConfidence',measurement.confidence, ...
    'timeSinceLastDetection',age,'predictedBearing',predictedBearing, ...
    'predictedFovMargin',predictedMargin, ...
    'remainingMissionTime',max(0,scenario.deadline-t), ...
    'previousNormalizedActionX',status.previousNormalizedAction(1), ...
    'previousNormalizedActionZ',status.previousNormalizedAction(end), ...
    'landingInhibited',status.landingInhibited, ...
    'abortRequested',status.abortRequested);
if spatial
    packet.vy = state.vy;
    packet.sinRoll = sin(state.roll);
    packet.cosRoll = cos(state.roll);
    packet.rollRate = state.rollRate;
    packet.eyEstimate = ey;
    packet.relativeVyEstimate = relativeVy;
    packet.padVyEstimate = track.padVy;
    packet.padAyEstimate = track.padAy;
    packet.measuredBearingY = finiteOrZero(measurement.bearingY);
    packet.predictedBearingY = predictedBearingY;
    packet.previousNormalizedActionY = status.previousNormalizedAction(2);
end
end

function x = finiteOrZero(x)
if ~isfinite(x), x = 0; end
end
