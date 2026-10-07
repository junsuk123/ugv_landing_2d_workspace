function metric = scenarioFeasibility(spec,c)
% SCENARIOFEASIBILITY  Policy-independent physical authority margins.
% This is deliberately separate from the ontology's temporary landing
% inhibit.  LandingInhibit means "do not descend now"; it is not proof that
% the complete scenario can never be landed.
s = spec.scenario;
speedLimit = c.experiment.scenario.sustainedDroneSpeed- ...
    c.experiment.scenario.speedMargin;
speedMargin = speedLimit-s.v3;
accelerationMargin = c.axMax-s.a2;
peakSpeed = s.v3;
if landing2d.environment.isSpatial(c) && isfield(s,'vy1')
    % 3D option: horizontal peak speed and the tighter per-axis authority.
    peakSpeed = hypot(s.v3,s.vy3);
    speedMargin = speedLimit-peakSpeed;
    accelerationMargin = min(accelerationMargin, ...
        c.experiment.spatial.lateralAccelerationLimit-abs(s.ay2));
end
timeMargin = c.experiment.maxMissionTime-s.deadline;
physicalFeasible = speedMargin>=0 && accelerationMargin>0 && timeMargin>=0;
if speedMargin < 0
    cause = "speed authority";
elseif accelerationMargin <= 0
    cause = "acceleration authority";
elseif timeMargin < 0
    cause = "mission time";
else
    cause = "feasible";
end
metric = struct('Scenario',string(spec.id),'ScenarioName',string(spec.name), ...
    'Challenge',string(spec.challenge),'OntologyPath',string(spec.ontologyPath), ...
    'InitialSpeed_mps',s.v1,'PadAcceleration_mps2',s.a2, ...
    'PeakPadSpeed_mps',peakSpeed,'InitialHeight_m',s.height, ...
    'SpeedLimit_mps',speedLimit,'SpeedMargin_mps',speedMargin, ...
    'AccelerationLimit_mps2',c.axMax, ...
    'AccelerationMargin_mps2',accelerationMargin, ...
    'Deadline_s',s.deadline,'TimeMargin_s',timeMargin, ...
    'PhysicalFeasible',physicalFeasible,'PhysicalCause',cause, ...
    'DropoutKind',string(spec.sensorEvents.dropoutKind), ...
    'DropoutDuration_s',eventDuration(spec.sensorEvents.dropoutStart, ...
        spec.sensorEvents.dropoutEnd));
end

function duration = eventDuration(a,b)
if isfinite(a) && isfinite(b), duration=max(0,b-a); else, duration=0; end
end
