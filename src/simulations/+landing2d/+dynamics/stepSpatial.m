function [next,info] = stepSpatial(state,aRequest,dt,d,pitchDisturbance)
% STEPSPATIAL  3D extension of stepPlanar: pitch and roll loops plus thrust.
% Pitch and roll use the same critically damped second-order loop and limits.
% The exogenous pitch-rate event acts on pitch only, as in the planar model.
% With zero lateral command and zero roll state, x/z/pitch/thrust evolve
% exactly as landing2d.dynamics.stepPlanar.
if nargin < 5, pitchDisturbance = 0; end
[thetaSp,rollSp,thrustSp] = landing2d.dynamics.accelerationToAttitude(aRequest,d);
wn = d.pitchNaturalFrequency;
zeta = d.pitchDampingRatio;
thetaError = thetaSp-state.theta;
pitchAcceleration = wn^2*thetaError-2*zeta*wn*state.pitchRate;
pitchRate = state.pitchRate+dt*pitchAcceleration;
pitchRate = landing2d.util.saturate(pitchRate,d.pitchRateLimit);
theta = state.theta+dt*pitchRate+pitchDisturbance;
rollError = rollSp-state.roll;
rollAcceleration = wn^2*rollError-2*zeta*wn*state.rollRate;
rollRate = state.rollRate+dt*rollAcceleration;
rollRate = landing2d.util.saturate(rollRate,d.pitchRateLimit);
roll = state.roll+dt*rollRate;
thrustRate = (thrustSp-state.collectiveThrust)/d.thrustTimeConstant;
thrust = state.collectiveThrust+dt*thrustRate;
thrust = min(max(thrust,0),d.maxThrustWeightRatio*d.mass*d.gravity);
ax = thrust*cos(roll)*sin(theta)/d.mass;
ay = thrust*sin(roll)/d.mass;
az = thrust*cos(roll)*cos(theta)/d.mass-d.gravity;
next = state;
next.x = state.x+dt*state.vx+0.5*dt^2*ax;
next.y = state.y+dt*state.vy+0.5*dt^2*ay;
next.z = state.z+dt*state.vz+0.5*dt^2*az;
next.vx = state.vx+dt*ax;
next.vy = state.vy+dt*ay;
next.vz = state.vz+dt*az;
next.theta = theta;
next.pitchRate = pitchRate;
next.roll = roll;
next.rollRate = rollRate;
next.collectiveThrust = thrust;
tiltLimit = d.pitchLimit+deg2rad(1);
info = struct('thetaSetpoint',thetaSp,'rollSetpoint',rollSp, ...
    'thrustSetpoint',thrustSp,'actualAcceleration',[ax;ay;az], ...
    'pitchAcceleration',pitchAcceleration,'rollAcceleration',rollAcceleration, ...
    'hardEnvelopeViolation',abs(theta)>tiltLimit || abs(roll)>tiltLimit || ...
        abs(pitchRate)>d.pitchRateLimit+1e-12 || ...
        abs(rollRate)>d.pitchRateLimit+1e-12);
end
