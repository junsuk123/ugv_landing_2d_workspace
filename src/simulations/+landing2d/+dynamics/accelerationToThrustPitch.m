function [thetaSetpoint,thrustSetpoint] = accelerationToThrustPitch(aRequest,d)
% ACCELERATIONTOTHRUSTPITCH  World net acceleration to inner-loop targets.
validateattributes(aRequest,{'numeric'},{'real','finite','vector','numel',2});
thetaSetpoint = atan2(aRequest(1),d.gravity+aRequest(2));
thetaSetpoint = landing2d.util.saturate(thetaSetpoint,d.pitchLimit);
thrustSetpoint = d.mass*hypot(aRequest(1),d.gravity+aRequest(2));
thrustSetpoint = min(max(thrustSetpoint,0), ...
    d.maxThrustWeightRatio*d.mass*d.gravity);
end
