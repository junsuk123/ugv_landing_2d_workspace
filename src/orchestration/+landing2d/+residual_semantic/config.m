function d = config(root)
% CONFIG relational_residual_v8 (C3): relation-typed operators in the graph correction.
% After C1 (v6) and C2 (v7) failed their development gates, the user asked on
% 2026-10-27 that Claude judge and continue modifying until Codex is available
% again ("코덱스 한도 복원되기 전까지 너가 판단해서 수정해줘"; also: a relation
% shuffle is expected to work worse). Claude's decision (Codex unavailable):
% on v5 with tanh, the relation of an edge fixes its operator
% (landing2d.residual_context.semanticGraphForward):
%   qualifiesEstimate  modulation of the destination, 1 + tanh(W_q h_src + b_q)
%   informsMotion      additive attention message, no squashing on the sum
%   self               additive attention message (root update tanh(W0 h + b))
% with the RelativeState goal node as the only graph readout, so every graph
% input reaches the action through typed edges. All three residual arms start
% with beta = 0 (sigmoid 0.5) instead of -2; base width 77 and MLP correction
% width 32 keep the parameter counts 2095/2085/2087/2087 (max difference 0.48%).
% PPO, the common raw critic, observation, physics, sensors, reward_v5, PPO
% loss, training family, validation and budget are v5. Evaluation: protocol v2.
% Development 471-475 x four methods (fresh); if the development gate passes,
% confirmation 431-450 x four methods on 9101-9200 (round j = 1).
if nargin<1, root = landing2d.orchestration.projectRoot(); end
base = landing2d.bias_diagnostics.config(root);         % v5 + registered protocol v2
c = base.c;
c.graphState.correctionOperators = 'semantic_v1';
c.graphState.readout = 'goal_node';
c.graphState.basePolicyHiddenSizes = 77;
c.graphState.hiddenDim = 8;
c.graphState.correctionHiddenSize = 32;
c.graphState.betaInit = 0;
c.outputDir = fullfile(root,'results','relational_residual_v8');
landing2d.config.validateConfig(c);
d = struct('version','relational_residual_v8','candidate','C3','root',root,'c',c,'v5',base.c, ...
    'outputDir',c.outputDir,'developmentSeeds',471:475,'confirmationSeeds',431:450, ...
    'methods',{{'ppo','residual_mlp_ppo','onto_rgat_ppo','shuffled_rgat_ppo'}}, ...
    'parameterCounts',[2095;2085;2087;2087], ...
    'developmentEnvironments',c.experiment.manifest.stressSeeds(1:100), ...
    'confirmationEnvironments',c.experiment.manifest.stressSeeds(101:200), ...
    'training',struct('concurrentRuns',8,'concurrentPool','threads'), ...
    'designDocument',fullfile(root,'docs','RELATIONAL_RESIDUAL_V8_KO.md'));
% Development gate: the v5 rule (landing2d.residual_soft.developmentGate), unchanged.
d.developmentGate = struct('reached80',5,'selected80',5,'validationMedianMargin',.05, ...
    'unsafeMedianMargin',.02,'positiveOodMeanContrasts',3,'motionNoiseMeanDirection',true);
% Confirmation (only after a passed, re-verified development gate and a separate
% registration): round j = 1, alpha_j = 0.025, Bonferroni over three comparisons ->
% individual two-sided 99.1667% paired t intervals, df = 19. Goal met only if the
% TOSM-PPO and TOSM-Shuffled lower bounds are > 0 and the motion/noise landing,
% unsafe and aim means do not deteriorate versus PPO and Shuffled, with every check passed.
d.confirmation = struct('round',1,'alpha',0.025,'comparisons',3, ...
    'confidence',1-0.025/3,'primary',{{'ppo','shuffled_rgat_ppo'}});
% Budget (Claude, until Codex returns): at most C3 (471-475) and one further
% candidate C4 (481-485, defined and registered before its training); the first
% candidate passing development goes to the single confirmation.
assert(isempty(intersect(d.developmentEnvironments,9101:9200)) ...
    && isequal(d.confirmationEnvironments,9101:9200),'landing2d:ResidualV8Seeds','Environment split changed.');
end
