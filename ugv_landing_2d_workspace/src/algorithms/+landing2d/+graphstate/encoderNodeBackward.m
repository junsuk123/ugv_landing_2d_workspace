function [grads,dS] = encoderNodeBackward(params,spec,cache,dH)
% ENCODERNODEBACKWARD Backpropagate a loss attached to node embeddings.
% This entry point is also used by causal masked-node pretraining.
B = cache.B; N = cache.N; dh = cache.dh;
switch spec.mode
    case {'node_pool','context_node_pool'}
        dZn = reshape(dH.*(1-cache.H.^2),dh,N*B);
        grads.Wn = dZn*cache.Xf';
        grads.bn = sum(dZn,2);
        dS = reshape(params.Wn'*dZn,spec.inDim*N,B);
    case {'gat','ontology_rgat'}
        preH2 = dH.*(1-cache.H.^2);
        [dH1FromLayer2,g2] = landing2d.rgat.relationBackward(preH2,cache.cache2);
        dH1 = preH2+dH1FromLayer2;
        preH1 = dH1.*(1-cache.H1.^2);
        [dX,g1] = landing2d.rgat.relationBackward(preH1,cache.cache1);
        grads.W1 = g1.W; grads.a1 = g1.a; grads.E1 = g1.E;
        grads.W2 = g2.W; grads.a2 = g2.a; grads.E2 = g2.E;
        dS = reshape(dX,spec.inDim*N,B);
    case {'context_gat','context_rgat'}
        preH = dH.*(1-cache.H.^2);
        [dXRelation,g1] = landing2d.rgat.relationBackward(preH,cache.cache1);
        flat = reshape(preH,dh,N*B);
        grads.W1 = g1.W; grads.a1 = g1.a; grads.E1 = g1.E;
        grads.W0 = flat*cache.Xf';
        grads.b0 = sum(flat,2);
        dX = dXRelation+reshape(params.W0'*flat,spec.inDim,N,B);
        dS = reshape(dX,spec.inDim*N,B);
    otherwise
        error('landing2d:UnknownStateRepresentation', ...
            'encoderNodeBackward does not handle %s.',spec.mode);
end
end
