function [share,info] = designByWeightGraph(potentials,D,onto)
% DESIGNBYWEIGHTGRAPH  가중치 노드를 훑어 착륙 잠재함수가 가장 큰 배분을 고릅니다.
%
% 가중치가 그래프 안의 노드이므로, 그 노드 값만 바꿔가며 Phi를 계산하면
% "그 배분이 안전 착륙으로 이어질 가능성"을 직접 읽을 수 있습니다.
% 반사실 민감도가 "무엇이 Phi를 좌우하는가"를 재는 것과 달리,
% 이쪽은 "어떤 배분이 착륙에 도움이 되는가"를 바로 답합니다.
if ~iscell(potentials)
    potentials = {potentials};
end
schema = D.schema;
assert(~isempty(schema.weightNodes), ...
    'landing2d:MissingWeightNodes','This design needs the design-variant ontology.');
T = landing2d.rgat.topology(schema);
X = landing2d.ontology.attributionSample(D.X,onto);
candidates = linspace(onto.weightMin,onto.weightMax,onto.sweepGrid);
score = zeros(size(candidates));
for i = 1:numel(candidates)
    counterfactual = X;
    counterfactual(1,schema.weightNodes(1),:) = candidates(i);
    counterfactual(2,schema.weightNodes(1),:) = 1-candidates(i);
    counterfactual(1,schema.weightNodes(2),:) = 1-candidates(i);
    counterfactual(2,schema.weightNodes(2),:) = candidates(i);
    total = 0;
    for k = 1:numel(potentials)
        total = total+mean(landing2d.rgat.predict(potentials{k},counterfactual,T));
    end
    score(i) = total/numel(potentials);
end
[bestScore,bestIndex] = max(score);
share = [candidates(bestIndex),1-candidates(bestIndex)];
info = struct('candidates',candidates,'score',score, ...
    'bestShare',candidates(bestIndex),'bestScore',bestScore, ...
    'scoreRange',max(score)-min(score),'samples',size(X,3));
end
