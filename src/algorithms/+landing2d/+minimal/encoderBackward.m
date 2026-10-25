function [grads,dPolicyInput] = encoderBackward(params,spec,cache,dG)
% ENCODERBACKWARD Exact derivative; v3.1 accumulates both hops into shared weights.
B = cache.B; N = spec.nNodes; d = spec.hiddenDim;
dH = zeros(d,N,B); dH(:,spec.T.goalNode,:) = reshape(dG,d,1,B);
if ismember(spec.encoderVersion,{'rgat_minimal_v2','rgat_minimal_v3'})
    zero = landing2d.util.adamInit(params); grads = zero.m;
    dEvidence = zeros(d,N,B);
    for k = spec.layers:-1:1
        layer = cache.layers{k}; preH = dH.*(1-layer.H.^2);
        if strcmp(spec.encoderVersion,'rgat_minimal_v3')
            [dSource,relationGrad,dPrevious] = landing2d.minimal.dynamicBackward(preH,layer.relation);
            dEvidence = dEvidence+dSource;
        else
            [dPrevious,relationGrad] = landing2d.minimal.dynamicBackward(preH,layer.relation);
        end
        flat = reshape(preH,d,N*B);
        grads.W = grads.W+relationGrad.W;
        grads.a = grads.a+relationGrad.a;
        grads.W0 = grads.W0+flat*reshape(layer.previous,d,N*B)';
        grads.b = grads.b+sum(flat,2);
        dH = dPrevious+reshape(params.W0'*flat,d,N,B);
    end
    if strcmp(spec.encoderVersion,'rgat_minimal_v3'), dH = dH+dEvidence; end
    preProjection = reshape(dH,d,N*B).*(1-cache.H0.^2);
    grads.P = preProjection*cache.Xf'; grads.bp = sum(preProjection,2);
    dPolicyInput = reshape(params.P'*preProjection,spec.inDim*N,B);
    return;
end
preH = dH.*(1-cache.H.^2);
[dH0,relationGrad] = landing2d.rgat.relationBackward(preH,cache.cache1);
flat = reshape(preH,d,N*B);
grads.W = relationGrad.W;
grads.a = sum(relationGrad.a,3);
grads.W0 = flat*cache.H0';
grads.b = sum(flat,2);
preProjection = (reshape(dH0,d,N*B)+params.W0'*flat).*(1-cache.H0.^2);
grads.P = preProjection*cache.Xf';
grads.bp = sum(preProjection,2);
dPolicyInput = reshape(params.P'*preProjection,spec.inDim*N,B);
grads = orderfields(grads,params);
end
