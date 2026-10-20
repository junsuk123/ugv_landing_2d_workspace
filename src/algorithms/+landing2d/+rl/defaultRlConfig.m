function rl = defaultRlConfig()
% DEFAULTRLCONFIG  PPO settings shared by every compared method (relational_policy_v1).
% Direct PPO from random weights on the planar scenario family: no teacher,
% curriculum, scripted prefix or relation-only stage. observationDim,
% actionInterval and gamma are derived from the experiment in primaryConfig.
rl.seed = 20240501;            % base seed; training seed s uses seed + s - 1
rl.trainingRegime = 'direct_ppo_v1';
rl.hiddenSize = 48;            % legacy plain-PPO width (12-D o_t: 48-48 / 48-48)
% Plain-PPO MLP widths for the 10-D o_t (relational-policy-v2.3): Actor 48-51,
% Critic 47-50 restore exactly 6,101 parameters after the two constant
% navigation inputs were removed (48-48 would give 5,909). R-GAT arms use
% graphState.v2Policy/ValueHiddenSizes.
rl.baselinePolicyHiddenSizes = [48,51];
rl.baselineValueHiddenSizes = [47,50];
rl.observationDim = 10;
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
% Exploration noise of the pre-tanh command (relational-policy-v2.1). At the
% former -1.0 (sigma 0.37) even converged landing controllers of all three
% methods landed 17% and hit unsafe contact 53% of their stochastic episodes,
% so a landing attempt under the training noise mostly earned the failure
% terminal and hovering to the timeout was the better return (the hover trap
% of v2.0). -2.0 (sigma 0.135) is the largest grid value at which those
% controllers keep unsafe contact <= 20% (docs/RGAT_V2_DESIGN_KO.md section 8).
rl.initialLogStd = -2.0;
rl.minimumLogStd = -2.5;
rl.maxGradNorm = 1.0;
rl.valueWarmup = 2;            % first updates train the critic only
% Validation (checkpoint selection, learning curve) every evaluateEvery updates.
rl.evaluateEvery = 25;
rl.earlyStopPatience = 0;      % 0 = off (no stop on missing improvement)
% Common plateau stop (relational-policy-v2.0): a run ends once its `window`
% most recent validation evaluations (window x validationEpisodeCount
% episodes) all land at least minimumLandingRate, and at least
% minimumIterations updates were made. Validation split only; the budget
% ppoIterations stays the upper limit, so a run that has not converged keeps
% training. The same rule applies to every method.
rl.earlyStop = struct('rule','validation_plateau_v1','window',3, ...
    'minimumLandingRate',0.95,'minimumIterations',150);
% Validation screen (relational-policy-v2.1): each validation first flies the
% first `episodes` validation seeds; only when at least minimumLandingRate of
% them land are the remaining validation seeds flown. A screened validation
% is recorded (and scored for checkpoint selection) on the screen episodes
% alone; a passed one is identical to the full evaluation. Validation split
% only, the same rule for every method.
rl.validationScreen = struct('rule','validation_screen_v1','episodes',20, ...
    'minimumLandingRate',0.5);
% Episode draws use their own stream rl.seed + episodeStreamSeedOffset.
rl.episodeStreamSeedOffset = 52001;
% Execution only (no effect on results; excluded from the training signature).
rl.parallelEpisodes = true;    % parfor over the episodes of one update
rl.parallelWorkers = 0;        % 0 = min(physical cores, episodes per update)
rl.policyFile = 'rl_policy.mat';
rl.retrain = false;
rl.verbose = true;
end
