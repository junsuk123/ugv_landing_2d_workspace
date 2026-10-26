function c = config(root)
% CONFIG Direct-mean residual v2; all four methods train on fresh seeds.
if nargin<1, root = landing2d.orchestration.projectRoot(); end
c = landing2d.residual.config(root);
c.methodProfile = 'relational_residual_v2';
c.experiment.designVersion = 'relational_residual_v2';
c.graphState.encoderVersion = 'relational_residual_v2';
c.graphState.graphDim = 2;
c.graphState.policyHiddenSizes = [];
c.graphState.basePolicyHiddenSizes = 74;
c.outputDir = fullfile(root,'results','relational_residual_v2');
landing2d.config.validateConfig(c);
end
