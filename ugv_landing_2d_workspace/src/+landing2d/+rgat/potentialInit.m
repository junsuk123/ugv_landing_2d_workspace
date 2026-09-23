function P = potentialInit(schema,onto,rs)
% POTENTIALINIT  두 층 R-GAT 안전 착륙 잠재함수 Phi(G)의 초기 파라미터.
% 두 번째 층에 잔차 연결이 있으므로 두 층의 출력 폭이 같아야 합니다.
dh = onto.hiddenDim;
relDim = onto.relationDim;
R = schema.nRelations;
scale = onto.initScale;
P.W1 = scale*randn(rs,dh,schema.inDim,R);
P.a1 = scale*randn(rs,1,2*dh+relDim,R);
P.E1 = scale*randn(rs,relDim,R);
P.W2 = scale*randn(rs,dh,dh,R);
P.a2 = scale*randn(rs,1,2*dh+relDim,R);
P.E2 = scale*randn(rs,relDim,R);
P.wOut = scale*randn(rs,1,dh);
P.bOut = 0;
end
