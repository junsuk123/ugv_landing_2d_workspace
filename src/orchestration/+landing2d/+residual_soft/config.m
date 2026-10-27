function d = config(root)
% CONFIG relational_residual_v6 (C1): relation-symmetric non-saturating residual correction.
% Goal reopened by the user on 2026-10-27 ("기존 일반화 목표 재개", autonomy up
% to confirmation). Codex plan (GO): the only change from v5 is the activation
% of the three residual arms' correction branch,
%   phi(z) = 0.9 tanh(z) + 0.1 z     (landing2d.residual_motion.correctionActivation)
% at the node projection, every node update and the final correction (graph
% arms), or the hidden layer and the final correction (Residual-MLP). The base
% MLP, the common raw critic, attention, the action tanh, observation, physics,
% sensors, reward_v5, PPO, training family, validation and budget are v5;
% PPO is unchanged; parameter counts 2095/2098/2089/2089. The coefficient 0.1
% is fixed (no search). Evaluation: protocol v2 (generalization_v2_calibration).
% Development 451-455 x four methods (fresh); if the development gate passes,
% confirmation 431-450 x four methods on environments 9101-9200 (round j = 1).
if nargin<1, root = landing2d.orchestration.projectRoot(); end
base = landing2d.bias_diagnostics.config(root);         % v5 + registered protocol v2
c = base.c;
c.graphState.correctionActivation = 'soft_linear_v1';
c.outputDir = fullfile(root,'results','relational_residual_v6');
landing2d.config.validateConfig(c);
d = struct('version','relational_residual_v6','candidate','C1','root',root,'c',c,'v5',base.c, ...
    'outputDir',c.outputDir,'developmentSeeds',451:455,'confirmationSeeds',431:450, ...
    'methods',{{'ppo','residual_mlp_ppo','onto_rgat_ppo','shuffled_rgat_ppo'}}, ...
    'parameterCounts',[2095;2098;2089;2089], ...
    'developmentEnvironments',c.experiment.manifest.stressSeeds(1:100), ...
    'confirmationEnvironments',c.experiment.manifest.stressSeeds(101:200), ...
    'training',struct('concurrentRuns',8,'concurrentPool','threads'));
% Development gate (landing2d.residual_soft.developmentGate; v5 rule, seeds re-registered):
% every method Reached80 and selected validation >= 80% in 5/5; TOSM validation
% median >= PPO/MLP - 5%p and unsafe median <= +2%p; TOSM-PPO, TOSM-MLP and
% TOSM-Shuffled OOD mean differences all > 0; in motion and noise OOD, TOSM
% landing >=, unsafe <= and aim RMS <= each of the three (tolerance 1e-12).
% Three individual 98.3333% paired t intervals (df = 4) are reported, not gated.
d.developmentGate = struct('reached80',5,'selected80',5,'validationMedianMargin',.05, ...
    'unsafeMedianMargin',.02,'positiveOodMeanContrasts',3,'motionNoiseMeanDirection',true);
% Confirmation (only after a passed, re-verified development gate and a separate
% registration): round j = 1, alpha_j = 0.05/2^j = 0.025, Bonferroni over the
% three comparisons -> individual two-sided 1 - 0.025/3 (99.1667%) paired t
% intervals, df = 19. Goal met only if the TOSM-PPO and TOSM-Shuffled lower
% bounds are > 0 and the motion/noise landing, unsafe and aim means do not
% deteriorate versus PPO and Shuffled, with every check passed.
d.confirmation = struct('round',1,'alpha',0.025,'comparisons',3, ...
    'confidence',1-0.025/3,'primary',{{'ppo','shuffled_rgat_ppo'}});
% Budget and stop (Codex): at most C1 (451-455) then C2 (461-465); the first
% candidate passing development goes to the single confirmation; failing both
% developments or the confirmation ends the reopening as not achieved.
assert(isempty(intersect(d.developmentEnvironments,9101:9200)) ...
    && isequal(d.confirmationEnvironments,9101:9200),'landing2d:ResidualV6Seeds','Environment split changed.');
end
