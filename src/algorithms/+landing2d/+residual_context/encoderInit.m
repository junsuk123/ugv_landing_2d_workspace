function [p,spec] = encoderInit(gs,rs,baseRs)
% ENCODERINIT Preserve every V4 parameter and draw; replace fixed topology only.
if nargin<3, baseRs = rs; end
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
