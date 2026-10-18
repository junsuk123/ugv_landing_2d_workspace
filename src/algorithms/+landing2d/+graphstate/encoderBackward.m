function [grads,dS] = encoderBackward(params,spec,cache,dG)
% ENCODERBACKWARD  Backpropagate an Actor/Critic loss through the encoder.
%   [grads,dS] = landing2d.graphstate.encoderBackward(params,spec,cache,dG)
% Baseline: identity (no parameters). context_rgat: grouped factorized
% readout -> node nonlinearity -> R-GAT layer (relationBackward) + local W0.
if strcmp(spec.mode,'baseline')
    grads = struct(); dS = dG; return;
end
B = cache.B; N = cache.N; dh = cache.dh;
preOutput = dG.*(1-cache.g.^2);
grads = struct();
grads.Wc = zeros(size(params.Wc));
grads.Wn = zeros(size(params.Wn));
grads.bg = sum(preOutput,2);
dH = zeros(dh,N,B);
for b = 1:B
    weighted = preOutput(:,b).*params.Wn;
    grads.Wc = grads.Wc+weighted*cache.grouped(:,:,b)';
    grads.Wn = grads.Wn+preOutput(:,b).*cache.channel(:,:,b);
    dH(:,:,b) = (params.Wc'*weighted)*spec.groupMatrix;
end
preH = dH.*(1-cache.H.^2);
[dXRelation,g1] = landing2d.rgat.relationBackward(preH,cache.cache1);
flat = reshape(preH,dh,N*B);
grads.W1 = g1.W; grads.a1 = g1.a; grads.E1 = g1.E;
grads.W0 = flat*cache.Xf';
grads.b0 = sum(flat,2);
dX = dXRelation+reshape(params.W0'*flat,spec.inDim,N,B);
dS = reshape(dX,spec.inDim*N,B);
grads = orderfields(grads,params);
end
