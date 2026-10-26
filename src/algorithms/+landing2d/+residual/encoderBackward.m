function [grads,dPolicyInput] = encoderBackward(params,spec,cache,dZ)
% ENCODERBACKWARD Exact derivative through both raw and correction paths.
zero = landing2d.util.adamInit(params); grads = zero.m;
grads.lnScale = sum(dZ.*cache.normalized,2);
grads.lnBias = sum(dZ,2);
dNormalized = dZ.*params.lnScale;
dCombined = cache.inverseScale.*(dNormalized-mean(dNormalized,1) ...
    -cache.normalized.*mean(dNormalized.*cache.normalized,1));
grads.beta = sum(dCombined.*cache.correction,'all')*cache.mix*(1-cache.mix);
dBase = dCombined.*(1-cache.base.^2);
grads.Pb = dBase*cache.policyInput'; grads.bb = sum(dBase,2);
dPolicyInput = params.Pb'*dBase;
dCorrection = cache.mix*dCombined.*(1-cache.correction.^2);
grads.R = dCorrection*cache.evidence'; grads.br = sum(dCorrection,2);
dEvidence = params.R'*dCorrection;
if strcmp(spec.correctionType,'mlp')
    dHidden = dEvidence.*(1-cache.evidence.^2);
    grads.F = dHidden*cache.policyInput'; grads.bf = sum(dHidden,2);
    dPolicyInput = dPolicyInput+params.F'*dHidden;
    return;
end
B = cache.B; d = spec.hiddenDim; N = spec.nNodes;
dH = reshape(dEvidence,d,N,B); dH0 = zeros(d,N,B);
for l = spec.layers:-1:1
    layer = cache.layers{l}; dPre = dH.*(1-layer.H.^2);
    [dSource,relationGrad,dPrevious] = landing2d.minimal.dynamicBackward(dPre,layer.relation);
    dH0 = dH0+dSource;
    flat = reshape(dPre,d,N*B);
    grads.W = grads.W+relationGrad.W; grads.a = grads.a+relationGrad.a;
    grads.W0 = grads.W0+flat*reshape(layer.previous,d,N*B)';
    grads.b = grads.b+sum(flat,2);
    dH = dPrevious+reshape(params.W0'*flat,d,N,B);
end
dProjection = (dH+dH0).*(1-cache.H0.^2);
for i = 1:N
    index = spec.schema.observationIndices{i};
    flat = reshape(dProjection(:,i,:),d,B);
    grads.P(:,index) = flat*cache.policyInput(index,:)';
    grads.bp(:,i) = sum(flat,2);
    dPolicyInput(index,:) = dPolicyInput(index,:)+params.P(:,index)'*flat;
end
end
