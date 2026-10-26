function d = config(root)
% CONFIG Fixed settings of control_gain_audit_v1 (frozen v5 policies; no training).
% Question: does a uniformly stronger horizontal command of the same frozen
% policy improve the protocol-v2 unknown-acceleration cell, and does it cost
% dropout/noise robustness? Intervention at every decision:
%   a_x_norm = clip(k * tanh(mu_x), -1, 1),   a_z_norm = tanh(mu_z)   (unchanged)
% with k in {1, 2}; k = 1 must reproduce the stored protocol-v2 development
% episodes. Every choice below (gains, cells, seeds, aggregation, thresholds)
% was fixed by the Codex decision of 2026-10-26 before any rollout was read.
% Environment seeds: the already-opened development stress seeds 9001-9050.
% Confirmation environments 9101-9200 stay closed.
if nargin<1, root = landing2d.orchestration.projectRoot(); end
base = landing2d.bias_diagnostics.config(root);
d = struct('version','control_gain_audit_v1','root',root,'c',base.c, ...
    'outputDir',fullfile(root,'results','control_gain_audit_v1'), ...
    'trainSeeds',base.trainSeeds,'methods',{base.methods}, ...
    'v2Evaluation',base.v2Evaluation, ...
    'gains',[1,2],'environmentSeeds',9001:9050, ...
    'cells',{{'motion','ID';'motion','OOD';'dropout','ID';'dropout','OOD';'noise','ID';'noise','OOD'}}, ...
    'forbiddenEnvironmentSeeds',9101:9200);
% Reproduction of the stored v2 episodes at k = 1: outcomes exact, aim RMS
% within aimTolerance * max(1,|stored|).
d.reproduction = struct('aimTolerance',1e-9);
% Saturation of the applied horizontal command (reported, not a criterion).
d.saturationThreshold = 0.95;
% Aggregation: Delta = (k=2) - (k=1) per episode pair; per model the mean over
% the 50 environments (S, U in %p; E = AimErrorRMS_m in m); per training seed
% the equal-weight mean of the four methods; the five seed blocks are the
% independent units (two-sided 95% t interval, df = 4). Exploratory and
% descriptive: not a confirmatory test and not evidence of a TOSM advantage.
% Criteria (all in %p or m):
%   G  motion OOD: mean dS >= gainS & low > 0; mean dE <= gainE & high < 0;
%      dU high <= unsafeLimit; every method mean dS > 0 and dE < 0.
%   C  trade-off: G and, for dropout or noise, either
%      [dS_OOD mean <= -harmS & high < 0 and (dS_OOD - dS_ID) mean <= -didS & high < 0]
%      or [dU_OOD mean >= harmU & low > 0 and (dU_OOD - dU_ID) mean >= didU & low > 0],
%      with the worsening direction of that OOD metric in every method mean.
%   B  global low gain: G and motion ID mean dE <= gainE & high < 0 with every
%      method mean dE < 0, and in all six cells dS low >= -tolS and dU high <= unsafeLimit.
%   Otherwise only G: gain bottleneck in the unknown acceleration only; no G: mixed,
%   null or worse (recorded, never re-run with another gain).
d.criteria = struct('gainS',5,'gainE',-0.10,'unsafeLimit',2,'harmS',5,'didS',3, ...
    'harmU',2,'didU',2,'tolS',2,'confidence',0.95);
landing2d.gain_audit.checkSeeds(d);
end
