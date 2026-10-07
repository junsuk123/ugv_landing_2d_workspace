function pad = padState(p,t)
% PADSTATE  True pad state at scalar time t (environment/evaluation use only).
% 2D fields: x, z, vx, ax, phase. A 3D scenario (fields vy1, ay2) adds the
% lateral CV-CA-CV components y, vy, ay with the same phase times T1, T2.
[x,vx,ax,phase] = landing2d.scenario.evaluateTrajectory(p,t);
pad = struct('x',x,'z',p.padHeight,'vx',vx,'ax',ax,'phase',phase);
if isfield(p,'vy1')
    [pad.y,pad.vy,pad.ay] = lateralTrajectory(p,t);
end
end

function [y,vy,ay] = lateralTrajectory(p,t)
t = max(0,min(t,p.deadline));
vy3 = p.vy1+p.ay2*p.T2;
y1 = p.y0+p.vy1*p.T1;
y2 = y1+p.vy1*p.T2+0.5*p.ay2*p.T2^2;
if t < p.T1
    y = p.y0+p.vy1*t; vy = p.vy1; ay = 0;
elseif t < p.T1+p.T2
    tau = t-p.T1;
    y = y1+p.vy1*tau+0.5*p.ay2*tau^2; vy = p.vy1+p.ay2*tau; ay = p.ay2;
else
    tau = t-p.T1-p.T2;
    y = y2+vy3*tau; vy = vy3; ay = 0;
end
end
