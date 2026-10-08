function state = probeState(probe)
% PROBESTATE  True drone state struct of a fixed probe (evaluation only).
x = probe.drone;
state = struct('x',x(1),'z',x(2),'vx',x(3),'vz',x(4),'theta',x(5), ...
    'pitchRate',x(6),'collectiveThrust',x(7));
end
