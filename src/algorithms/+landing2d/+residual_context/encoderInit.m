function [p,spec] = encoderInit(gs,rs,baseRs)
% ENCODERINIT Preserve every V4 parameter and draw; replace fixed topology only.
% gs.correctionActivation (v6/C1, optional) selects the correction-branch
% activation (landing2d.residual_motion.correctionActivation); parameters and
% random draws are unchanged.
% gs.correctionHiddenSize (v7/C2) selects the registered capacity widths
% (landing2d.residual_context.capacityEncoderInit); gs.correctionOperators (v8/C3)
% the relation-typed operators (landing2d.residual_context.semanticEncoderInit).
if nargin<3, baseRs = rs; end
if strcmp(gs.topologyVersion,'tosm4_context_accel_v1')
    [p,spec] = landing2d.residual_context.accelerationEncoderInit(gs,rs,baseRs);
elseif isfield(gs,'correctionOperators')
    [p,spec] = landing2d.residual_context.semanticEncoderInit(gs,rs,baseRs);
elseif isfield(gs,'correctionHiddenSize')
    [p,spec] = landing2d.residual_context.capacityEncoderInit(gs,rs,baseRs);
else
    unperturbed = gs;
    if isfield(unperturbed,'relationPerturbation'), unperturbed=rmfield(unperturbed,'relationPerturbation'); end
    [p,spec] = landing2d.residual_base_init.encoderInit(unperturbed,rs,baseRs);
    spec.encoderVersion = 'relational_residual_v5';
    if strcmp(gs.correctionType,'graph')
        [schema,T] = landing2d.residual_context.schema();
        [schema,T,graph] = landing2d.rgat.applyRelationPerturbation(schema,T,gs);
        spec.schema = schema; spec.T = T; spec.graph = graph;
    end
end
if isfield(gs,'correctionActivation'), spec.correctionActivation = gs.correctionActivation; end
end
