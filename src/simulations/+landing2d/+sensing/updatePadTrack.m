function [track,info] = updatePadTrack(track,measurement,own,t,sensor)
% UPDATEPADTRACK  Small causal timestamped constant-acceleration estimator.
% The only pad-position input is a valid measurement plus synchronized own x.
% A 3D track (field padY) runs the same filter on the lateral axis with the
% shared isotropic uncertainty, and gates on the horizontal innovation norm.
spatial = isfield(track,'padY');
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
    if spatial
        track.padY = track.padY+track.padVy*dt+0.5*track.padAy*dt^2;
        track.padVy = track.padVy+track.padAy*dt;
        track.padAy = track.padAy*exp(-dt/sensor.accelerationDecayTime);
    end
    track.positionStd = hypot(track.positionStd,0.5*sensor.processAccelerationStd*dt^2);
    track.velocityStd = hypot(track.velocityStd,sensor.processAccelerationStd*dt);
    track.accelerationStd = hypot(track.accelerationStd, ...
        sensor.processAccelerationStd*sqrt(max(dt,0)));
end
track.lastUpdateTime = t;
accepted = false; innovation = NaN; innovationY = NaN;
isNew = measurement.detected && measurement.valid ...
    && (~isfinite(track.lastMeasurementTime) || t > track.lastMeasurementTime+1e-12);
if isNew
    measuredPadX = own.x+measurement.relativeX;
    if spatial
        measuredPadY = own.y+measurement.relativeY;
    end
    if ~track.initialized
        track.padX = measuredPadX;
        % The reset contract starts the aircraft horizontally matched to the
        % pad. Until two measurements exist, own velocity is the only causal
        % velocity prior available; zero created a large fictitious relative
        % speed on the very first policy observation.
        if isfield(own,'vx') && isfinite(own.vx)
            track.padVx = own.vx;
        else
            track.padVx = 0;
        end
        track.padAx = 0;
        if spatial
            track.padY = measuredPadY;
            track.padVy = own.vy;
            track.padAy = 0;
        end
        track.initialized = true;
        accepted = true;
    else
        innovation = measuredPadX-track.padX;
        gate = sensor.reacquisitionGateSigma*max(track.positionStd, ...
            sensor.relativePositionNoiseStd);
        if spatial
            innovationY = measuredPadY-track.padY;
            accepted = hypot(innovation,innovationY) <= max(gate,0.25);
        else
            accepted = abs(innovation) <= max(gate,0.25);
        end
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
            if spatial
                track.padY = track.padY+sensor.positionInnovationGain*innovationY;
                track.padVy = track.padVy+ ...
                    sensor.velocityInnovationGain*innovationY/max(gap,eps);
                track.padAy = track.padAy+sensor.accelerationInnovationGain* ...
                    2*innovationY/max(gap^2,eps);
                track.padAy = landing2d.util.saturate(track.padAy, ...
                    sensor.maxAccelerationEstimate);
            end
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
        if spatial
            track.lastMeasurementPadY = measuredPadY;
            track.lastBearingY = measurement.bearingY;
        end
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
if spatial, info.innovationY = innovationY; end
end
