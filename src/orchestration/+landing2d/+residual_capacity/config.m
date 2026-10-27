function d = config(root)
% CONFIG relational_residual_v7 (C2): capacity reallocation of the three residual arms.
% Goal reopened by the user on 2026-10-27 ("기존 일반화 목표 재개", autonomy up
% to confirmation). C1 (relational_residual_v6) failed its development gate;
% Codex (GO) keeps the registered C2 unchanged: on v5 (tanh, no C1 phi), the
% residual arms' base MLP width 74 -> 42, graph node width 8 -> 12 and
% Residual-MLP correction width 36 -> 68 (landing2d.residual_context.capacityEncoderInit).
% PPO (10-110-2, critic 10-55-1), the common raw critic, attention, the action
% tanh, observation, physics, sensors, reward_v5, PPO loss, training family,
% validation and budget are v5. Parameter counts 2095/2098/2093/2093.
% Evaluation: protocol v2. Development 461-465 x four methods (fresh); if the
% development gate passes, confirmation 431-450 x four methods on 9101-9200 (j = 1).
if nargin<1, root = landing2d.orchestration.projectRoot(); end
base = landing2d.bias_diagnostics.config(root);         % v5 + registered protocol v2
c = base.c;
c.graphState.basePolicyHiddenSizes = 42;
c.graphState.hiddenDim = 12;
c.graphState.correctionHiddenSize = 68;
c.outputDir = fullfile(root,'results','relational_residual_v7');
landing2d.config.validateConfig(c);
d = struct('version','relational_residual_v7','candidate','C2','root',root,'c',c,'v5',base.c, ...
    'outputDir',c.outputDir,'developmentSeeds',461:465,'confirmationSeeds',431:450, ...
    'methods',{{'ppo','residual_mlp_ppo','onto_rgat_ppo','shuffled_rgat_ppo'}}, ...
    'parameterCounts',[2095;2098;2093;2093], ...
    'developmentEnvironments',c.experiment.manifest.stressSeeds(1:100), ...
    'confirmationEnvironments',c.experiment.manifest.stressSeeds(101:200), ...
    'training',struct('concurrentRuns',8,'concurrentPool','threads'), ...
    'designDocument',fullfile(root,'docs','RELATIONAL_RESIDUAL_V7_KO.md'));
% Development gate: the C1 rule (landing2d.residual_soft.developmentGate, v5 rule
% for a registered seed list), unchanged.
d.developmentGate = struct('reached80',5,'selected80',5,'validationMedianMargin',.05, ...
    'unsafeMedianMargin',.02,'positiveOodMeanContrasts',3,'motionNoiseMeanDirection',true);
% Confirmation (only after a passed, re-verified development gate and a separate
% registration): round j = 1, alpha_j = 0.025, Bonferroni over three comparisons ->
% individual two-sided 99.1667% paired t intervals, df = 19. Goal met only if the
% TOSM-PPO and TOSM-Shuffled lower bounds are > 0 and the motion/noise landing,
% unsafe and aim means do not deteriorate versus PPO and Shuffled, with every check passed.
d.confirmation = struct('round',1,'alpha',0.025,'comparisons',3, ...
    'confidence',1-0.025/3,'primary',{{'ppo','shuffled_rgat_ppo'}});
% Budget and stop (Codex): C2 is the last registered candidate; failing this
% development or the confirmation ends the reopening as not achieved.
assert(isempty(intersect(d.developmentEnvironments,9101:9200)) ...
    && isequal(d.confirmationEnvironments,9101:9200),'landing2d:ResidualV7Seeds','Environment split changed.');
end
