function [applied,info] = safetySupervisor(requested,state,packet,c)
% SAFETYSUPERVISOR  Common causal braking/hold envelope for every method.
% This is a simulation guard, not a real-flight safety certificate.
% REQUESTED is [a_x;a_z] or, for the 3D option, [a_x;a_y;a_z]. The lateral
% axis mirrors the horizontal recovery rule; vertical rules are unchanged.
s = c.experiment.safety;
d = c.experiment.dynamics;
spatial = numel(requested) == 3;
ax = requested(1); az = requested(end);
if spatial
    ay = requested(2);
    ayMax = c.experiment.spatial.lateralAccelerationLimit;
end
reasons = {};
downSpeed = max(0,-state.vz);
availableBrake = max(1e-6,d.maxThrustWeightRatio*d.gravity-d.gravity);
stoppingHeight = downSpeed*s.responseDelay+downSpeed^2/(2*availableBrake);
if packet.abortRequested
    % Keep pursuing the last causal pad track while climbing to widen FOV.
    % Braking to zero inertial speed lets a moving UGV escape permanently;
    % relative position/velocity feedback instead creates a real chance to
    % reacquire without using phase labels or future ground truth.
    if packet.trackInitialized
        ax = 0.35*packet.exEstimate+0.8*packet.relativeVxEstimate;
    else
        ax = -1.5*state.vx;
    end
    ax = landing2d.util.saturate(ax,c.axMax);
    if spatial
        if packet.trackInitialized
            ay = 0.35*packet.eyEstimate+0.8*packet.relativeVyEstimate;
        else
            ay = -1.5*state.vy;
        end
        ay = landing2d.util.saturate(ay,ayMax);
    end
    if packet.h < s.abortHoldHeight || state.vz < -s.abortVerticalSpeedTolerance
        az = c.azMax;
    else
        az = landing2d.util.saturate(-1.5*state.vz,c.azMax);
    end
    reasons{end+1} = 'recovery_backup';
elseif packet.landingInhibited && (state.vz < 0 || packet.h <= stoppingHeight)
    az = max(az,min(c.azMax,availableBrake));
    reasons{end+1} = 'descent_inhibited';
elseif packet.h <= stoppingHeight && state.vz < -s.touchdownSpeedZ
    az = max(az,min(c.azMax,availableBrake));
    reasons{end+1} = 'vertical_stopping_margin';
end
if spatial
    applied = [landing2d.util.saturate(ax,c.axMax); ...
        landing2d.util.saturate(ay,ayMax); ...
        landing2d.util.saturate(az,c.azMax)];
else
    applied = [landing2d.util.saturate(ax,c.axMax); ...
        landing2d.util.saturate(az,c.azMax)];
end
info = struct('intervened',any(abs(applied-requested(:))>1e-12), ...
    'reasons',{reasons},'stoppingHeight',stoppingHeight, ...
    'availableVerticalBrake',availableBrake);
end
