function d = config(root)
% CONFIG Fixed settings of inductive_bias_diagnostics_v1 (docs/INDUCTIVE_BIAS_DIAGNOSTICS_KO.md).
% Frozen v5 development policies 421-425 x four methods; no training, no reward change.
% Every analysis choice is fixed here before any diagnostic output is read.
% Environment seeds: reference states on the test split (policy-independent
% reference driver) and closed-loop rollouts on the already-opened development
% stress seeds 9001-9100. Confirmation environments 9101-9200 stay closed.
if nargin<1, root = landing2d.orchestration.projectRoot(); end
c = landing2d.residual_context.config(root);
c.figureVisible = false;
registration = jsondecode(fileread(fullfile(root,'results','generalization_v2_calibration', ...
    'protocol_registration.json')));
g = c.evaluation.generalization;
g.oodA2Range = registration.selected.motion(:)';
g.oodDropoutDuration = registration.selected.dropout(:)';
g.oodNoiseScale = registration.selected.noise;
g.seedOffset = 0; g.phase = 'development';
c.evaluation.generalization = g;
c.evaluation.protocolVersion = 'minimal_generalization_v2';
landing2d.config.validateConfig(c);
evaluation = fullfile(root,'results','relational_residual_v5','generalization_v2');
d = struct('version','inductive_bias_diagnostics_v1','root',root,'c',c, ...
    'outputDir',fullfile(root,'results','inductive_bias_diagnostics_v1'), ...
    'trainSeeds',421:425, ...
    'methods',{{'ppo','residual_mlp_ppo','onto_rgat_ppo','shuffled_rgat_ppo'}}, ...
    'v2Evaluation',fullfile(evaluation,'development','s421-422-423-424-425'), ...
    'ablationSummary',fullfile(evaluation,'correction_diagnostic','summary.json'));
% Policy-independent states: the causal reference driver flies the training
% scenario family and the v2 motion-OOD family; the sensing chain is replayed.
d.reference = struct('seeds',3001:3010,'stride',5,'families',{{'training','motion_v2'}}, ...
    'noiseReplicates',4,'noiseSeedStride',c.evaluation.probes.noiseSeedStride, ...
    'staleAge',c.evaluation.probes.staleAge);
% Physical perturbations act on the common-observation structure O (then the
% registered toVector); arbitrary perturbations act on single o_t entries.
% o9 (visionUpdated) is binary and analysed only as the fresh/stale replay.
d.perturbation = struct('ugvVelocity',0.1,'droneVelocity',0.1,'ugvPosition',0.1, ...
    'finiteDifference',1e-4,'jacobianInputs',[1:8,10]);
d.classes = struct('fovBoundaryFraction',0.8,'nearContactHeight',1.0);
d.rollout = struct('seeds',9001:9020, ...
    'cells',{{'motion','ID';'motion','OOD';'dropout','ID';'dropout','OOD'}});
% Paired branches from an exact environment snapshot: the frozen policy's own
% action versus +/-0.25 normalized a_x held for 0.5 s, then the same policy.
d.branch = struct('seeds',9001:9010,'factor','motion','shift','OOD', ...
    'points',{{'accelerationStart','accelerationMiddle','afterAcceleration'}}, ...
    'deltaAx',[-0.25,0.25],'holdDecisions',5,'aimHorizon',3.0);
d.typingSwap = struct('seeds',9001:9020,'factor','motion','shift','OOD');
d.saturationThreshold = 0.95;
d.contrasts = {'onto_rgat_ppo','shuffled_rgat_ppo';'onto_rgat_ppo','ppo'; ...
    'onto_rgat_ppo','residual_mlp_ppo';'shuffled_rgat_ppo','residual_mlp_ppo'};
d.forbiddenEnvironmentSeeds = 9101:9200;
landing2d.bias_diagnostics.checkSeeds(d);
end
