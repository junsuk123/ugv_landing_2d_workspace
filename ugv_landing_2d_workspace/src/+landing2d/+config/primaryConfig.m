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
% Iteration 1 starts 0.1--0.4 m above the pad so a random policy can produce
% enough genuine safe contacts to learn touchdown without a teacher. The
% range then expands continuously to the nominal 4--8 m distribution.
cfg.rl.initialHeightRange = [0.025,1.00];
cfg.rl.curriculumStartHeight = 0.05;
cfg.rl.abortCurriculumFraction = 0.55;
cfg.rl.abortCurriculumStart = 12.0;
cfg.rl.motionCurriculumFraction = 0.65;
cfg.rl.motionCurriculumStartScale = 0.15;
% Successful windows can promote early. A later scheduled floor prevents a
% permanently stalled curriculum and guarantees nominal-task exposure.
cfg.rl.curriculumMode = 'performance';
cfg.rl.curriculumLandingThreshold = 0.10;
cfg.rl.curriculumStep = 0.10;
cfg.rl.curriculumRequiredWindows = 3;
% The last 20%% trains mostly on the complete 4--8 m distribution. One easy
% and one bridge episode per six-episode batch prevent touchdown forgetting.
cfg.rl.curriculumFloorStartFraction = 0.30;
cfg.rl.curriculumFullDifficultyFraction = 0.80;
cfg.rl.checkpointMinCurriculum = 1.0;
cfg.rl.curriculumEasyReplayFraction = 1/3;
cfg.rl.curriculumBridgeReplayFraction = 1/6;
cfg.rl.touchdownSpeedCurriculumScale = 2.0;
cfg.rl.unsafePenaltyCurriculumStart = -5.0;
cfg.rl.observationDim = cfg.experiment.observationSchema.dimension;
cfg.rl.actionInterval = round(cfg.experiment.policyDt/cfg.experiment.physicsDt);
cfg.rl.gamma = exp(-cfg.experiment.policyDt/ ...
    cfg.experiment.reward.discountTimeConstant);
cfg.rl.policyFile = 'ppo_low_level_planar_visibility_v2.mat';
cfg.graphState.useScratchSettings = false;
cfg.graphState.policyFile = 'ppo_context_planar_visibility_v2.mat';
cfg.scratchBaseline = true;
end
