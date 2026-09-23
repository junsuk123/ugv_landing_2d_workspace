function X = nodeFeatures(values,signed,schema)
% NODEFEATURES  상태 표현용 노드 특징 행렬 X_t.
%
% landing2d.ontology.buildGraph와 같은 구성에 방향 부호 채널 하나를 더한 것입니다.
% 보상 설계 경로는 buildGraph를 그대로 쓰므로 영향을 받지 않습니다.
%
%   1     : 노드 값 (온톨로지가 정의한 위험/좋음의 크기, [0,1])
%   2     : 1 - 노드 값
%   3     : 위험 노드 표시
%   4     : 편향
%   5     : 방향 부호 ([-1,1], 방향이 없는 노드는 0)
%   6.... : 노드 정체성 one-hot
%
% 노드 집합 V_t, 간선 집합 E_t, 관계 유형은 온톨로지 스키마 그대로입니다.
% 새 노드나 새 관계를 만들지 않고, 노드가 이미 나타내는 양의 부호만 같은
% 노드의 특징 벡터에 덧붙입니다.
%
% 왜 필요한가: 온톨로지 노드 값은 전부 절댓값입니다(PositionError = |오차|,
% DescentSpeed = |vz|). 보상 가중치를 설계할 때는 "얼마나 위험한가"만 알면
% 되므로 문제가 없지만, 정책의 상태로 쓰면 좌/우와 상승/하강을 구분하지 못해
% 제어가 불가능합니다. 측정값은 docs/ONTOLOGY_GRAPH_STATE_KO.md에 있습니다.
n = schema.nNodes;
X = zeros(schema.inDim,n);
for i = 1:n
    name = schema.nodeNames{i};
    if isfield(signed,name)
        direction = signed.(name);
    else
        direction = 0;
    end
    riskFlag = double(ismember(i,schema.riskNodes));
    X(1:5,i) = [values(i);1-values(i);riskFlag;1;direction];
    X(5+i,i) = 1;
end
end
