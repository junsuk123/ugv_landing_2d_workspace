function [g,dCoordinates] = semanticGraphBackward(p,spec,cache,dEvidence)
% SEMANTICGRAPHBACKWARD Exact derivative of landing2d.residual_context.semanticGraphForward.
% G is a product of gate factors; each factor's derivative uses the product of
% the other factors at that node (no division).
d = spec.hiddenDim; N = spec.nNodes; B = cache.B; u = cache.u;
Wq = p.W(:,:,spec.gateRelation);
g = struct('P',zeros(size(p.P)),'bp',zeros(size(p.bp)),'W',zeros(size(p.W)),'a',zeros(size(p.a)), ...
    'bq',zeros(size(p.bq)),'W0',zeros(size(p.W0)),'b',zeros(size(p.b)));
dH = zeros(d,N,B); dH(:,spec.goalNode,:) = reshape(dEvidence,d,1,B);
for l = spec.layers:-1:1
    layer = cache.layers{l};
    dInner = dH.*layer.G; dG = dH.*layer.inner;
    dRoot = reshape(dInner.*(1-layer.root.^2),d,N*B);
    g.W0 = g.W0+dRoot*reshape(layer.previous,d,N*B)'; g.b = g.b+sum(dRoot,2);
    dPrevious = reshape(p.W0'*dRoot,d,N,B);
    [dX,relationGrad] = landing2d.minimal.dynamicBackward(dInner,layer.relation);
    g.W(:,:,spec.additiveRelations) = g.W(:,:,spec.additiveRelations)+relationGrad.W;
    g.a = g.a+relationGrad.a;
    dPrevious = dPrevious+dX;
    for e = 1:numel(spec.qualifies.src)
        i = spec.qualifies.dst(e); j = spec.qualifies.src(e);
        others = ones(d,B);
        for f = 1:numel(spec.qualifies.src)
            if f~=e && spec.qualifies.dst(f)==i, others = others.*(1+layer.gateTerms{f}); end
        end
        t = layer.gateTerms{e};
        dz = reshape(dG(:,i,:),d,B).*others.*(1-t.^2);
        g.W(:,:,spec.gateRelation) = g.W(:,:,spec.gateRelation)+dz*reshape(layer.previous(:,j,:),d,B)';
        g.bq = g.bq+sum(dz,2);
        dPrevious(:,j,:) = dPrevious(:,j,:)+reshape(Wq'*dz,d,1,B);
    end
    dH = dPrevious;
end
dProjection = dH.*(1-cache.H0.^2);
dCoordinates = zeros(size(u));
for i = 1:N
    index = spec.schema.observationIndices{i}; flat = reshape(dProjection(:,i,:),d,B);
    g.P(:,index) = flat*u(index,:)'; g.bp(:,i) = sum(flat,2);
    dCoordinates(index,:) = p.P(:,index)'*flat;
end
end
