function [reward,components] = computeReward(previousTruth,truth,measurement,aNorm,dt,event,c,previousNorm)
% COMPUTEREWARD  Common costs, policy-invariant progress shaping and terminal.
% 3D option (truth.ey present): the same terms use the horizontal error vector,
% the off-axis bearing, and roll/roll-rate alongside pitch/pitch-rate.
% Optional reward.actionChangeWeight (3D option only) adds a running cost on
% the change of the normalized action since the previous decision.
r = c.experiment.reward;
cGoal = goalCost(truth,r);
previousGoalCost = goalCost(previousTruth,r);
if measurement.detected && measurement.bearingValid && isfield(measurement,'bearingY')
    cView = min(1,(hypot(measurement.bearing,measurement.bearingY)/ ...
        (c.experiment.sensor.fov/2))^2);
elseif measurement.detected && measurement.bearingValid
    cView = min(1,(measurement.bearing/(c.experiment.sensor.fov/2))^2);
else
    cView = 1;
end
cControl = 0.5*sum(aNorm(:).^2);
runningCost = (dt/r.referenceTime)*(r.goalWeight*cGoal+ ...
    r.viewWeight*cView+r.controlWeight*cControl);
cChange = 0;
if isfield(r,'actionChangeWeight') && nargin >= 8 && ~isempty(previousNorm)
    cChange = 0.5*sum((aNorm(:)-previousNorm(:)).^2);
    runningCost = runningCost+(dt/r.referenceTime)*r.actionChangeWeight*cChange;
end
readiness = landingReadiness(truth,c);
previousReadiness = landingReadiness(previousTruth,c);
% Pay only signed progress toward a touchdown-ready state.  Paying the
% absolute readiness every step made a near-pad hover accumulate reward and
% compete with actual contact.  This difference telescopes over an episode:
% holding position earns zero and moving away returns the earlier gain.
readinessReward = r.readinessWeight*(readiness-previousReadiness);
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
    'landingReadiness',readiness,'previousLandingReadiness',previousReadiness, ...
    'readinessReward',readinessReward, ...
    'previousGoalCost',previousGoalCost,'potentialShaping',potentialShaping, ...
    'terminalBonus',terminalBonus,'dt',dt);
if isfield(r,'actionChangeWeight'), components.actionChangeCost = cChange; end
end

function value=goalCost(truth,r)
if isfield(truth,'ey')
    x2=(hypot(truth.ex,truth.ey)/r.goalLengthX)^2;
else
    x2=(truth.ex/r.goalLengthX)^2;
end
h2=(truth.h/r.goalLengthH)^2;
xCost=x2/(1+x2);
hCost=h2/(1+h2);
value=r.goalHorizontalShare*xCost+(1-r.goalHorizontalShare)*hCost;
end

function value=landingReadiness(truth,c)
if isfield(truth,'ey')
    value=spatialLandingReadiness(truth,c);
    return;
end
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

function value=spatialLandingReadiness(truth,c)
% Same Gaussian readiness as the planar case with lateral/roll terms added.
s=c.experiment.safety;
r=c.experiment.reward;
ex=truth.ex; ey=truth.ey;
h=max(truth.h,0);
distance=hypot(ex,ey);
closingSpeed=min(s.touchdownSpeedX,0.6*distance);
if distance>0
    direction=[ex,ey]/distance;
else
    direction=[0,0];
end
desiredRelativeVx=-direction(1)*closingSpeed;
desiredRelativeVy=-direction(2)*closingSpeed;
desiredVz=-min(0.8*s.touchdownSpeedZ,0.5*h);
risk=(ex/max(c.padHalfLength,eps))^2+ ...
    (ey/max(c.experiment.spatial.padHalfWidth,eps))^2+ ...
    (h/r.readinessHeight)^2+ ...
    ((truth.relativeVx-desiredRelativeVx)/s.touchdownSpeedX)^2+ ...
    ((truth.relativeVy-desiredRelativeVy)/s.touchdownSpeedX)^2+ ...
    ((truth.vz-desiredVz)/s.touchdownSpeedZ)^2+ ...
    (truth.theta/s.touchdownPitchTolerance)^2+ ...
    (truth.roll/s.touchdownPitchTolerance)^2+ ...
    (truth.pitchRate/s.touchdownPitchRateTolerance)^2+ ...
    (truth.rollRate/s.touchdownPitchRateTolerance)^2;
value=exp(-0.5*min(risk,100));
end

function value=fieldOrZero(s,name)
if isfield(s,name), value=s.(name); else, value=0; end
end
