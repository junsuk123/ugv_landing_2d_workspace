function values = nodeValues(sem,schema,extra)
% NODEVALUES  의미 채널과 설계 변수를 스키마 순서의 노드 값 벡터로 변환.
% 목표 노드(SafeLanding)는 미래 정답 누출을 막기 위해 항상 0입니다.
%
% extra는 상태에서 나오지 않는 노드 값입니다(보상 가중치, 강화학습 가치 등).
if nargin < 3
    extra = struct();
end
values = zeros(1,schema.nNodes);
for i = 1:schema.nNodes
    name = schema.nodeNames{i};
    if isfield(sem,name)
        values(i) = sem.(name);
    elseif isfield(extra,name)
        values(i) = extra.(name);
    elseif i ~= schema.goalNode
        error('landing2d:MissingNodeValue','No value for ontology node %s.',name);
    end
end
values(schema.goalNode) = 0;
end
