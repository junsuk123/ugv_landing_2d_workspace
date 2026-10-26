function c = config(root,version)
% CONFIG Active compact study; the existing 2D physical and PPO contracts stay.
if nargin<1, root = landing2d.orchestration.projectRoot(); end
if nargin<2, version = 'v31'; end
assert(ismember(version,{'v3','v31','v32','v33'}),'landing2d:MinimalVersion','Use v3, v31, v32 or v33 (development candidate).');
c = landing2d.config.primaryConfig(root);
expected = {'relative_x','relative_height','relative_vx','ugv_vx','drone_vz', ...
    'drone_sinTheta','drone_cosTheta','drone_pitchRate','ugv_visionUpdated','ugv_visionAge'};
assert(isequal(c.experiment.observationSchema.names(:)',expected), ...
    'landing2d:MinimalObservation','Observation order changed; migrate the named node partition.');
c.experiment.designVersion = 'minimal_relational_v3';
c.outputDir = fullfile(root,'results','minimal_v3');
c.rl.baselinePolicyHiddenSizes = 58;
c.rl.baselineValueHiddenSizes = 55;
encoderLearnRate = c.graphState.encoderLearnRate;
% 371 parameters per encoder; graph heads 32/32; total 1,419 in every arm.
c.graphState = struct('stateRepresentation','baseline', ...
    'encoderVersion','rgat_minimal_v1','observationSource','commonObservation', ...
    'observationFeatures','tosm4_v1','readout','relative_state', ...
    'attentionMode','input_dependent_v1','hiddenDim',8,'graphDim',8, ...
    'relationDim',3,'policyHiddenSizes',32,'valueHiddenSizes',32, ...
    'encoderLearnRate',encoderLearnRate);
if ismember(version,{'v31','v32','v33'})
    c.outputDir = fullfile(root,'results',['minimal_',version]);
    c.graphState.encoderVersion = 'rgat_minimal_v2';
    c.graphState.attentionMode = 'dynamic_joint_v1';
end
if ismember(version,{'v32','v33'}), c.graphState.encoderVersion = 'rgat_minimal_v3'; end
if strcmp(version,'v33'), c.graphState.relationInitialization = 'shared_semantic_v1'; end
% Evaluation contract is unchanged between v3 and v3.1; outside signatures.
c.evaluation.protocolVersion = 'minimal_generalization_v1';
c.evaluation.generalization.conditions = {'motion','dropout','noise'};
c.evaluation.generalization.oodDropoutDuration = [1.2,2.0];
c.evaluation.generalization.seedOffset = 0; % development 9001:9100; confirmation +100
c.evaluation.generalization.phase = 'development';
landing2d.config.validateConfig(c);
end
