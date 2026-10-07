function metric = trajectoryMetrics(result,traj,spec,c,modelLabel,mode)
% TRAJECTORYMETRICS  Causal rollout stability and landing-inhibit audit.
% Truth is used only after rollout for evaluation; it is never fed to a
% policy.  Cause shares partition time for which the policy packet carried
% landingInhibited=true.
% 3D option: tracking/speed errors are horizontal norms, the attitude RMS
% combines pitch and roll, and the FOV audit uses the conical projection.
n = traj.count;
spatial = isfield(result,'yDrone');
assert(n>0,'landing2d:PaperEmptyRollout','Paper rollout produced no decisions.');
t = result.time(1:n);
dt = traj.dt(:)';
ex = result.xPad(1:n)-result.xDrone(1:n);
relativeVx = result.vxPad(1:n)-result.vxDrone(1:n);
height = result.zDrone(1:n)-spec.scenario.padHeight;
visible = logical(result.visible(1:n));
inhibitIndex = strcmp(c.experiment.observationSchema.names,'landingInhibited');
inhibited = traj.observation(inhibitIndex,:)>0.5;
if spatial
    ey = result.yPad(1:n)-result.yDrone(1:n);
    relativeVy = result.vyPad(1:n)-result.vyDrone(1:n);
end

geometricVisible = false(1,n);
fovMargin = zeros(1,n);
for k = 1:n
    state = struct('x',result.xDrone(k),'z',result.zDrone(k), ...
        'theta',result.theta(k));
    pad = struct('x',result.xPad(k),'z',spec.scenario.padHeight);
    if spatial
        state.y = result.yDrone(k); state.roll = result.roll(k);
        pad.y = result.yPad(k);
    end
    projection = landing2d.sensing.projectPad(state,pad,c.experiment.sensor);
    geometricVisible(k) = projection.visible;
    fovMargin(k) = projection.fovMargin;
end

events = spec.sensorEvents;
dropout = isfinite(events.dropoutStart) & t>=events.dropoutStart & ...
    t<events.dropoutEnd;
horizontalSpeed = abs(relativeVx);
if spatial, horizontalSpeed = hypot(relativeVx,relativeVy); end
speedRisk = horizontalSpeed>c.experiment.safety.touchdownSpeedX;
trajectoryRisk = ~geometricVisible;
assignedDropout = inhibited & dropout;
assignedTrajectory = inhibited & ~assignedDropout & trajectoryRisk;
assignedSpeed = inhibited & ~assignedDropout & ~assignedTrajectory & speedRisk;
assignedUncertainty = inhibited & ~assignedDropout & ~assignedTrajectory & ~assignedSpeed;
inhibitDuration = weighted(inhibited,dt);
causeDurations = [weighted(assignedDropout,dt), ...
    weighted(assignedTrajectory,dt),weighted(assignedSpeed,dt), ...
    weighted(assignedUncertainty,dt)];
causeNames = ["sensor dropout","trajectory/FOV","relative speed","uncertainty/gate"];
if inhibitDuration<=eps
    dominantCause = "none";
else
    [~,which] = max(causeDurations);
    dominantCause = causeNames(which);
end

duration = max(sum(dt),eps);
xRmse = sqrt(sum(dt.*ex.^2)/duration);
vRmse = sqrt(sum(dt.*relativeVx.^2)/duration);
pitchRms = sqrt(sum(dt.*result.theta(1:n).^2)/duration);
if spatial
    xRmse = sqrt(sum(dt.*(ex.^2+ey.^2))/duration);
    vRmse = sqrt(sum(dt.*(relativeVx.^2+relativeVy.^2))/duration);
    pitchRms = sqrt(sum(dt.*(result.theta(1:n).^2+result.roll(1:n).^2))/duration);
end
fovLossFraction = weighted(~visible,dt)/duration;
geometricLossFraction = weighted(~geometricVisible,dt)/duration;
supervisorFraction = weighted(traj.safetyIntervened,dt)/duration;
unsafeDescent = inhibited & result.vzDrone(1:n)<0 & ...
    height<=c.experiment.reward.readinessHeight;
unsafeDescentExposure = weighted(unsafeDescent,dt);
jerkRms = controlJerk(traj.appliedAcceleration,dt);
recoveryLatency = reacquisitionLatency(result,events);

% A transparent, bounded stability index.  It does not contain return or
% success, so the landing outcome remains a separate reported quantity.
safety = c.experiment.safety;
positionScore = exp(-(xRmse/max(c.padHalfLength,eps))^2);
speedScore = exp(-(vRmse/max(safety.touchdownSpeedX,eps))^2);
visibilityScore = 1-fovLossFraction;
supervisorScore = 1-supervisorFraction;
attitudeScore = exp(-(pitchRms/max(safety.touchdownPitchTolerance,eps))^2);
jerkReference = hypot(c.axMax,c.azMax)/c.experiment.policyDt;
if spatial
    jerkReference = norm(landing2d.environment.actionLimits(c))/c.experiment.policyDt;
end
smoothnessScore = 1/(1+jerkRms/max(jerkReference,eps));
stabilityIndex = 100*mean([positionScore,speedScore,visibilityScore, ...
    supervisorScore,attitudeScore,smoothnessScore]);

feasibility = landing2d.paper.scenarioFeasibility(spec,c);
if ~feasibility.PhysicalFeasible
    interpretation = "physically infeasible: "+feasibility.PhysicalCause;
elseif inhibitDuration>eps
    interpretation = "physically feasible; temporary inhibit: "+dominantCause;
else
    interpretation = "physically feasible; no landing inhibit";
end

metric = struct('Scenario',string(spec.id),'ScenarioName',string(spec.name), ...
    'Method',string(modelLabel),'StateRepresentation',string(mode), ...
    'TerminalReason',string(result.terminalReason), ...
    'Success',strcmp(result.terminalReason,'SUCCESS'), ...
    'Return',result.return,'LandingTime_s',result.landingTime, ...
    'Duration_s',duration,'TrackingRMSE_m',xRmse, ...
    'RelativeSpeedRMSE_mps',vRmse,'PitchRMS_deg',rad2deg(pitchRms), ...
    'MeasuredFOVLoss_pct',100*fovLossFraction, ...
    'GeometricFOVLoss_pct',100*geometricLossFraction, ...
    'SupervisorIntervention_pct',100*supervisorFraction, ...
    'LandingInhibit_pct',100*inhibitDuration/duration, ...
    'UnsafeDescentExposure_s',unsafeDescentExposure, ...
    'ControlJerkRMS_mps3',jerkRms,'RecoveryLatency_s',recoveryLatency, ...
    'StabilityIndex',stabilityIndex,'DominantInhibitCause',dominantCause, ...
    'InhibitDropout_s',causeDurations(1), ...
    'InhibitTrajectoryFOV_s',causeDurations(2), ...
    'InhibitRelativeSpeed_s',causeDurations(3), ...
    'InhibitUncertainty_s',causeDurations(4), ...
    'PhysicalFeasible',feasibility.PhysicalFeasible, ...
    'Interpretation',interpretation, ...
    'FOVViolationIntegral_s',sum(dt.*max(0,-fovMargin)/ ...
        max(c.experiment.sensor.fov/2,eps)), ...
    'MeanDescentEligibility',mean(traj.descentEligibility), ...
    'VerticalGate_pct',100*mean(traj.verticalGateActive), ...
    'MeanAbsRelationResidualX',mean(abs(traj.relationResidual(1,:))), ...
    'MeanAbsRelationResidualZ',mean(abs(traj.relationResidual(end,:))), ...
    'RelationResidualActive',any(abs(traj.relationResidual(:))>1e-10));
if spatial
    metric.MeanAbsRelationResidualY = mean(abs(traj.relationResidual(2,:)));
end
end

function value = weighted(mask,dt)
value = sum(dt.*double(mask));
end

function rmsValue = controlJerk(acceleration,dt)
if size(acceleration,2)<2
    rmsValue = 0;
    return;
end
deltaT = max(dt(2:end),eps);
jerk = diff(acceleration,1,2)./deltaT;
rmsValue = sqrt(mean(sum(jerk.^2,1)));
end

function latency = reacquisitionLatency(result,events)
if ~isfinite(events.dropoutEnd)
    latency = NaN;
    return;
end
indices = find(result.time>=events.dropoutEnd & result.visible,1,'first');
if isempty(indices)
    latency = NaN;
else
    latency = max(0,result.time(indices)-events.dropoutEnd);
end
end
