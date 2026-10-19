function [grads,dPolicyInput] = encoderBackward(params,spec,cache,dG)
% ENCODERBACKWARD  Backpropagate an Actor/Critic loss through the encoder.
%   [grads,dPolicyInput] = landing2d.graphstate.encoderBackward(params,spec,cache,dG)
% Baseline: identity (no parameters). context_rgat: grouped factorized
% readout -> node nonlinearity -> R-GAT layer (relationBackward) + local W0.
% dPolicyInput is the gradient with respect to the encoder input (policyInput).
if strcmp(spec.mode,'baseline')
    grads = struct(); dPolicyInput = dG; return;
end
isV2 = isfield(spec,'encoderVersion') && strcmp(spec.encoderVersion,'rgat_v2');
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
if isV2
    [grads,dPolicyInput] = backwardV2(params,spec,cache,grads,dH);
    return;
elseif isfield(cache,'cacheMod')
    % typed_v1: H = (1 + M) .* A, A = tanh(Z_prop + local), M = tanh(Z_mod).
    preH = dH.*(1+cache.M).*(1-cache.A.^2);
    preM = dH.*cache.A.*(1-cache.M.^2);
    [dXa,ga] = landing2d.rgat.relationBackward(preH,cache.cacheAdd);
    [dXm,gm] = landing2d.rgat.relationBackward(preM,cache.cacheMod);
    dXRelation = dXa+dXm;
    g1 = struct('W',ga.W+gm.W,'a',ga.a+gm.a,'E',ga.E+gm.E);
else
    preH = dH.*(1-cache.H.^2);
    [dXRelation,g1] = landing2d.rgat.relationBackward(preH,cache.cache1);
end
flat = reshape(preH,dh,N*B);
grads.W1 = g1.W; grads.a1 = g1.a; grads.E1 = g1.E;
grads.W0 = flat*cache.Xf';
grads.b0 = sum(flat,2);
dX = dXRelation+reshape(params.W0'*flat,spec.inDim,N,B);
dPolicyInput = reshape(dX,spec.inDim*N,B);
grads = orderfields(grads,params);
end

function [grads,dPolicyInput] = backwardV2(params,spec,cache,grads,dH)
% Layers in reverse: tanh, relation layer (landing2d.rgat.relationBackward),
% then the basis decomposition dV_b = sum_r C(r,b) dW_r, dC(r,b) = <dW_r,V_b>.
for l = spec.layers:-1:1
    V = params.(sprintf('V%d',l)); C = params.(sprintf('C%d',l));
    [dh,din,Bb] = size(V); R = size(C,1);
    preActivation = dH.*(1-cache.layerH{l}.^2);
    grads.(sprintf('b%d',l)) = reshape(sum(sum(preActivation,3),2),dh,1);
    [dH,g] = landing2d.rgat.relationBackward(preActivation,cache.layerCaches{l});
    dW = reshape(g.W,dh*din,R);
    grads.(sprintf('V%d',l)) = reshape(dW*C,dh,din,Bb);
    grads.(sprintf('C%d',l)) = dW'*reshape(V,dh*din,Bb);
    grads.(sprintf('a%d',l)) = g.a;
    grads.(sprintf('E%d',l)) = g.E;
end
dPolicyInput = reshape(dH,spec.inDim*cache.N,cache.B);
grads = orderfields(grads,params);
end
