function [track,info] = updatePadTrack(track,measurement,own,t,sensor)
% UPDATEPADTRACK  Small causal timestamped constant-acceleration estimator.
% The only pad-position input is a valid measurement plus synchronized own x.
if isfinite(track.lastUpdateTime) && t < track.lastUpdateTime-1e-12
    error('landing2d:EstimatorTimeOrder','Estimator time moved backwards.');
end
if isfinite(track.lastUpdateTime)
    dt = t-track.lastUpdateTime;
else
    dt = 0;
end
if track.initialized && dt > 0
    track.padX = track.padX+track.padVx*dt+0.5*track.padAx*dt^2;
    track.padVx = track.padVx+track.padAx*dt;
    track.padAx = track.padAx*exp(-dt/sensor.accelerationDecayTime);
    track.positionStd = hypot(track.positionStd,0.5*sensor.processAccelerationStd*dt^2);
    track.velocityStd = hypot(track.velocityStd,sensor.processAccelerationStd*dt);
    track.accelerationStd = hypot(track.accelerationStd, ...
        sensor.processAccelerationStd*sqrt(max(dt,0)));
end
track.lastUpdateTime = t;
accepted = false; innovation = NaN;
isNew = measurement.detected && measurement.valid ...
    && (~isfinite(track.lastMeasurementTime) || t > track.lastMeasurementTime+1e-12);
if isNew
    measuredPadX = own.x+measurement.relativeX;
    if ~track.initialized
        track.padX = measuredPadX;
        track.padVx = 0;
        track.padAx = 0;
        track.initialized = true;
        accepted = true;
    else
        innovation = measuredPadX-track.padX;
        gate = sensor.reacquisitionGateSigma*max(track.positionStd, ...
            sensor.relativePositionNoiseStd);
        accepted = abs(innovation) <= max(gate,0.25);
        if accepted
            gap = t-track.lastMeasurementTime;
            % Causal alpha-beta-gamma innovation update. Directly
            % differencing 2-cm position noise at the 100-Hz physics rate
            % amplified it into multi-m/s velocity and hundreds of m/s^2
            % acceleration spikes. The predicted track above is corrected
            % without using future samples or hidden simulator truth.
            track.padX = track.padX+sensor.positionInnovationGain*innovation;
            track.padVx = track.padVx+ ...
                sensor.velocityInnovationGain*innovation/max(gap,eps);
            track.padAx = track.padAx+sensor.accelerationInnovationGain* ...
                2*innovation/max(gap^2,eps);
            track.padAx = landing2d.util.saturate(track.padAx, ...
                sensor.maxAccelerationEstimate);
            track.positionStd = max(sensor.relativePositionNoiseStd, ...
                0.5*track.positionStd);
            track.velocityStd = max(sensor.relativePositionNoiseStd/ ...
                max(gap,eps)*sensor.velocityInnovationGain,0.80*track.velocityStd);
            track.accelerationStd = max(sensor.processAccelerationStd*0.25, ...
                0.85*track.accelerationStd);
            track.lastMeasuredVelocity = track.padVx;
            track.lastVelocityTime = t;
        end
    end
    if accepted
        track.lastMeasurementTime = t;
        track.lastMeasurementPadX = measuredPadX;
        track.lastConfidence = measurement.confidence;
        track.lastBearing = measurement.bearing;
        track.bearingValid = measurement.bearingValid;
    end
end
if isfinite(track.lastMeasurementTime)
    track.timeSinceLastDetection = max(0,t-track.lastMeasurementTime);
else
    track.timeSinceLastDetection = Inf;
end
if ~measurement.detected
    track.bearingValid = false;
end
info = struct('accepted',accepted,'innovation',innovation,'idempotent', ...
    measurement.detected && measurement.valid && ~isNew);
end
