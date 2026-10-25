function [dX,grads,dQuery] = dynamicBackward(dZ,cache)
% DYNAMICBACKWARD Exact derivative including the joint-query attention path.
T = cache.T; d = cache.d; N = cache.N; B = cache.B; E = T.nEdges;
dWeighted = dZ(:,T.dst,:);
dAlpha = reshape(sum(dWeighted.*cache.source,1),E,B);
weightedSum = T.Msel*(dAlpha.*cache.alpha);
dScore = cache.alpha.*(dAlpha-weightedSum(T.dst,:));
grads.a = zeros(size(cache.a));
grads.a(1:d) = reshape(dScore,1,E*B)*reshape(cache.activated,d,E*B)';
grads.a(2*d+(1:T.nRelations)) = sum(T.Mrel*dScore,2)';
dJoint = reshape(cache.a(1:d),d,1,1).*reshape(dScore,1,E,B) ...
    .*(.6+.4*sign(cache.joint));
grads.a(d+(1:d)) = sum(reshape(dJoint,d,E*B),2)';
dSource = dJoint+dWeighted.*reshape(cache.alpha,1,E,B);
grads.W = zeros(size(cache.W)); dXf = zeros(size(cache.Xf));
if isfield(cache,'queryFlat')
    dQueryFlat = zeros(size(cache.queryFlat));
    for r = 1:T.nRelations
        dProjected = zeros(d,N,B); dQueryProjected = zeros(d,N,B);
        for e = find(T.rel==r)
            dProjected(:,T.src(e),:) = dProjected(:,T.src(e),:)+dSource(:,e,:);
            dQueryProjected(:,T.dst(e),:) = dQueryProjected(:,T.dst(e),:)+dJoint(:,e,:);
        end
        flat = reshape(dProjected,d,N*B); queryFlat = reshape(dQueryProjected,d,N*B);
        grads.W(:,:,r) = flat*cache.Xf'+queryFlat*cache.queryFlat';
        dXf = dXf+cache.W(:,:,r)'*flat;
        dQueryFlat = dQueryFlat+cache.W(:,:,r)'*queryFlat;
    end
    dX = reshape(dXf,d,N,B); dQuery = reshape(dQueryFlat,d,N,B);
    return;
end
for r = 1:T.nRelations
    dProjected = zeros(d,N,B);
    for e = find(T.rel==r)
        dProjected(:,T.src(e),:) = dProjected(:,T.src(e),:)+dSource(:,e,:);
        dProjected(:,T.dst(e),:) = dProjected(:,T.dst(e),:)+dJoint(:,e,:);
    end
    flat = reshape(dProjected,d,N*B);
    grads.W(:,:,r) = flat*cache.Xf';
    dXf = dXf+cache.W(:,:,r)'*flat;
end
dX = reshape(dXf,d,N,B);
dQuery = [];
end
