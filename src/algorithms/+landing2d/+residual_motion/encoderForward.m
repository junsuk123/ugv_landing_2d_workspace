function [mu,cache] = encoderForward(p,spec,o)
% Direct mean correction: the base actor has its own unchanged output path.
% Correction-branch activation (landing2d.residual_motion.correctionActivation):
% spec.correctionActivation, tanh when absent (v3-v5); v6 uses soft_linear_v1
% at the node projection, every node update and the final correction (graph),
% or the hidden layer and the final correction (MLP). The base MLP keeps tanh.
% spec.correctionOperators (v8/C3): the graph correction is
% landing2d.residual_context.semanticGraphForward (relation-typed operators,
% goal-node evidence); the MLP correction and the mixing are unchanged.
assert(size(o,1)==spec.inDim && all(isfinite(o),'all'));
kind = 'tanh';
if isfield(spec,'correctionActivation'), kind = spec.correctionActivation; end
B = size(o,2); d = spec.hiddenDim; N = 4;   % 8 for v3-v6, 12 for v7 (C2)
[correctionInput,coordinateJacobian] = landing2d.residual_motion.motionCoordinates(o);
baseHidden = tanh(p.B1*o+p.b1);
baseMean = p.B2*baseHidden+p.b2;
cache = struct('policyInput',o,'B',B,'baseHidden',baseHidden,'baseMean',baseMean, ...
    'correctionInput',correctionInput,'coordinateJacobian',coordinateJacobian);
if strcmp(spec.correctionType,'graph') && isfield(spec,'correctionOperators')
    [evidence,cache.semantic] = landing2d.residual_context.semanticGraphForward(p,spec,correctionInput);
    % Display-only first-hop attention on the full edge list (gate edges NaN).
    alpha = nan(numel(spec.schema.src),B);
    alpha(spec.additiveEdges,:) = cache.semantic.layers{1}.relation.alpha;
    cache.cache1 = struct('alpha',alpha);
elseif strcmp(spec.correctionType,'graph')
    H0 = zeros(d,N,B); H0Slope = H0;
    for i = 1:N
        index = spec.schema.observationIndices{i};
        [h,s] = landing2d.residual_motion.correctionActivation(p.P(:,index)*correctionInput(index,:)+p.bp(:,i),kind);
        H0(:,i,:) = reshape(h,d,1,B); H0Slope(:,i,:) = reshape(s,d,1,B);
    end
    H = H0; layers = cell(1,spec.layers);
    for l = 1:spec.layers
        previous = H;
        [Z,relation] = landing2d.minimal.dynamicForward(H0,p.W,p.a,spec.T,H);
        [h,s] = landing2d.residual_motion.correctionActivation(reshape(Z,d,N*B)+p.W0*reshape(H,d,N*B)+p.b,kind);
        H = reshape(h,d,N,B);
        layers{l} = struct('previous',previous,'H',H,'slope',reshape(s,d,N,B),'relation',relation);
    end
    evidence = reshape(H,d*N,B);
    cache.H0 = H0; cache.H0Slope = H0Slope; cache.layers = layers; cache.cache1 = layers{1}.relation;
else
    [evidence,cache.evidenceSlope] = landing2d.residual_motion.correctionActivation(p.F*correctionInput+p.bf,kind);
end
[correction,cache.correctionSlope] = landing2d.residual_motion.correctionActivation(p.R*evidence+p.br,kind);
mix = 1/(1+exp(-p.beta));
mu = baseMean+mix*correction;
cache.evidence = evidence; cache.correction = correction; cache.mix = mix;
end
