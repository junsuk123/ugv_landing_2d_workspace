function pad = padState(p,t)
% PADSTATE  True pad state at scalar time t (environment/evaluation use only).
% Fields: x, z, vx, ax, phase.
[x,vx,ax,phase] = landing2d.scenario.evaluateTrajectory(p,t);
pad = struct('x',x,'z',p.padHeight,'vx',vx,'ax',ax,'phase',phase);
end
