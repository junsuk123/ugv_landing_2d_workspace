function info = attention(P,X,T,schema)
% ATTENTION  학습된 R-GAT 두 번째 계층의 간선 주의 가중치.
% 어떤 관계와 어떤 간선을 통해 정보가 목표 노드로 모이는지 보기 위한 해석용입니다.
% 주의 가중치는 학습된 중요도이지 인과의 증명이 아닙니다.
[~,cache] = landing2d.rgat.potentialForward(P,X,T);
edgeAlpha = mean(cache.cache2.alpha,2)';
info = struct('edgeAlpha',edgeAlpha,'src',T.src,'dst',T.dst,'rel',T.rel);
info.relationMean = zeros(1,T.nRelations);
for r = 1:T.nRelations
    mask = T.rel == r;
    if any(mask)
        info.relationMean(r) = mean(edgeAlpha(mask));
    end
end
% 목표 노드로 들어오는 간선만 따로 모으면 최종 판단에 쓰인 경로가 보입니다.
goalMask = T.dst == T.goalNode & T.rel ~= T.nRelations;
info.goalEdges = struct('src',T.src(goalMask),'rel',T.rel(goalMask), ...
    'alpha',edgeAlpha(goalMask));
if nargin > 3
    info.nodeNames = schema.nodeNames;
    info.relationNames = schema.relationNames;
end
end
