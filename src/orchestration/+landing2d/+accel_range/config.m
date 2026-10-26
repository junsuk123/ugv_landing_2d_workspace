function d = config(root)
% CONFIG acceleration_range_r1_v1: hypothesis 2, the training UGV acceleration range only.
% Independent variable: training CA a2Range [0.3,0.8] -> [0.3,1.4] m/s^2 (uniform).
% Everything else is the frozen v5 contract: CV probability, T1/T2, initial
% conditions, physics, sensors, 10-D observation, reward_v5, actions, models,
% initialization, PPO and the 750 x 6 budget. Validation (checkpoint
% selection, validation seeds 2001-2200) stays on the v5 family through
% experiment.validationScenario; the evaluation environments are the v5 /
% protocol-v2 cells (landing2d.accel_range.evaluationRuns), never the new
% training family. Seeds 421-425 x four methods train fresh; the v5 models
% of the same method and seed are the paired controls. Design and criteria:
% Codex decision of 2026-10-26 (GO), fixed before training.
if nargin<1, root = landing2d.orchestration.projectRoot(); end
base = landing2d.bias_diagnostics.config(root);         % v5 + registered protocol v2
v5 = base.c;
c = v5;
c.experiment.validationScenario = v5.experiment.scenario;
c.experiment.scenario.a2Range = [0.3,1.4];
c.outputDir = fullfile(root,'results','acceleration_range_r1_v1');
landing2d.config.validateConfig(c);
d = struct('version','acceleration_range_r1_v1','root',root,'c',c,'v5',v5, ...
    'outputDir',c.outputDir,'trainSeeds',421:425, ...
    'methods',{{'ppo','residual_mlp_ppo','onto_rgat_ppo','shuffled_rgat_ppo'}}, ...
    'v5Evaluation',base.v2Evaluation, ...
    'environmentSeeds',v5.experiment.manifest.stressSeeds(1:100), ...
    'cells',{{'motion','ID';'motion','OOD';'dropout','ID';'dropout','OOD';'noise','ID';'noise','OOD'}}, ...
    'forbiddenEnvironmentSeeds',9101:9200, ...
    'training',struct('concurrentRuns',8,'concurrentPool','threads'));
% Paired differences new - v5 per (method, seed, cell, environment): S landing,
% U unsafe contact [%p]. Per model the mean over 100 environments, per seed the
% equal-weight mean of the four methods (seed block, the unit); two-sided
% t intervals over five blocks (df = 4).
%   L  every method: Reached80 and selected validation landing >= 80% in 5/5 seeds
%   G  motion OOD seed-block mean dS >= gainS and 95% low > 0
%   K  G and every method's motion OOD dS 95% low > 0 (common improvement)
%   N  every method, all six cells: dS 95% low >= -marginS, dU 95% high <= marginU
%   H  seed blocks, noise or dropout OOD: dS <= -harmS with riskConfidence high < 0,
%      or dU >= harmU with riskConfidence low > 0 (four risk comparisons)
% Verdict: no L -> training_failure; L,G,H -> trade_off_supported;
% L,G,N -> improved_within_registered_margins; L,G -> gain_with_unresolved_risk;
% L without G -> insufficient_evidence_of_improvement. K alone licenses the
% word "common". No verdict is a TOSM advantage or the closed goal.
d.criteria = struct('reached80',5,'selected80',5,'gainS',5,'marginS',2,'marginU',2, ...
    'harmS',5,'harmU',2,'confidence',0.95,'riskConfidence',0.9875);
landing2d.accel_range.checkSeeds(d);
end
