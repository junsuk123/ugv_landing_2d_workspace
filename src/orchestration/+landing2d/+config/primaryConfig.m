function cfg = primaryConfig(projectRoot)
% PRIMARYCONFIG  Configuration of the relational_policy_v1 study (planar contract).
%   cfg = landing2d.config.primaryConfig()
% Single place where the pieces are assembled:
%   experiment  environment, sensors, reward, scenario family and seed manifest
%               (landing2d.config.defaultPlanarVisibilityConfig)
%   rl          PPO, identical for every method (landing2d.rl.defaultRlConfig)
%   graphState  state representation; plain PPO by default, set per method by
%               landing2d.config.applyMethod (landing2d.graphstate.defaultGraphStateConfig)
%   evaluation  evaluation-only settings (landing2d.config.defaultEvaluationConfig)
% Training is direct PPO from random weights on the full scenario family; the
% methods differ only in the Actor/Critic state representation.
if nargin < 1
    projectRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end
cfg = landing2d.config.defaultConfig(projectRoot);
cfg.experiment = landing2d.config.defaultPlanarVisibilityConfig();
cfg.rl.observationDim = cfg.experiment.observationSchema.dimension;
cfg.rl.actionInterval = round(cfg.experiment.policyDt/cfg.experiment.physicsDt);
cfg.rl.gamma = exp(-cfg.experiment.policyDt/cfg.experiment.reward.discountTimeConstant);
cfg.evaluation = landing2d.config.defaultEvaluationConfig();
end
