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
% All learned arms start from random weights.  Apply the complete scratch
% schedule, not only the imitation-learning flag: the short 60-iteration
% legacy fine-tuning schedule cannot discover touchdown from a random policy.
cfg.rl = landing2d.rl.applyScratchSettings(cfg.rl);
% Pure-RL curriculum: begin with low-altitude members of the same scenario
% family and expand to the complete nominal height range.  Evaluation always
% uses the untouched manifest distribution.
cfg.rl.curriculumFraction = 0.45;
cfg.rl.initialHeightRange = [0.35,1.00];
cfg.rl.curriculumStartHeight = 0.35;
cfg.rl.observationDim = cfg.experiment.observationSchema.dimension;
cfg.rl.actionInterval = round(cfg.experiment.policyDt/cfg.experiment.physicsDt);
cfg.rl.gamma = exp(-cfg.experiment.policyDt/ ...
    cfg.experiment.reward.discountTimeConstant);
cfg.rl.policyFile = 'ppo_low_level_planar_visibility_v2.mat';
cfg.graphState.useScratchSettings = false;
cfg.graphState.policyFile = 'ppo_context_planar_visibility_v2.mat';
cfg.scratchBaseline = true;
end
