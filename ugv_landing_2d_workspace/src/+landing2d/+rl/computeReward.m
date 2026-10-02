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
readiness = landingReadiness(truth,c);
readinessReward = (dt/r.referenceTime)*r.readinessWeight*readiness;
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
reward = terminalBonus-runningCost+readinessReward+potentialShaping;
components = struct('goalCost',cGoal,'viewCost',cView, ...
    'controlCost',cControl,'scaledRunningCost',runningCost, ...
    'landingReadiness',readiness,'readinessReward',readinessReward, ...
    'previousGoalCost',previousGoalCost,'potentialShaping',potentialShaping, ...
    'terminalBonus',terminalBonus,'dt',dt);
end

function value=goalCost(truth,r)
zeta=(truth.ex/r.goalLengthX)^2+(truth.h/r.goalLengthH)^2;
value=zeta/(1+zeta);
end

function value=landingReadiness(truth,c)
s=c.experiment.safety;
r=c.experiment.reward;
ex=fieldOrZero(truth,'ex');
h=max(fieldOrZero(truth,'h'),0);
relativeVx=fieldOrZero(truth,'relativeVx');
vz=fieldOrZero(truth,'vz');
theta=fieldOrZero(truth,'theta');
pitchRate=fieldOrZero(truth,'pitchRate');
closingSpeed=min(s.touchdownSpeedX,0.6*abs(ex));
desiredRelativeVx=-sign(ex)*closingSpeed;
desiredVz=-min(0.8*s.touchdownSpeedZ,0.5*h);
risk=(ex/max(c.padHalfLength,eps))^2+ ...
    (h/r.readinessHeight)^2+ ...
    ((relativeVx-desiredRelativeVx)/s.touchdownSpeedX)^2+ ...
    ((vz-desiredVz)/s.touchdownSpeedZ)^2+ ...
    (theta/s.touchdownPitchTolerance)^2+ ...
    (pitchRate/s.touchdownPitchRateTolerance)^2;
value=exp(-0.5*min(risk,100));
end

function value=fieldOrZero(s,name)
if isfield(s,name), value=s.(name); else, value=0; end
end
