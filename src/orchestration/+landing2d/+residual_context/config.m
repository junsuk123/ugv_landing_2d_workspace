function c = config(root)
% CONFIG V5 changes only the graph information paths; all common task paths stay.
if nargin<1, root = landing2d.orchestration.projectRoot(); end
c = landing2d.residual_base_init.config(root);
c.methodProfile = 'relational_residual_v5';
c.experiment.designVersion = 'relational_residual_v5';
c.graphState.encoderVersion = 'relational_residual_v5';
c.graphState.graphDim = 2;
c.graphState.actorMeanInitialization = 'random_base_zero_correction_v1';
c.graphState.correctionCoordinates = 'masked_own_vx_v1';
c.graphState.policyHiddenSizes = [];
c.graphState.basePolicyHiddenSizes = 74;
c.outputDir = fullfile(root,'results','relational_residual_v5');
c.graphState.topologyVersion = 'tosm4_context_v1';
landing2d.config.validateConfig(c);
end
