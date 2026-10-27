function [mu,cache] = encoderForward(p,spec,o)
% ENCODERFORWARD Current 10-D input -> feature MLP or two shared graph hops.
assert(size(o,1)==10 && all(isfinite(o),'all'),'landing2d:CurrentSemanticsObservation', ...
    'Expected finite current 10-D observations.');
if strcmp(spec.mode,'baseline')
    mu = o; cache = struct('mode','baseline'); return;
end
needCache = nargout>1;
if needCache
    [phi,X,~,J] = landing2d.current_semantics.features(o,spec.featureConstants);
else
    [phi,X] = landing2d.current_semantics.features(o,spec.featureConstants);
end
B = size(o,2);
if needCache
    cache = struct('mode','current_semantics_actor','encoderMode',spec.encoderMode, ...
        'o',o,'phi',phi,'X',X,'featureJacobian',J,'B',B);
end
if strcmp(spec.encoderMode,'semantic_mlp')
    input = phi;
else
    d = spec.hiddenDim; N = spec.nNodes;
    H0 = reshape(tanh(p.P*reshape(X,spec.inputFeatureDim,N*B)+p.bp),d,N,B);
    H = H0;
    if needCache, layers = cell(1,spec.layers); end
    for l = 1:spec.layers
        previous = H;
        if needCache
            [Z,relation] = landing2d.minimal.dynamicForward(previous,p.W,p.a,spec.T);
        else
            Z = landing2d.minimal.dynamicForward(previous,p.W,p.a,spec.T);
        end
        H = reshape(tanh(reshape(Z,d,N*B)+p.W0*reshape(previous,d,N*B)+p.b),d,N,B);
        if needCache, layers{l} = struct('previous',previous,'H',H,'relation',relation); end
    end
    goal = reshape(H(:,spec.goalNode,:),d,B);
    input = [o;goal];
    if needCache
        cache.H0 = H0; cache.layers = layers;
        cache.cache1 = layers{1}.relation;
    end
end
hidden = tanh(p.A1*input+p.c1);
mu = p.A2*hidden+p.c2;
if needCache, cache.headInput = input; cache.headHidden = hidden; end
assert(all(isfinite(mu),'all'),'landing2d:CurrentSemanticsOutput','Non-finite actor output.');
end
