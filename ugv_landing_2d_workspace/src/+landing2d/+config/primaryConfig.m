function cfg = primaryConfig(projectRoot)
% PRIMARYCONFIG  Build the planar_visibility_v2 experiment configuration.
if nargin < 1
    projectRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end
cfg = landing2d.config.defaultConfig(projectRoot);
cfg.experiment = landing2d.config.defaultPlanarVisibilityConfig();
cfg.dt = cfg.experiment.physicsDt;
cfg.tEnd = cfg.experiment.maxMissionTime;
cfg.padHeight = cfg.experiment.scenario.padHeight;
cfg.cameraFovDeg = rad2deg(cfg.experiment.sensor.fov);
cfg.ceilingHeight = cfg.experiment.safety.ceilingHeight;
cfg.axMax = 1.2;
cfg.azMax = 2.0;
cfg.rl.useBehaviorClone = false;
cfg.rl.observationDim = cfg.experiment.observationSchema.dimension;
cfg.rl.actionInterval = round(cfg.experiment.policyDt/cfg.experiment.physicsDt);
cfg.rl.gamma = exp(-cfg.experiment.policyDt/ ...
    cfg.experiment.reward.discountTimeConstant);
cfg.rl.policyFile = 'ppo_low_level_planar_visibility_v2.mat';
cfg.graphState.useScratchSettings = false;
cfg.graphState.policyFile = 'ppo_context_planar_visibility_v2.mat';
cfg.scratchBaseline = true;
end
