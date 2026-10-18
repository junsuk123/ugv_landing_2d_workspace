function [x,v,a,phase] = evaluateTrajectory(p,t)
% EVALUATETRAJECTORY  Exact three-phase CV-CA-CV pad trajectory.
t = max(0,min(t,p.deadline));
x1 = p.x0+p.v1*p.T1;
x2 = x1+p.v1*p.T2+0.5*p.a2*p.T2^2;
x = zeros(size(t)); v = x; a = x; phase = ones(size(t));
i1 = t < p.T1;
i2 = ~i1 & t < p.T1+p.T2;
i3 = ~(i1|i2);
x(i1) = p.x0+p.v1*t(i1);
v(i1) = p.v1;
a(i1) = 0;
tau = t(i2)-p.T1;
x(i2) = x1+p.v1*tau+0.5*p.a2*tau.^2;
v(i2) = p.v1+p.a2*tau;
a(i2) = p.a2;
phase(i2) = 2;
tau = t(i3)-p.T1-p.T2;
x(i3) = x2+p.v3*tau;
v(i3) = p.v3;
a(i3) = 0;
phase(i3) = 3;
% Opt-in interactive diagnostic pulses only. No field -> original numerical
% path is unchanged. Exact integrals preserve x/v continuity at button times.
% These are exogenous scenario interventions, never policy input features.
if isfield(p,'liveAccelerationPulses')
    pulses=p.liveAccelerationPulses; % rows [start, duration, acceleration]
    for k=1:size(pulses,1)
        t0=pulses(k,1); duration=pulses(k,2); ak=pulses(k,3);
        tau=max(0,min(t-t0,duration));
        x=x+0.5*ak*tau.^2+ak*duration*max(t-t0-duration,0);
        v=v+ak*tau;
        active=t>=t0 & t<t0+duration;
        a(active)=a(active)+ak; phase(active)=2;
    end
end
end
