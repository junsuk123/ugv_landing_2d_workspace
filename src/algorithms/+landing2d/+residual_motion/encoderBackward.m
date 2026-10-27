function [g,dx] = encoderBackward(p,spec,c,dMu)
% Exact derivative. Base gradients are not multiplied by the correction gate.
% Correction-branch slopes come from the forward cache (correctionActivation).
optimizerState = landing2d.util.adamInit(p); g = optimizerState.m;
g.B2 = dMu*c.baseHidden'; g.b2 = sum(dMu,2);
dBase = (p.B2'*dMu).*(1-c.baseHidden.^2);
g.B1 = dBase*c.policyInput'; g.b1 = sum(dBase,2);
dx = p.B1'*dBase; dCoordinates = zeros(size(dx));
g.beta = sum(dMu.*c.correction,'all')*c.mix*(1-c.mix);
dCorrection = c.mix*dMu.*c.correctionSlope;
g.R = dCorrection*c.evidence'; g.br = sum(dCorrection,2);
dEvidence = p.R'*dCorrection;
if strcmp(spec.correctionType,'mlp')
    dHidden = dEvidence.*c.evidenceSlope;
    g.F = dHidden*c.correctionInput'; g.bf = sum(dHidden,2);
    dCoordinates = p.F'*dHidden;
    dx = dx+landing2d.residual_motion.motionCoordinatesBackward(dCoordinates,c.coordinateJacobian); return;
end
if isfield(spec,'correctionOperators')   % v8/C3 relation-typed operators
    [graphGrad,dCoordinates] = landing2d.residual_context.semanticGraphBackward(p,spec,c.semantic,dEvidence);
    for name = fieldnames(graphGrad)', g.(name{1}) = graphGrad.(name{1}); end
    dx = dx+landing2d.residual_motion.motionCoordinatesBackward(dCoordinates,c.coordinateJacobian); return;
end
B = c.B; d = spec.hiddenDim; N = 4;
dH = reshape(dEvidence,d,N,B); dH0 = zeros(d,N,B);
for l = spec.layers:-1:1
    layer = c.layers{l}; dPre = dH.*layer.slope;
    [dSource,relationGrad,dPrevious] = landing2d.minimal.dynamicBackward(dPre,layer.relation);
    dH0 = dH0+dSource;
    flat = reshape(dPre,d,N*B);
    g.W = g.W+relationGrad.W; g.a = g.a+relationGrad.a;
    g.W0 = g.W0+flat*reshape(layer.previous,d,N*B)';
    g.b = g.b+sum(flat,2);
    dH = dPrevious+reshape(p.W0'*flat,d,N,B);
end
dProjection = (dH+dH0).*c.H0Slope;
for i = 1:N
    index = spec.schema.observationIndices{i}; flat = reshape(dProjection(:,i,:),d,B);
    g.P(:,index) = flat*c.correctionInput(index,:)'; g.bp(:,i) = sum(flat,2);
    dCoordinates(index,:) = p.P(:,index)'*flat;
end
dx = dx+landing2d.residual_motion.motionCoordinatesBackward(dCoordinates,c.coordinateJacobian);
end
