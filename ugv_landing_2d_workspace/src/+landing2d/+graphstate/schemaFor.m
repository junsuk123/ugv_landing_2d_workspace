function [schema,T] = schemaFor(mode)
% SCHEMAFOR  상태 표현 방식에 맞는 온톨로지 스키마와 간선 색인표.
%
% 노드 집합 V_t와 간선 집합 E_t는 언제나 기존 landing2d.ontology.nodeSchema의
% 'core' 변형(9노드)에서 옵니다. 새 온톨로지 클래스나 관계를 만들지 않습니다.
% 'design' 변형(보상 가중치 노드 포함)은 보상 설계 전용이므로 쓰지 않습니다.
%
%   'ontology_rgat' 관계 유형을 그대로 유지 (degrades/supports/contributes/self)
%   'gat'           제거 실험. 모든 간선을 관계 하나로 합칩니다. 자기 간선도 같은
%                   인접 행렬에 들어가는 표준 GAT 구성입니다.
%   'node_pool'     간선을 쓰지 않으므로 색인표는 구조 점검용으로만 돌려줍니다.
schema = landing2d.ontology.nodeSchema('core');
switch mode
    case {'ontology_rgat','node_pool','semantic_flat'}
        % 관계 유형 유지.
    case 'gat'
        schema.rel = ones(size(schema.rel));
        schema.relationNames = {'adjacent'};
        schema.nRelations = 1;
    otherwise
        error('landing2d:UnknownStateRepresentation', ...
            'schemaFor does not handle stateRepresentation %s.',mode);
end
% 상태 표현용 노드 특징은 방향 부호 채널이 하나 더 있습니다.
% landing2d.graphstate.nodeFeatures 참고. 노드와 간선은 그대로입니다.
schema.contextNames = {'AccelerationTrend','MarginRate', ...
    'BoundaryUrgency','MemoryUncertainty','AltitudeContext'};
schema.nContext = numel(schema.contextNames);
schema.inDim = 5+schema.nContext+schema.nNodes;
if nargout > 1
    T = landing2d.rgat.topology(schema);
end
end
