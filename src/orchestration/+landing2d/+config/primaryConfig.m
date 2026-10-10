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
% The aircraft must retain control authority over the fastest admissible
% UGV acceleration (1.5 m/s^2) plus feedback correction.  The old 1.2
% m/s^2 cap made part of the scenario family physically untrackable.
cfg.axMax = 2.5;
cfg.azMax = 2.0;
% All learned arms start from random weights.  Apply the complete scratch
% schedule, not only the imitation-learning flag: the short 60-iteration
% legacy fine-tuning schedule cannot discover touchdown from a random policy.
cfg.rl = landing2d.rl.applyScratchSettings(cfg.rl);
% Direct PPO is the only policy-training aid: no teacher, scripted prefix,
% curriculum replay or relation-only repair stage.
cfg.rl.trainingRegime = 'direct_ppo_v1';
% Planar budget: 750 updates x 6 episodes = 4,500 episodes. The earlier
% 500-update paired run was sufficient for R-GAT (the selected checkpoint was
% update 225), but plain PPO never landed and diverged horizontally. The extra
% 50%% budget is paired with reward_v5's non-vanishing far-field running-cost
% gradient and is applied identically to both comparison arms.
cfg.rl.ppoIterations = 750;
cfg.rl.evaluateEvery = 25;
cfg.rl.policyLearnRate = 2e-4;
cfg.rl.valueLearnRate = 5e-4;
cfg.rl.entropyWeight = 0.004;
cfg.rl.initialLogStd = -1.0;
% Pure-RL curriculum: begin with low-altitude members of the same scenario
% family and expand to the complete nominal height range.  Evaluation always
% uses the untouched manifest distribution.
cfg.rl.curriculumFraction = 0.45;
% Iteration 1 starts 0.45--0.6 m above the pad (scale x nominal 4--8 m) so a
% random policy can produce enough genuine safe contacts to learn touchdown
% without a teacher. The planar forward-down marker camera initializes the
% UGV estimate at reset only from 0.40 m up (no marker in view below 0.35 m,
% validation of 20 seeds), so lower starts would begin blind and inhibited;
% 0.45 m also starts inside the final-descent band (enterHeight 0.5 m). The
% range then expands continuously to the nominal 4--8 m distribution. The 3D
% option restores its own start (landing2d.config.defaultSpatialConfig).
cfg.rl.initialHeightRange = [0.1125,1.00];
cfg.rl.curriculumStartHeight = 0.075;
% Planar descent-prefix curriculum (training episodes only, all methods). The
% forward-down camera cannot start a pad-relative episode below 0.40 m, while
% the downward camera of the original contract let random policies discover
% touchdown from 0.1--0.4 m. With probability p*(1-level) the causal reference
% driver (landing2d.probe.referenceDriver, common observation only) flies the
% start down to a handover height in [0.1,0.3] m, so the UGV estimate is
% initialized and the final-descent latch is engaged by real measurements;
% those prefix decisions are not policy transitions. A pilot run without it
% hovered in view until timeout for 950 iterations (0% train landing), while
% hovering scored -12 and a scripted landing +27 at curriculum level 0.
% Rewards, environment, supervisor and evaluation are unchanged; the 3D option
% removes these fields (landing2d.config.applySpatialDimension).
cfg.rl.descentPrefixProbability = 1.0;
cfg.rl.descentPrefixHandoverRange = [0.10,0.30];
% The prefix also hands over at a random time in [2,15] s (the reference driver
% lands in about 12 s), so policies start from tracked, speed-matched states at
% altitude after the UGV acceleration, and at least 30% of training episodes
% keep a prefix at full difficulty. Seed-1 PPO runs without these collapsed at
% curriculum level 0.7-0.9 into either hovering in view until timeout or losing
% the pad at 5-7 m after the UGV acceleration (safe abort 85-95%).
cfg.rl.descentPrefixMinProbability = 0.30;
cfg.rl.descentPrefixMaxTimeRange = [2,15];
% Training-episode draws (environment seed and case per episode) come from
% their own stream (rl.seed + offset, landing2d.rl.ppoTrain): methods with the
% same training seed train on the same episode sequence, however many samples
% each policy collects. The 3D option removes this field.
cfg.rl.episodeStreamSeedOffset = 52001;
cfg.rl.abortCurriculumFraction = 0.55;
cfg.rl.abortCurriculumStart = 12.0;
cfg.rl.motionCurriculumFraction = 0.65;
cfg.rl.motionCurriculumStartScale = 0.15;
% Successful windows can promote early. A later scheduled floor prevents a
% permanently stalled curriculum and guarantees nominal-task exposure.
% Planar contract: promotion needs 30% current-level landings in 3 windows,
% and 2 windows below 10% step the level back (landing2d.rl.advanceCurriculumLevel).
% With the former 10% promotion and no demotion, runs of both methods that were
% promoted from 0.6 to 0.9 while landing 9-11% collapsed (safe abort 28-47%)
% and stayed there until the floor forced level 1. The 3D option keeps 10%
% without demotion (landing2d.config.applySpatialDimension).
cfg.rl.curriculumMode = 'performance';
cfg.rl.curriculumLandingThreshold = 0.30;
cfg.rl.curriculumDemotionThreshold = 0.10;
cfg.rl.curriculumDemotionWindows = 2;
cfg.rl.curriculumStep = 0.10;
cfg.rl.curriculumRequiredWindows = 3;
% The last 20%% trains mostly on the complete 4--8 m distribution. One easy
% and one bridge episode per six-episode batch prevent touchdown forgetting.
cfg.rl.curriculumFloorStartFraction = 0.30;
cfg.rl.curriculumFullDifficultyFraction = 0.80;
cfg.rl.checkpointMinCurriculum = 1.0;
cfg.rl.curriculumEasyReplayFraction = 1/6;
cfg.rl.curriculumBridgeReplayFraction = 1/6;
% Replay episodes keep their easy start height and UGV motion, but take the
% touchdown limits, failure rewards and prolonged-loss threshold of the
% current level (landing2d.rl.trainingEpisodeConfig). Before, the easy replay
% kept 2x touchdown speeds and a -20 failure reward to the end of training,
% so a low-altitude state that is indistinguishable from the final descent of
% a nominal episode was SUCCESS in replay and UNSAFE_CONTACT at nominal.
% The 3D option removes this field (episode-level contract).
cfg.rl.curriculumReplayContract = 'current';
% The registered 12-D planar observation is already bounded. Freezing the
% policy coordinates avoids the non-stationarity introduced by running
% standardization in the plain MLP. The graph arm also remains unstandardized.
% Keep the disabled setting in the signature so old checkpoints are rejected;
% the 3D option removes the planar-only field.
cfg.rl.inputNormalization = struct('enabled',false,'clip',5,'epsilon',1e-2, ...
    'initialCount',1e-4);
cfg.rl.touchdownSpeedCurriculumScale = 2.0;
% Even easy touchdown episodes must experience the UGV acceleration event;
% otherwise the policy learns to land before the research event begins.
cfg.rl.curriculumStartT1Range = [0.10,0.30];
% Unsafe impact must never be an attractive shortcut to the +25 touchdown
% bonus.  The former -5 early penalty taught a fast dive that became -40 at
% nominal evaluation; retain some curriculum relaxation without reversing
% the safe/unsafe preference.
cfg.rl.unsafePenaltyCurriculumStart = -20.0;
cfg.rl.observationDim = cfg.experiment.observationSchema.dimension;
cfg.rl.actionInterval = round(cfg.experiment.policyDt/cfg.experiment.physicsDt);
cfg.rl.gamma = exp(-cfg.experiment.policyDt/ ...
    cfg.experiment.reward.discountTimeConstant);
cfg.rl.policyFile = 'ppo_low_level_planar_visibility_v2.mat';
cfg.graphState.useScratchSettings = false;
cfg.graphState.policyFile = 'ppo_context_planar_visibility_v2.mat';
% Planar context graphs are built from the 12-D common observation (the same
% o_t the baseline reads); the 3D option removes this field and keeps the
% packet-based graph (landing2d.config.applySpatialDimension).
cfg.graphState.observationSource = 'commonObservation';
% Node-feature version of that graph (landing2d.graphstate.observationGraph).
% Every node feature is a deterministic function of the registered vector.
cfg.graphState.observationFeatures = 'minimal_sensor_v1';
% Parameter-matched graph-only proposal: Actor and Critic receive only the
% grouped typed R-GAT embedding built from the same common observation as
% PPO. The original 16-D relation state is retained, while its parameter-
% dominant dense grouped readout is replaced by a channel x node factorized
% map. This yields a 16-D graph embedding without a raw observation bypass.
% Capacity is reallocated from the post-graph MLP: actor 38-37, critic 35-34.
% Actor + Critic contain exactly 6,101 trainable scalars, identical to plain
% PPO. There is no additive residual, state gate, or validation guard.
cfg.graphState.readout = 'grouped_factorized';
cfg.graphState.hiddenDim = 16;
cfg.graphState.graphDim = 16;
cfg.graphState.policyHiddenSizes = [38,37];
cfg.graphState.valueHiddenSizes = [35,34];
cfg.graphState.encoderLearnRate = 1e-4;
cfg.graphState.freezeStaticBackbone = false;
cfg.graphState.graphAdaptationWarmupFraction = 0;
cfg.graphState.preserveRawPolicyDuringGraphAdaptation = false;
cfg.graphState.pretrain.enabled = false;
cfg.scratchBaseline = true;
% Evaluation-only consistency settings (noise scales, fixed probes, command
% logs). Top-level, so they are outside the training signature and the task
% fingerprint.
cfg.consistency = landing2d.config.defaultConsistencyConfig();
end
