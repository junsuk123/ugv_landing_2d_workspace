function d = config(root)
% CONFIG response_gain_r1_v1 (D1): frozen Q2 response diagnostics, R1 versus v5.
% The same 489 policy-independent reference states, physical contrasts and
% probe code as inductive_bias_diagnostics_v1 (Q2) are applied to the 20
% acceleration_range_r1_v1 models and the 20 v5 models; no training, no
% checkpoint reselection, the R1 verdict is not changed. Design fixed by the
% Codex decision of 2026-10-26 (REVISE incorporated) before any probe:
%   primary   motion_v2 family (244 states), per-model state means of the gain
%             vector G = (RugvX, RposX, -RdroneX) (original signs reported too);
%             paired R1 - v5 per method and seed, equal-weight mean of the four
%             methods per seed (five seed blocks, df = 4); direction label per
%             metric from the Bonferroni two-sided 1 - 0.05/3 t interval:
%             low > 0 'increase in the reference direction', high < 0
%             'decrease in the reference direction', else 'no change detected';
%             95% intervals are reported as description
%   secondary training family (245 states), StaleDeltaX (valid stale states
%             counted), SaturatedX, Agree*, ratios to the reference driver
%             (same-family means; NA when the reference mean is 0)
%   branches  branchRollouts on 9001-9010 (motion OOD): normalized a_x +/-0.25
%             (+/-0.625 m/s^2 before the limit) added to the policy action and
%             clipped for 5 decisions; PolicyBestReturn (ties count as best) and
%             AdvantagePlus, paired on the keys reached by both models; reach
%             counts and per-policy totals reported; v5 reproduction PPO/421/9001
%   link      Spearman of the 20 model dRugvX (motion_v2) with the R1 motion OOD
%             dS (descriptive; methods mixed, seeds shared; no p value)
if nargin<1, root = landing2d.orchestration.projectRoot(); end
d = landing2d.bias_diagnostics.config(root);
d.version = 'response_gain_r1_v1';
d.outputDir = fullfile(root,'results','response_gain_r1_v1');
d.r1 = landing2d.accel_range.config(root);
d.r1Results = fullfile(root,'results','acceleration_range_r1_v1');
d.q2Results = fullfile(root,'results','inductive_bias_diagnostics_v1');
d.primaryFamily = "motion_v2";
d.primary = {'RugvX','RposX','RdroneXNeg'};
d.secondary = {'RugvX','RposX','RdroneX','RdroneXNeg','StaleDeltaX','SaturatedX', ...
    'AgreeUgvX','AgreeDroneX','AgreePosX','ReferenceRugvX','ReferenceRdroneX','ReferenceRposX', ...
    'ReferenceStaleDeltaX'};
d.confidence = 0.95; d.directionConfidence = 1-0.05/3;
d.branchReproduction = struct('MethodId','ppo','TrainSeed',421,'EnvironmentSeed',9001);
d.reproductionTolerance = 1e-9;
landing2d.bias_diagnostics.checkSeeds(d);
end
