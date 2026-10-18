function cfg = smokeConfig(cfg)
% SMOKECONFIG  Bounded integration settings: every stage runs, nothing is a result.
% One PPO iteration of one episode per run and a few evaluation episodes.
cfg.rl.ppoIterations = 1;
cfg.rl.episodesPerIteration = 1;
cfg.rl.ppoEpochs = 1;
cfg.rl.miniBatch = 64;
cfg.rl.evaluateEvery = 1;
cfg.rl.valueWarmup = 0;
cfg.rl.parallelEpisodes = false;
cfg.rl.verbose = false;
cfg.experiment.validationEpisodeCount = 1;
cfg.experiment.testEpisodeCount = 2;
cfg.evaluation.factorial.replicates = 2;
cfg.evaluation.generalization.episodes = 1;
cfg.evaluation.probes.episodes = 1;
cfg.evaluation.probes.stride = 20;
cfg.figureVisible = false;
end
