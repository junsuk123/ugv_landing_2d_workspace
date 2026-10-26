function [g,dx] = encoderBackward(p,spec,c,dMu)
% Exact derivative. Base gradients are not multiplied by the correction gate.
optimizerState = landing2d.util.adamInit(p); g = optimizerState.m;
g.B2 = dMu*c.baseHidden'; g.b2 = sum(dMu,2);
dBase = (p.B2'*dMu).*(1-c.baseHidden.^2);
g.B1 = dBase*c.policyInput'; g.b1 = sum(dBase,2);
dx = p.B1'*dBase;
g.beta = sum(dMu.*c.correction,'all')*c.mix*(1-c.mix);
dCorrection = c.mix*dMu.*(1-c.correction.^2);
g.R = dCorrection*c.evidence'; g.br = sum(dCorrection,2);
dEvidence = p.R'*dCorrection;
if strcmp(spec.correctionType,'mlp')
    dHidden = dEvidence.*(1-c.evidence.^2);
    g.F = dHidden*c.policyInput'; g.bf = sum(dHidden,2);
    dx = dx+p.F'*dHidden; return;
end
B = c.B; d = 8; N = 4;
dH = reshape(dEvidence,d,N,B); dH0 = zeros(d,N,B);
for l = spec.layers:-1:1
    layer = c.layers{l}; dPre = dH.*(1-layer.H.^2);
    [dSource,relationGrad,dPrevious] = landing2d.minimal.dynamicBackward(dPre,layer.relation);
    dH0 = dH0+dSource;
    flat = reshape(dPre,d,N*B);
    g.W = g.W+relationGrad.W; g.a = g.a+relationGrad.a;
    g.W0 = g.W0+flat*reshape(layer.previous,d,N*B)';
    g.b = g.b+sum(flat,2);
    dH = dPrevious+reshape(p.W0'*flat,d,N,B);
end
dProjection = (dH+dH0).*(1-c.H0.^2);
for i = 1:N
    index = spec.schema.observationIndices{i}; flat = reshape(dProjection(:,i,:),d,B);
    g.P(:,index) = flat*c.policyInput(index,:)'; g.bp(:,i) = sum(flat,2);
    dx(index,:) = dx(index,:)+p.P(:,index)'*flat;
end
end
