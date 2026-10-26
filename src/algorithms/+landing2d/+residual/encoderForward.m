function [z,cache] = encoderForward(params,spec,policyInput)
% ENCODERFORWARD z=LN(tanh(Pb*o+bb)+sigmoid(beta)*tanh(correction(o))).
B = size(policyInput,2); d = spec.hiddenDim; N = spec.nNodes;
assert(size(policyInput,1)==10 && all(isfinite(policyInput),'all'), ...
    'landing2d:ResidualInput','Expected finite common-observation columns.');
base = tanh(params.Pb*policyInput+params.bb);
cache = struct('B',B,'policyInput',policyInput,'base',base);
if strcmp(spec.correctionType,'graph')
    H0 = zeros(d,N,B);
    for i = 1:N
        index = spec.schema.observationIndices{i};
        H0(:,i,:) = reshape(tanh(params.P(:,index)*policyInput(index,:) ...
            +params.bp(:,i)),d,1,B);
    end
    H = H0; layers = cell(1,spec.layers);
    for l = 1:spec.layers
        previous = H;
        [Z,relation] = landing2d.minimal.dynamicForward(H0,params.W,params.a,spec.T,H);
        H = reshape(tanh(reshape(Z,d,N*B)+params.W0*reshape(H,d,N*B)+params.b),d,N,B);
        layers{l} = struct('previous',previous,'H',H,'relation',relation);
    end
    evidence = reshape(H,d*N,B);
    cache.H0 = H0; cache.layers = layers;
    cache.cache1 = layers{1}.relation;
else
    evidence = tanh(params.F*policyInput+params.bf);
end
correction = tanh(params.R*evidence+params.br);
mix = 1/(1+exp(-params.beta));
combined = base+mix*correction;
centered = combined-mean(combined,1);
inverseScale = 1./sqrt(mean(centered.^2,1)+spec.layerNormEpsilon);
normalized = centered.*inverseScale;
z = params.lnScale.*normalized+params.lnBias;
cache.evidence = evidence; cache.correction = correction; cache.mix = mix;
cache.normalized = normalized; cache.inverseScale = inverseScale;
end
