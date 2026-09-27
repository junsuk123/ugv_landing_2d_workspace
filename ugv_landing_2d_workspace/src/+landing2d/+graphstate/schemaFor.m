function [schema,T] = schemaFor(mode)
% SCHEMAFOR  상태 표현 방식에 맞는 온톨로지 스키마와 간선 색인표.
%
% 의미 노드와 의미 간선은 기존 landing2d.ontology.nodeSchema의 'core'
% 변형(9노드)에서 옵니다. R-GAT 정책 표현에는 센서값을 갖지 않는 PolicyNode와
% ValueNode를 덧붙입니다. 두 가상 노드는 모든 의미 노드의 메시지를 모으는
% graph-level query이며, 각각 Actor와 Critic이 직접 읽습니다.
%
%   'ontology_rgat' 관계 유형을 그대로 유지 (degrades/supports/contributes/self)
%   'gat'           제거 실험. 모든 간선을 관계 하나로 합칩니다. 자기 간선도 같은
%                   인접 행렬에 들어가는 표준 GAT 구성입니다.
%   'node_pool'     간선을 쓰지 않으므로 색인표는 구조 점검용으로만 돌려줍니다.
schema = landing2d.ontology.nodeSchema('core');
switch mode
    case 'ontology_rgat'
        schema = addDecisionNodes(schema);
    case {'node_pool','semantic_flat'}
        % 제거 실험은 기존 9개 의미 노드만 유지합니다.
    case 'gat'
        schema = addDecisionNodes(schema);
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

function schema = addDecisionNodes(schema)
% ADDDECISIONNODES  전역 pooling을 대신할 Actor/Critic 가상 노드.
%
% 새 센서 정보나 환경 참값은 넣지 않습니다. 두 노드의 입력값은 항상 0이며,
% R-GAT message passing으로 들어온 의미 노드 정보만 의사결정 표현에 사용됩니다.
ontologyNodes = 1:schema.nNodes;
policyNode = schema.nNodes+1;
valueNode = schema.nNodes+2;
schema.nodeNames = [schema.nodeNames,{'PolicyNode','ValueNode'}];
schema.nNodes = schema.nNodes+2;
schema.ontologyNodes = ontologyNodes;
schema.policyNode = policyNode;
schema.valueNode = valueNode;
schema.decisionNodes = [policyNode,valueNode];
schema.neutralValue = [schema.neutralValue,0,0];

% 기존 self 간선을 잠시 빼고, 모든 의미 노드 -> 두 의사결정 노드를
% contributes 관계로 연결한 뒤 전체 노드의 self 간선을 다시 만듭니다.
selfRelation = find(strcmp(schema.relationNames,'self'),1);
contributes = find(strcmp(schema.relationNames,'contributes'),1);
nonSelf = schema.rel ~= selfRelation;
informSrc = [ontologyNodes,ontologyNodes];
informDst = [policyNode*ones(size(ontologyNodes)), ...
    valueNode*ones(size(ontologyNodes))];
schema.src = [schema.src(nonSelf),informSrc,1:schema.nNodes];
schema.dst = [schema.dst(nonSelf),informDst,1:schema.nNodes];
schema.rel = [schema.rel(nonSelf), ...
    contributes*ones(size(informSrc)), ...
    selfRelation*ones(1,schema.nNodes)];
schema.variant = 'policy_value_graphstate';
end
