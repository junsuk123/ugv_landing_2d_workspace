function [thetaSetpoint,rollSetpoint,thrustSetpoint] = accelerationToAttitude(aRequest,d)
% ACCELERATIONTOATTITUDE  3D world net acceleration [a_x;a_y;a_z] to inner-loop targets.
% Thrust direction n = [cos(phi)sin(theta); sin(phi); cos(phi)cos(theta)] is
% aligned with [a_x; a_y; g+a_z]. With a_y = 0 the result equals the planar
% landing2d.dynamics.accelerationToThrustPitch exactly (roll 0, same thrust).
% Roll reuses the pitch limit: one symmetric tilt envelope per axis.
validateattributes(aRequest,{'numeric'},{'real','finite','vector','numel',3});
vertical = d.gravity+aRequest(3);
longitudinal = hypot(aRequest(1),vertical);
thetaSetpoint = atan2(aRequest(1),vertical);
thetaSetpoint = landing2d.util.saturate(thetaSetpoint,d.pitchLimit);
rollSetpoint = atan2(aRequest(2),longitudinal);
rollSetpoint = landing2d.util.saturate(rollSetpoint,d.pitchLimit);
thrustSetpoint = d.mass*hypot(longitudinal,aRequest(2));
thrustSetpoint = min(max(thrustSetpoint,0), ...
    d.maxThrustWeightRatio*d.mass*d.gravity);
end
