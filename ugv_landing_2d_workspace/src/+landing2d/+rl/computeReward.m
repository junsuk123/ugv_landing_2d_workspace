function [reward,components] = computeReward(truth,measurement,aNorm,dt,event,c)
% COMPUTEREWARD  Common bounded three-cost reward with one terminal outcome.
r = c.experiment.reward;
zeta = (truth.ex/r.goalLengthX)^2+(truth.h/r.goalLengthH)^2;
cGoal = zeta/(1+zeta);
if measurement.detected && measurement.bearingValid
    cView = min(1,(measurement.bearing/(c.experiment.sensor.fov/2))^2);
else
    cView = 1;
end
cControl = 0.5*sum(aNorm(:).^2);
runningCost = (dt/r.referenceTime)*(r.goalWeight*cGoal+ ...
    r.viewWeight*cView+r.controlWeight*cControl);
terminalBonus = 0;
if event.occurred
    assert(isfield(r,event.reason),'landing2d:TerminalReward', ...
        'No terminal reward configured for %s.',event.reason);
    terminalBonus = r.(event.reason);
end
reward = terminalBonus-runningCost;
components = struct('goalCost',cGoal,'viewCost',cView, ...
    'controlCost',cControl,'scaledRunningCost',runningCost, ...
    'terminalBonus',terminalBonus,'dt',dt);
end
