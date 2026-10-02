function [reward,components] = computeReward(previousTruth,truth,measurement,aNorm,dt,event,c)
% COMPUTEREWARD  Common costs, policy-invariant progress shaping and terminal.
r = c.experiment.reward;
cGoal = goalCost(truth,r);
previousGoalCost = goalCost(previousTruth,r);
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
discount=exp(-dt/r.discountTimeConstant);
phiPrevious=-r.potentialWeight*previousGoalCost;
if event.occurred
    phiNext=0;
else
    phiNext=-r.potentialWeight*cGoal;
end
potentialShaping=discount*phiNext-phiPrevious;
reward = terminalBonus-runningCost+potentialShaping;
components = struct('goalCost',cGoal,'viewCost',cView, ...
    'controlCost',cControl,'scaledRunningCost',runningCost, ...
    'previousGoalCost',previousGoalCost,'potentialShaping',potentialShaping, ...
    'terminalBonus',terminalBonus,'dt',dt);
end

function value=goalCost(truth,r)
zeta=(truth.ex/r.goalLengthX)^2+(truth.h/r.goalLengthH)^2;
value=zeta/(1+zeta);
end
