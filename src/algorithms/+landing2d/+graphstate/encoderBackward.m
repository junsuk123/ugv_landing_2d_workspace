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
% Layers in reverse: residual mix (l >= 2, eta = cache.residualMix:
% dF = eta dH, skip (1-eta) dH to the previous state), tanh, root weight,
% relation layer (landing2d.rgat.relationBackward), then the basis
% decomposition dV_b = sum_r C(r,b) dW_r, dC(r,b) = <dW_r,V_b>.
% semantic_fixed_v1: F = (1 + M) .* A gives dA = dF (1 + M), dM = dF A; the
% additive and the modulating graph send their gradients to the same W_r/a/E.
eta = 0; if isfield(cache,'residualMix'), eta = cache.residualMix; end
typed = isfield(cache,'v2Operators') ...
    && ismember(cache.v2Operators,{'semantic_fixed_v1','semantic_bottleneck_v1', ...
    'semantic_reliability_bottleneck_v1'});
keep = 1-eta; mix = eta;
if isfield(cache,'residualKeep'), keep = cache.residualKeep; mix = cache.residualWeight; end
for l = spec.layers:-1:1
    if l == 1
        previous = reshape(cache.Xf,spec.inDim,cache.N,cache.B);
    else
        previous = cache.layerH{l-1};
    end
    root = params.(sprintf('Wroot%d',l));
    V = params.(sprintf('V%d',l));
    fixedCodebook = isfield(spec,'relationParameterization') ...
        && ismember(spec.relationParameterization, ...
        {'fixed_cyclic_codebook_v1','fixed_semantic_codebook_v1'});
    if fixedCodebook
        C = spec.fixedRelationCodebook;
    else
        C = params.(sprintf('C%d',l));
    end
    [dh,din,Bb] = size(V); R = size(C,1);
    skip = 0;
    if l >= 2 && eta > 0
        skip = keep*dH; dH = mix*dH;
    end
    if typed
        A = cache.layerA{l}; M = cache.layerM{l};
        preActivation = dH.*(1+M).*(1-A.^2);
        preModulation = dH.*A.*(1-M.^2);
    elseif l >= 2 && eta > 0
        preActivation = dH.*(1-cache.layerF{l}.^2);
    else
        preActivation = dH.*(1-cache.layerH{l}.^2);
    end
    grads.(sprintf('b%d',l)) = reshape(sum(sum(preActivation,3),2),dh,1);
    flatPre = reshape(preActivation,dh,cache.N*cache.B);
    flatPrevious = reshape(previous,size(previous,1),cache.N*cache.B);
    grads.(sprintf('Wroot%d',l)) = flatPre*flatPrevious';
    if typed
        [dHa,ga] = landing2d.rgat.relationBackward(preActivation,cache.layerAdd{l});
        [dHm,gm] = landing2d.rgat.relationBackward(preModulation,cache.layerMod{l});
        dH = dHa+dHm;
        g = struct('W',ga.W+gm.W,'a',ga.a+gm.a,'E',ga.E+gm.E);
    else
        [dH,g] = landing2d.rgat.relationBackward(preActivation,cache.layerCaches{l});
    end
    dH = dH+reshape(root'*flatPre,size(previous,1),cache.N,cache.B)+skip;
    dW = reshape(g.W,dh*din,R);
    grads.(sprintf('V%d',l)) = reshape(dW*C,dh,din,Bb);
    if fixedCodebook
        grads.(sprintf('a%d',l)) = sum(g.a,3);
    else
        grads.(sprintf('C%d',l)) = dW'*reshape(V,dh*din,Bb);
        grads.(sprintf('a%d',l)) = g.a;
        grads.(sprintf('E%d',l)) = g.E;
    end
end
dPolicyInput = reshape(dH,spec.inDim*cache.N,cache.B);
grads = orderfields(grads,params);
end
