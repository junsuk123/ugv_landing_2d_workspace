function [mu,cache] = encoderForward(p,spec,o)
% Direct mean correction: the base actor has its own unchanged output path.
assert(size(o,1)==10 && all(isfinite(o),'all'));
B = size(o,2); d = 8; N = 4;
[correctionInput,coordinateJacobian] = landing2d.residual_motion.motionCoordinates(o);
baseHidden = tanh(p.B1*o+p.b1);
baseMean = p.B2*baseHidden+p.b2;
cache = struct('policyInput',o,'B',B,'baseHidden',baseHidden,'baseMean',baseMean, ...
    'correctionInput',correctionInput,'coordinateJacobian',coordinateJacobian);
if strcmp(spec.correctionType,'graph')
    H0 = zeros(d,N,B);
    for i = 1:N
        index = spec.schema.observationIndices{i};
        H0(:,i,:) = reshape(tanh(p.P(:,index)*correctionInput(index,:)+p.bp(:,i)),d,1,B);
    end
    H = H0; layers = cell(1,spec.layers);
    for l = 1:spec.layers
        previous = H;
        [Z,relation] = landing2d.minimal.dynamicForward(H0,p.W,p.a,spec.T,H);
        H = reshape(tanh(reshape(Z,d,N*B)+p.W0*reshape(H,d,N*B)+p.b),d,N,B);
        layers{l} = struct('previous',previous,'H',H,'relation',relation);
    end
    evidence = reshape(H,d*N,B);
    cache.H0 = H0; cache.layers = layers; cache.cache1 = layers{1}.relation;
else
    evidence = tanh(p.F*correctionInput+p.bf);
end
correction = tanh(p.R*evidence+p.br);
mix = 1/(1+exp(-p.beta));
mu = baseMean+mix*correction;
cache.evidence = evidence; cache.correction = correction; cache.mix = mix;
end
