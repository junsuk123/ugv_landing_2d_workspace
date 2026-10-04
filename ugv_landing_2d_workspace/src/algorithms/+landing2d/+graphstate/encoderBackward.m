function [grads,dS] = encoderBackward(params,spec,cache,dG)
% ENCODERBACKWARD Backpropagate an Actor/Critic loss through graph readout.
if ismember(spec.mode,{'baseline','semantic_flat','context_flat'})
    grads = struct(); dS = dG; return;
end
B = cache.B; N = cache.N; dh = cache.dh;
grads = struct();
switch spec.readout
    case 'decision_nodes'
        dH = zeros(dh,N,B);
        dH(:,cache.readoutNode,:) = reshape(dG,dh,1,B);
    case 'meanmax'
        preOutput = dG.*(1-cache.g.^2);
        grads.Wg = preOutput*cache.readout';
        grads.bg = sum(preOutput,2);
        dReadout = params.Wg'*preOutput;
        dMean = dReadout(1:dh,:);
        dMax = dReadout(dh+1:end,:);
        dH = repmat(reshape(dMean/N,dh,1,B),1,N,1);
        rowIndex = repmat((1:dh)',1,B);
        batchIndex = repmat(1:B,dh,1);
        linear = sub2ind([dh,N,B],rowIndex,cache.argMax,batchIndex);
        dH(linear) = dH(linear)+dMax;
    case 'mean'
        dH = repmat(reshape(dG/N,dh,1,B),1,N,1);
    case 'grouped'
        preOutput = dG.*(1-cache.g.^2);
        grads.Wg = preOutput*cache.readout';
        grads.bg = sum(preOutput,2);
        dGrouped = reshape(params.Wg'*preOutput,dh,spec.groupCount,B);
        dH = zeros(dh,N,B);
        for b = 1:B
            dH(:,:,b) = dGrouped(:,:,b)*spec.groupMatrix;
        end
        directDS = zeros(spec.stateDim,B);
    case 'raw_plus_groups'
        directDS = dG(1:spec.stateDim,:);
        dContext = dG(spec.stateDim+1:end,:);
        preOutput = dContext.*(1-cache.relationContext.^2);
        grads.Wg = preOutput*cache.readout';
        grads.bg = sum(preOutput,2);
        dGrouped = reshape(params.Wg'*preOutput,dh,spec.groupCount,B);
        dH = zeros(dh,N,B);
        for b = 1:B
            dH(:,:,b) = dGrouped(:,:,b)*spec.groupMatrix;
        end
    otherwise
        error('landing2d:UnknownReadout','Unknown readout: %s',spec.readout);
end
[backboneGrads,dS] = landing2d.graphstate.encoderNodeBackward( ...
    params,spec,cache,dH);
if exist('directDS','var'), dS = dS+directDS; end
names = fieldnames(backboneGrads);
for i = 1:numel(names), grads.(names{i}) = backboneGrads.(names{i}); end
grads = orderfields(grads,params);
end
