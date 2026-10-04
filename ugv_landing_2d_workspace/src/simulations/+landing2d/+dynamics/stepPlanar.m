function [next,info] = stepPlanar(state,aRequest,dt,d,pitchDisturbance)
% STEPPLANAR  Lagged planar pitch/thrust dynamics driven by actual attitude.
if nargin < 5, pitchDisturbance = 0; end
[thetaSp,thrustSp] = landing2d.dynamics.accelerationToThrustPitch(aRequest,d);
thetaError = thetaSp-state.theta;
pitchAcceleration = d.pitchNaturalFrequency^2*thetaError ...
    -2*d.pitchDampingRatio*d.pitchNaturalFrequency*state.pitchRate;
pitchRate = state.pitchRate+dt*pitchAcceleration;
pitchRate = landing2d.util.saturate(pitchRate,d.pitchRateLimit);
theta = state.theta+dt*pitchRate+pitchDisturbance;
thrustRate = (thrustSp-state.collectiveThrust)/d.thrustTimeConstant;
thrust = state.collectiveThrust+dt*thrustRate;
thrust = min(max(thrust,0),d.maxThrustWeightRatio*d.mass*d.gravity);
ax = thrust*sin(theta)/d.mass;
az = thrust*cos(theta)/d.mass-d.gravity;
next = state;
next.x = state.x+dt*state.vx+0.5*dt^2*ax;
next.z = state.z+dt*state.vz+0.5*dt^2*az;
next.vx = state.vx+dt*ax;
next.vz = state.vz+dt*az;
next.theta = theta;
next.pitchRate = pitchRate;
next.collectiveThrust = thrust;
info = struct('thetaSetpoint',thetaSp,'thrustSetpoint',thrustSp, ...
    'actualAcceleration',[ax;az],'pitchAcceleration',pitchAcceleration, ...
    'hardEnvelopeViolation',abs(theta)>d.pitchLimit+deg2rad(1) || ...
        abs(pitchRate)>d.pitchRateLimit+1e-12);
end
