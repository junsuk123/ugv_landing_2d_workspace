function c = config(root)
% CONFIG Motion-coordinate residual v3; all four methods train on fresh seeds.
if nargin<1, root = landing2d.orchestration.projectRoot(); end
c = landing2d.residual_logits.config(root);
c.methodProfile = 'relational_residual_v3';
c.experiment.designVersion = 'relational_residual_v3';
c.graphState.encoderVersion = 'relational_residual_v3';
c.graphState.graphDim = 2;
c.graphState.actorMeanInitialization = 'zero_v1';
c.graphState.correctionCoordinates = 'masked_own_vx_v1';
c.graphState.policyHiddenSizes = [];
c.graphState.basePolicyHiddenSizes = 74;
c.outputDir = fullfile(root,'results','relational_residual_v3');
landing2d.config.validateConfig(c);
end
