function id = taskFingerprint(c)
% TASKFINGERPRINT  Method-independent environment/reward/safety contract hash.
contract = struct('schemaVersion',c.experiment.schemaVersion, ...
    'timing',[c.experiment.physicsDt,c.experiment.policyDt], ...
    'scenario',c.experiment.scenario,'dynamics',c.experiment.dynamics, ...
    'sensor',c.experiment.sensor,'safety',c.experiment.safety, ...
    'reward',c.experiment.reward,'actionLimits',[c.axMax,c.azMax], ...
    'observationSchema',c.experiment.observationSchema.version);
if landing2d.environment.isSpatial(c)
    % 3D option only; the planar contract hash is unchanged.
    contract.actionLimits = landing2d.environment.actionLimits(c)';
    contract.spatial = c.experiment.spatial;
end
if isfield(c.experiment,'commonObservation')
    % Planar marker perception drives the safety supervisor and landing
    % authorization, so its camera/estimator/noise settings are task contract.
    contract.commonObservation = c.experiment.commonObservation;
end
text=jsonencode(contract);
id=landing2d.util.checksum(double(unicode2native(text,'UTF-8')));
end
