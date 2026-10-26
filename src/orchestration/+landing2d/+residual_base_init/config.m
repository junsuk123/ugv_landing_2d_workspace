function c = config(root)
% CONFIG V4 single-factor base-output restoration; paired development first.
if nargin<1, root = landing2d.orchestration.projectRoot(); end
c = landing2d.residual_motion.config(root);
c.methodProfile = 'relational_residual_v4';
c.experiment.designVersion = 'relational_residual_v4';
c.graphState.encoderVersion = 'relational_residual_v4';
c.graphState.graphDim = 2;
c.graphState.actorMeanInitialization = 'random_base_zero_correction_v1';
c.graphState.correctionCoordinates = 'masked_own_vx_v1';
c.graphState.policyHiddenSizes = [];
c.graphState.basePolicyHiddenSizes = 74;
c.outputDir = fullfile(root,'results','relational_residual_v4');
landing2d.config.validateConfig(c);
end
