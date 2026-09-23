function [phi,cache] = potentialForward(P,X,T)
% POTENTIALFORWARD  그래프 하나 또는 배치에 대한 유계 잠재함수 Phi(G) in [-1,1].
%   X : [inDim x nNodes] 또는 [inDim x nNodes x B],  phi : [1 x B]
% 두 관계형 주의 계층, 두 번째 층 잔차 연결, 목표 노드에서의 선형 읽기.
if ndims(X) < 3
    X = reshape(X,size(X,1),size(X,2),1);
end
B = size(X,3);
N = T.nNodes;
dh = size(P.W1,1);
[Z1,cache1] = landing2d.rgat.relationForward(X,P.W1,P.a1,P.E1,T);
H1 = tanh(reshape(Z1,dh,N,B));
[Z2,cache2] = landing2d.rgat.relationForward(H1,P.W2,P.a2,P.E2,T);
H2 = tanh(reshape(Z2,dh,N,B)+H1);
goal = reshape(H2(:,T.goalNode,:),dh,B);
phi = tanh(P.wOut*goal+P.bOut);
cache = struct('cache1',cache1,'cache2',cache2,'H1',H1,'H2',H2, ...
    'goal',goal,'phi',phi,'wOut',P.wOut,'dh',dh,'N',N,'B',B,'T',T);
end
