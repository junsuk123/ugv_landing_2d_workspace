function [applied,info] = safetySupervisor(requested,state,packet,c)
% SAFETYSUPERVISOR  Common causal braking/hold envelope for every method.
% This is a simulation guard, not a real-flight safety certificate.
s = c.experiment.safety;
d = c.experiment.dynamics;
ax = requested(1); az = requested(2);
reasons = {};
downSpeed = max(0,-state.vz);
availableBrake = max(1e-6,d.maxThrustWeightRatio*d.gravity-d.gravity);
stoppingHeight = downSpeed*s.responseDelay+downSpeed^2/(2*availableBrake);
if packet.abortRequested
    ax = -min(c.axMax,max(-c.axMax,1.5*state.vx));
    if packet.h < s.abortHoldHeight || state.vz < -s.abortVerticalSpeedTolerance
        az = c.azMax;
    else
        az = landing2d.util.saturate(-1.5*state.vz,c.azMax);
    end
    reasons{end+1} = 'latched_abort'; %#ok<AGROW>
elseif packet.landingInhibited && (state.vz < 0 || packet.h <= stoppingHeight)
    az = max(az,min(c.azMax,availableBrake));
    reasons{end+1} = 'descent_inhibited'; %#ok<AGROW>
elseif packet.h <= stoppingHeight && state.vz < -s.touchdownSpeedZ
    az = max(az,min(c.azMax,availableBrake));
    reasons{end+1} = 'vertical_stopping_margin'; %#ok<AGROW>
end
applied = [landing2d.util.saturate(ax,c.axMax); ...
    landing2d.util.saturate(az,c.azMax)];
info = struct('intervened',any(abs(applied-requested(:))>1e-12), ...
    'reasons',{reasons},'stoppingHeight',stoppingHeight, ...
    'availableVerticalBrake',availableBrake);
end
