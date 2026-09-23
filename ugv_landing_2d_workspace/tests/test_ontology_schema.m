function test_ontology_schema()
% TEST_ONTOLOGY_SCHEMA  축소형 온톨로지 스키마와 그래프 생성의 일관성 확인.
schema = landing2d.ontology.nodeSchema();
n = schema.nNodes;
assert(numel(schema.nodeNames) == n);
assert(schema.goalNode == n,'The goal node is expected to be the last node.');
assert(schema.inDim == 4+n);
assert(all(schema.src >= 1 & schema.src <= n));
assert(all(schema.dst >= 1 & schema.dst <= n));
assert(all(schema.rel >= 1 & schema.rel <= schema.nRelations));
assert(numel(schema.src) == numel(schema.dst) && numel(schema.src) == numel(schema.rel));

% 모든 노드에 자기 간선이 있고, 목표 노드로 들어오는 간선이 있어야 함.
selfEdges = schema.src(schema.rel == schema.nRelations);
assert(isequal(sort(selfEdges),1:n),'Every node needs a self edge.');
assert(any(schema.dst == schema.goalNode & schema.rel ~= schema.nRelations));

% 보상항과 노드의 대응
allTermNodes = [schema.terms.nodes];
assert(numel(unique(allTermNodes)) == numel(allTermNodes), ...
    'Reward terms must not share ontology nodes.');
assert(all(allTermNodes >= 1 & allTermNodes <= n));
assert(~ismember(schema.goalNode,allTermNodes), ...
    'The goal node must not belong to a reward term.');

% 노드 특징 행렬
values = linspace(0,1,n);
X = landing2d.ontology.buildGraph(values,schema);
assert(isequal(size(X),[schema.inDim,n]));
for i = 1:n
    assert(abs(X(1,i)-values(i)) < 1e-12);
    assert(abs(X(2,i)-(1-values(i))) < 1e-12);
    assert(X(3,i) == double(ismember(i,schema.riskNodes)));
    assert(X(4,i) == 1);
    assert(X(4+i,i) == 1 && sum(X(5:end,i)) == 1);
end

% 최소 스키마: 모든 노드가 적어도 하나의 간선으로 목표 노드에 이어져야 함.
reach = false(1,n);
reach(schema.goalNode) = true;
for step = 1:n
    for e = 1:numel(schema.src)
        if schema.rel(e) ~= schema.nRelations && reach(schema.dst(e))
            reach(schema.src(e)) = true;
        end
    end
end
assert(all(reach),'Every node must reach the goal node through the graph.');

% 목표 노드 값은 미래 정답 누출을 막기 위해 항상 0
c = landing2d.config.defaultConfig();
[~,states,~] = landing2d.simulation.initialize(c);
s = states(1);
s.h = 3;
obs = landing2d.sensing.observePad(s,s.x+0.1,1,c);
memory = landing2d.rl.initialMemory(1);
truth = struct('error',0.1,'rate',0.2,'speed',1);
sem = landing2d.ontology.semanticState(s,obs,memory,truth,c);
nodes = landing2d.ontology.nodeValues(sem,schema);
assert(nodes(schema.goalNode) == 0);
assert(all(nodes >= 0 & nodes <= 1),'Every semantic channel must stay in [0,1].');
end
