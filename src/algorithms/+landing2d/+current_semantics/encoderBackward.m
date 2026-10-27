function [g,dx] = encoderBackward(p,spec,c,dMu)
% ENCODERBACKWARD Exact derivatives through the current-only semantic actor.
% Shared message/root weights receive the SUM from both computational hops.
if strcmp(c.mode,'baseline')
    g = struct(); dx = dMu; return;
end
g = struct();
for name = fieldnames(p)', g.(name{1}) = zeros(size(p.(name{1}))); end
g.A2 = dMu*c.headHidden'; g.c2 = sum(dMu,2);
dHidden = (p.A2'*dMu).*(1-c.headHidden.^2);
g.A1 = dHidden*c.headInput'; g.c1 = sum(dHidden,2);
dInput = p.A1'*dHidden;
if strcmp(spec.encoderMode,'semantic_mlp')
    dx = chainFeatures(c.featureJacobian,dInput); return;
end
d = spec.hiddenDim; N = spec.nNodes; B = c.B;
dx = dInput(1:10,:);
dH = zeros(d,N,B); dH(:,spec.goalNode,:) = reshape(dInput(11:end,:),d,1,B);
for l = spec.layers:-1:1
    layer = c.layers{l}; dPre = dH.*(1-layer.H.^2);
    flat = reshape(dPre,d,N*B);
    g.W0 = g.W0+flat*reshape(layer.previous,d,N*B)';
    g.b = g.b+sum(flat,2);
    [dPrevious,relationGrad] = landing2d.minimal.dynamicBackward(dPre,layer.relation);
    g.W = g.W+relationGrad.W; g.a = g.a+relationGrad.a;
    dH = dPrevious+reshape(p.W0'*flat,d,N,B);
end
dProjection = reshape(dH.*(1-c.H0.^2),d,N*B);
g.P = dProjection*reshape(c.X,spec.inputFeatureDim,N*B)';
g.bp = sum(dProjection,2);
dX = reshape(p.P'*dProjection,spec.inputFeatureDim*N,B);
dPhi = dX(spec.schema.activeLinearIndices,:);
dx = dx+chainFeatures(c.featureJacobian,dPhi);
end

function dx = chainFeatures(J,dPhi)
B = size(dPhi,2); dx = zeros(10,B);
for b = 1:B, dx(:,b) = J(:,:,b)'*dPhi(:,b); end
end
