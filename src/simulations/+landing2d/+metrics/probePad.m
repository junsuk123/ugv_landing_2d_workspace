function pad = probePad(probe)
% PROBEPAD  True pad state struct of a fixed probe (evaluation only).
p = probe.pad;
pad = struct('x',p(1),'z',p(2),'vx',p(3),'ax',p(4));
end
