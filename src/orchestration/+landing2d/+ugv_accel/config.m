function d = config(root,jerkSpectralDensityX)
% CONFIG ugv_accel_h3_v1: hypothesis H3, a UGV acceleration estimate in the common observation.
% The v5 contract (landing2d.residual_context.config with the registered
% protocol-v2 evaluation) with ONE change of the common observation: the
% schema minimal_common_observation_v4_ugv_accel appends o11, the horizontal
% acceleration of a parallel constant-acceleration KF
% (landing2d.observation.updateUgvAcceleration), as signedScale(a_x, 1 m/s^2),
% 0 before that filter is initialized. o1-o10 and the constant-velocity KF are
% unchanged. Every arm reads the 11-D o_t (PPO 11 -> 110 -> 2, residual base
% 11 -> 74 -> 2, critic 11 -> 55 -> 1); the graph arms place o11 in
% TargetMotion with o4 (topology tosm4_context_accel_v1). Training family,
% validation, rewards, PPO and widths stay v5. Design: Codex decision of
% 2026-10-26; user approval "게이트 통과 시 학습까지".
% JERKSPECTRALDENSITYX: q_x of the CA KF [m^2/s^5]; the default is the value
% selected by the registered calibration (landing2d.ugv_accel.runGate).
if nargin<1 || isempty(root), root = landing2d.orchestration.projectRoot(); end
if nargin<2, jerkSpectralDensityX = selectedJerk(root); end
base = landing2d.bias_diagnostics.config(root);
v5 = base.c;
c = v5;
co = c.experiment.commonObservation;
co.schemaVersion = 'minimal_common_observation_v4_ugv_accel';
co.estimator.acceleration = struct('jerkSpectralDensity',[jerkSpectralDensityX,0.01], ...
    'initialAccelerationStd',[1,0.1],'observationScale',1.0);
c.experiment.commonObservation = co;
c.experiment.observationSchema = landing2d.observation.vectorSchema(co);
c.rl.observationDim = c.experiment.observationSchema.dimension;
c.graphState.topologyVersion = 'tosm4_context_accel_v1';
c.outputDir = fullfile(root,'results','ugv_accel_h3_v1');
landing2d.config.validateConfig(c);
d = struct('version','ugv_accel_h3_v1','root',root,'c',c,'v5',v5,'outputDir',c.outputDir, ...
    'trainSeeds',421:425,'methods',{{'ppo','residual_mlp_ppo','onto_rgat_ppo','shuffled_rgat_ppo'}}, ...
    'v5Evaluation',base.v2Evaluation,'environmentSeeds',v5.experiment.manifest.stressSeeds(1:100), ...
    'cells',{{'motion','ID';'motion','OOD';'dropout','ID';'dropout','OOD';'noise','ID';'noise','OOD'}}, ...
    'forbiddenEnvironmentSeeds',9101:9200,'training',struct('concurrentRuns',8,'concurrentPool','threads'), ...
    'parameterCounts',struct('ppo',2260,'residual_mlp_ppo',2263,'onto_rgat_ppo',2226,'shuffled_rgat_ppo',2226));
% Pre-training informativeness gate (TEST ONLY; landing2d.ugv_accel.runGate).
% Deterministic reference driver (landing2d.probe.referenceDriver, no driver
% noise). Calibration: validation seeds 2001-2020 x strata {CV, CA(training
% a2)} x noise {x1, x3}; per episode the MSE of (a_hat - a_pad) over all
% decisions (a_hat = 0 before initialization); q_x minimizes the equal-weight
% mean of the four strata seed means (ties -> smaller q). Gate, once, seeds
% 2021-2040 with the selected q_x:
%   families CA(training a2) x1 and CA(v2 motion a2 1.5-2.0) x1: window
%   [T1-0.5, T1+T2+0.5]; per episode Pearson r and NRMSE = RMS(a_hat - a)/RMS(a);
%   episode means r >= 0.5 and NRMSE <= 0.8; detection = second of two
%   consecutive decisions inside [T1, T1+T2) with sign(a_hat) = sign(a) and
%   |a_hat| >= |a|/2, delay = t - T1; share with delay <= min(0.5, T2/2) >= 0.8.
%   family CV x3: per-episode RMS of a_hat over initialized decisions, mean <= 0.3.
%   An incomplete window, an uninitialized estimate in the window or a constant
%   estimate counts as the zero-acceleration estimate (r = 0, NRMSE = 1); a
%   missing detection is a failure; an episode never initialized has RMS = Inf.
%   Any failed criterion: no training, no recalibration.
d.gate = struct('jerkGrid',[0.01,0.1,1,10],'jerkZ',0.01,'calibrationSeeds',2001:2020, ...
    'gateSeeds',2021:2040,'window',0.5,'minCorrelation',0.5,'maxNrmse',0.8, ...
    'detectionDelay',0.5,'detectionShare',0.8,'maxNoiseRms',0.3,'noiseScale',3, ...
    'outputDir',fullfile(c.outputDir,'gate'));
assert(isempty(intersect([d.gate.calibrationSeeds,d.gate.gateSeeds],d.forbiddenEnvironmentSeeds)) ...
    && all(ismember([d.gate.calibrationSeeds,d.gate.gateSeeds],v5.experiment.manifest.validationSeeds)), ...
    'landing2d:UgvAccelSeeds','The gate uses validation seeds only.');
end

function q = selectedJerk(root)
file = fullfile(root,'results','ugv_accel_h3_v1','gate','gate_result.json');
assert(isfile(file),'landing2d:UgvAccelGate', ...
    'Run landing2d.ugv_accel.runGate first (or pass q_x explicitly for the calibration).');
r = jsondecode(fileread(file));
assert(r.passed,'landing2d:UgvAccelGate','The informativeness gate failed; H3 training is not allowed.');
q = r.selectedJerkSpectralDensityX;
end
