function [g,cache] = encoderForward(params,spec,policyInput)
% ENCODERFORWARD No basis bank, gate, residual stack or learned readout.
B = size(policyInput,2); N = spec.nNodes; d = spec.hiddenDim;
Xf = reshape(policyInput,spec.inDim,N*B);
H0 = tanh(params.P*Xf+params.bp);
if strcmp(spec.encoderVersion,'rgat_minimal_v2')
    H = reshape(H0,d,N,B); layers = cell(1,spec.layers);
    for k = 1:spec.layers
        previous = H;
        [Z,relationCache] = landing2d.minimal.dynamicForward(H,params.W,params.a,spec.T);
        H = reshape(tanh(reshape(Z,d,N*B)+params.W0*reshape(H,d,N*B)+params.b),d,N,B);
        layers{k} = struct('previous',previous,'H',H,'relation',relationCache);
    end
    g = reshape(H(:,spec.T.goalNode,:),d,B);
    cache = struct('B',B,'Xf',Xf,'H0',H0,'layers',{layers},'g',g);
    % Existing validation diagnostics read first-hop attention via cache1.
    % This alias is read-only and is not the cache used for differentiation.
    cache.cache1 = layers{1}.relation;
    return;
end
[Z,relationCache] = landing2d.rgat.relationForward(reshape(H0,d,N,B), ...
    params.W,repmat(params.a,1,1,spec.T.nRelations), ...
    spec.fixedRelationEmbedding,spec.T,[],spec.attentionMode);
H = tanh(reshape(Z,d,N*B)+params.W0*H0+params.b);
H = reshape(H,d,N,B);
g = reshape(H(:,spec.T.goalNode,:),d,B);
cache = struct('B',B,'Xf',Xf,'H0',H0,'H',H,'cache1',relationCache,'g',g);
end
