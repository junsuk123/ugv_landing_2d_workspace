function [Z,cache] = dynamicForward(X,W,a,T,query)
% DYNAMICFORWARD Relational GATv2-style joint source/destination attention.
% The SAME W_r projects both ends (share_weights); messages remain W_r h_j.
% a = [score vector (d), joint bias (d), relation bias (R)]. No extra weights.
[d,N,B] = size(X); R = T.nRelations; E = T.nEdges;
Xf = reshape(X,d,N*B); projected = zeros(d,N*R,B);
for r = 1:R
    projected(:,(r-1)*N+(1:N),:) = reshape(W(:,:,r)*Xf,d,N,B);
end
source = projected(:,T.colIdx,:);
destination = projected(:,T.dst+N*(T.rel-1),:);
if nargin>=5
    assert(isequal(size(X),size(query)),'landing2d:AttentionShape','Evidence/query sizes differ.');
    queryFlat = reshape(query,d,N*B); queryProjected = zeros(d,N*R,B);
    for r = 1:R
        queryProjected(:,(r-1)*N+(1:N),:) = reshape(W(:,:,r)*queryFlat,d,N,B);
    end
    destination = queryProjected(:,T.dst+N*(T.rel-1),:);
end
joint = source+destination+reshape(a(d+(1:d)),d,1,1);
activated = .6*joint+.4*abs(joint);
score = reshape(a(1:d)*reshape(activated,d,E*B),E,B)+a(2*d+T.rel)';
alpha = zeros(E,B);
for i = 1:N
    edges = find(T.dst==i);
    shifted = score(edges,:)-max(score(edges,:),[],1);
    weight = exp(shifted); alpha(edges,:) = weight./sum(weight,1);
end
weighted = source.*reshape(alpha,1,E,B);
Z = permute(reshape(T.Msel*reshape(permute(weighted,[2,1,3]),E,d*B),N,d,B),[2,1,3]);
cache = struct('Xf',Xf,'W',W,'a',a,'T',T,'source',source,'joint',joint, ...
    'activated',activated,'alpha',alpha,'score',score,'d',d,'N',N,'B',B);
if nargin>=5, cache.queryFlat = queryFlat; end
end
