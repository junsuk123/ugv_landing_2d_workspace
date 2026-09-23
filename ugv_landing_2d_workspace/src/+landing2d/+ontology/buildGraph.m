function X = buildGraph(values,schema)
% BUILDGRAPH  노드 값에서 온톨로지 그래프의 노드 특징 행렬을 생성.
% 간선은 스키마에 고정되어 있고, 상태에 따라 변하는 것은 이 특징 행렬뿐입니다.
%
% 특징 구성 (원 저장소 semantic.buildOntologyGraph와 같음)
%   1: 노드 값, 2: 1-값, 3: 위험 노드 표시, 4: 편향, 5..: 노드 정체성 one-hot
X = zeros(schema.inDim,schema.nNodes);
for i = 1:schema.nNodes
    riskFlag = double(ismember(i,schema.riskNodes));
    X(1:4,i) = [values(i);1-values(i);riskFlag;1];
    X(4+i,i) = 1;
end
end
