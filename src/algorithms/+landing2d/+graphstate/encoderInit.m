function [params,spec] = encoderInit(gs,observationDim,rs)
% ENCODERINIT  그래프 부호기의 학습 파라미터와 고정 명세를 생성.
%
% params는 숫자 배열만 담습니다. landing2d.util.adamInit / adamUpdate /
% clipGradient가 중첩 구조체를 그대로 훑기 때문에, 여기에 문자열이나 색인표를
% 넣으면 최적화기가 깨집니다. 그래서 바뀌지 않는 정보는 전부 spec으로 뺍니다.
%
% 'baseline'에서는 params가 빈 구조체이고 부호기가 항등 사상입니다.
% 빈 구조체는 Adam에서 갱신할 항목이 없고 기울기 노름에 0을 더하므로,
% 기준 모델의 수치 결과가 이 변경 전과 완전히 같습니다.
mode = gs.stateRepresentation;
spec = struct('mode',mode,'readout',gs.readout);
if strcmp(mode,'baseline')
    params = struct();
    spec.inDim = 0;
    spec.nNodes = 0;
    spec.hiddenDim = 0;
    spec.rawDim = observationDim;
    spec.graphStateDim = 0;
    spec.stateDim = observationDim;
    spec.graphDim = observationDim;
    spec.schema = [];
    spec.T = [];
    return;
end
[schema,T] = landing2d.graphstate.schemaFor(mode, ...
    landing2d.graphstate.graphDimension(gs),landing2d.graphstate.graphSource(gs));
% Relation-shuffle ablation: one fixed edge-relation permutation per graph
% seed, applied here once so pretraining, PPO, evaluation and inference all
% read the same typed topology from encoderSpec. graphHash identifies the
% typed graph actually used (canonical or shuffled).
[schema,T,graph] = landing2d.rgat.applyRelationPerturbation(schema,T,gs);
if isfield(gs,'ontologyReadout') && ~strcmp(gs.ontologyReadout,'all_nodes_v1')
    assert(strcmp(gs.ontologyReadout,'control_nodes_v1') ...
        && isfield(schema,'observationSource') ...
        && strcmp(schema.observationSource,'commonObservation'), ...
        'landing2d:OntologyReadout','Unknown or incompatible ontology readout.');
    names={'RelativePosition','RelativeVelocity','VerticalMotion','Attitude'};
    nodes=cellfun(@(name)find(strcmp(schema.nodeNames,name),1),names);
    assert(all(nodes>0),'landing2d:OntologyReadout', ...
        'The control-node ontology readout requires all registered nodes.');
    schema.groupNames=names;
    schema.readoutGroups=num2cell(nodes);
    schema.groupMatrix=zeros(numel(nodes),schema.nNodes);
    for g=1:numel(nodes), schema.groupMatrix(g,nodes(g))=1; end
    schema.variant=[schema.variant,'_control_readout'];
end
dh = gs.hiddenDim;
spec.schema = schema;
spec.T = T;
spec.graph = graph;
spec.policyNode = [];
spec.valueNode = [];
if isfield(schema,'policyNode')
    spec.policyNode = schema.policyNode;
    spec.valueNode = schema.valueNode;
end
spec.inDim = schema.inDim;
spec.nNodes = schema.nNodes;
spec.hiddenDim = dh;
spec.graphStateDim = schema.inDim*schema.nNodes;
spec.rawDim = spec.graphStateDim;
spec.stateDim = spec.graphStateDim;
if strcmp(gs.readout,'observation_plus_groups')
    assert(strcmp(landing2d.graphstate.graphSource(gs),'commonObservation'), ...
        'landing2d:ObservationResidual', ...
        'observation_plus_groups requires the planar common observation graph.');
    spec.rawDim = observationDim;
    spec.stateDim = observationDim+spec.graphStateDim;
end
spec.descentEligibilityIndex = [];
spec.landingInhibitIndex = [];
if isfield(schema,'nodeNames')
    descentNode = find(strcmp(schema.nodeNames,'DescentEligibility'),1);
    inhibitNode = find(strcmp(schema.nodeNames,'LandingInhibit'),1);
    if ~isempty(descentNode)
        spec.descentEligibilityIndex = (descentNode-1)*schema.inDim+1;
    end
    if ~isempty(inhibitNode)
        spec.landingInhibitIndex = (inhibitNode-1)*schema.inDim+1;
    end
end
if ismember(mode,{'semantic_flat','context_flat'})
    % Same semantic features as the graph arms, passed directly to the MLP.
    % This separates added-information gains from graph-structure gains.
    params = struct();
    spec.hiddenDim = 0;
    spec.graphDim = spec.stateDim;
    return;
end
scale = gs.initScale;
switch mode
    case {'node_pool','context_node_pool'}
        % 메시지 전달 없이 노드별 사영만. 간선을 전혀 쓰지 않습니다.
        params.Wn = scale*randn(rs,dh,schema.inDim);
        params.bn = zeros(dh,1);
    case {'gat','ontology_rgat'}
        % 두 층 관계형 주의. 두 번째 층에 잔차 연결이 있어 두 층의 폭이 같아야 합니다.
        R = schema.nRelations;
        relDim = gs.relationDim;
        params.W1 = scale*randn(rs,dh,schema.inDim,R);
        params.a1 = scale*randn(rs,1,2*dh+relDim,R);
        params.E1 = scale*randn(rs,relDim,R);
        params.W2 = scale*randn(rs,dh,dh,R);
        params.a2 = scale*randn(rs,1,2*dh+relDim,R);
        params.E2 = scale*randn(rs,relDim,R);
    case {'context_gat','context_rgat'}
        % A single relation layer is enough for this compact graph: its
        % semantic edges already connect each downstream decision context
        % to the causal evidence it needs. W0 is the fixed local residual;
        % a1 is the state-dependent gate adapted by PPO.
        R = schema.nRelations;
        relDim = gs.relationDim;
        params.W1 = scale*randn(rs,dh,schema.inDim,R);
        params.a1 = scale*randn(rs,1,2*dh+relDim,R);
        params.E1 = scale*randn(rs,relDim,R);
        params.W0 = scale*randn(rs,dh,schema.inDim);
        params.b0 = zeros(dh,1);
        % For the minimal sensor ontology, start with an information-
        % preserving local path inside the R-GAT layer. Relation messages
        % remain trainable and the MLP still receives only the graph
        % embedding; this is not a raw-observation bypass.
        if isfield(schema,'variant') && startsWith(schema.variant, ...
                'minimal_observation_rgat_')
            params.W0(:) = 0;
            d = min(dh,schema.inDim);
            params.W0(1:d,1:d) = eye(d);
        end
    otherwise
        error('landing2d:UnknownStateRepresentation', ...
            'encoderInit does not handle stateRepresentation %s.',mode);
end
switch gs.readout
    case 'decision_nodes'
        assert(ismember(mode,{'gat','ontology_rgat','context_gat','context_rgat'}) ...
            && ~isempty(spec.policyNode) && ~isempty(spec.valueNode), ...
            'landing2d:DecisionNodeReadout', ...
            'decision_nodes readout requires gat or ontology_rgat.');
        % H(:,PolicyNode) / H(:,ValueNode)를 그대로 반환하므로 별도 pooling
        % 파라미터가 없고 출력 폭은 노드 임베딩 폭과 같습니다.
        spec.graphDim = dh;
    case 'meanmax'
        % g_t = tanh(Wg*[mean(H_t,2); max(H_t,2)]+bg)
        params.Wg = scale*randn(rs,gs.graphDim,2*dh);
        params.bg = zeros(gs.graphDim,1);
        spec.graphDim = gs.graphDim;
    case 'mean'
        % g_t = mean(H_t,2). 추가 파라미터가 없습니다.
        spec.graphDim = dh;
    case 'grouped'
        assert(isfield(schema,'groupMatrix'),'landing2d:GroupedReadout', ...
            'Grouped readout requires schema.groupMatrix.');
        spec.groupMatrix = schema.groupMatrix;
        spec.groupNames = schema.groupNames;
        spec.groupCount = size(schema.groupMatrix,1);
        params.Wg = scale*randn(rs,gs.graphDim,dh*spec.groupCount);
        params.bg = zeros(gs.graphDim,1);
        spec.graphDim = gs.graphDim;
    case 'raw_plus_groups'
        assert(isfield(schema,'groupMatrix'),'landing2d:GroupedReadout', ...
            'Raw-plus-groups readout requires schema.groupMatrix.');
        spec.groupMatrix = schema.groupMatrix;
        spec.groupNames = schema.groupNames;
        spec.groupCount = size(schema.groupMatrix,1);
        % Zero initialization makes the initial representation exactly
        % [raw semantic state; zeros]. PPO can only add relational context;
        % it can never erase the semantic-flat information path.
        params.Wg = zeros(spec.groupCount,dh*spec.groupCount);
        params.bg = zeros(spec.groupCount,1);
        spec.graphDim = spec.stateDim+spec.groupCount;
    case 'observation_plus_groups'
        assert(isfield(schema,'groupMatrix'),'landing2d:GroupedReadout', ...
            'Observation-plus-groups readout requires schema.groupMatrix.');
        spec.groupMatrix = schema.groupMatrix;
        spec.groupNames = schema.groupNames;
        spec.groupCount = size(schema.groupMatrix,1);
        % Zero context preserves exact initial equality with plain PPO.
        params.Wg = zeros(spec.groupCount,dh*spec.groupCount);
        params.bg = zeros(spec.groupCount,1);
        spec.graphDim = spec.rawDim+spec.groupCount;
    otherwise
        error('landing2d:UnknownReadout','Unknown readout: %s',gs.readout);
end
end
