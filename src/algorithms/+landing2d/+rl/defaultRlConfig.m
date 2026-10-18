function rl = defaultRlConfig()
% DEFAULTRLCONFIG  PPO settings shared by every compared method (relational_policy_v1).
% Direct PPO from random weights on the planar scenario family: no teacher,
% curriculum, scripted prefix or relation-only stage. observationDim,
% actionInterval and gamma are derived from the experiment in primaryConfig.
rl.seed = 20240501;            % base seed; training seed s uses seed + s - 1
rl.trainingRegime = 'direct_ppo_v1';
rl.hiddenSize = 48;            % plain-PPO MLP width (2 layers); R-GAT arms use
                               % graphState.policy/valueHiddenSizes (same 6,101 parameters)
rl.observationDim = 12;
rl.actionDim = 2;              % [a_x, a_z] before tanh scaling to the limits
rl.actionInterval = 10;
% Budget: 750 updates x 6 episodes = 4,500 episodes per run.
rl.ppoIterations = 750;
rl.episodesPerIteration = 6;
rl.ppoEpochs = 8;
rl.miniBatch = 256;
rl.clipRatio = 0.2;
rl.gamma = exp(-0.1/70);       % decision interval 0.1 s, discount time constant 70 s
rl.lambda = 0.95;              % GAE
rl.policyLearnRate = 2e-4;
rl.valueLearnRate = 5e-4;
rl.entropyWeight = 0.004;
rl.initialLogStd = -1.0;       % exploration noise (pre-tanh command)
rl.minimumLogStd = -2.5;
rl.maxGradNorm = 1.0;
rl.valueWarmup = 2;            % first updates train the critic only
% Validation (checkpoint selection, learning curve) every evaluateEvery updates.
rl.evaluateEvery = 25;
rl.earlyStopPatience = 0;      % 0 = off (the full budget is always used)
% Episode draws use their own stream rl.seed + episodeStreamSeedOffset.
rl.episodeStreamSeedOffset = 52001;
% Execution only (no effect on results; excluded from the training signature).
rl.parallelEpisodes = true;    % parfor over the episodes of one update
rl.parallelWorkers = 0;        % 0 = min(physical cores, episodes per update)
rl.policyFile = 'rl_policy.mat';
rl.retrain = false;
rl.verbose = true;
end
