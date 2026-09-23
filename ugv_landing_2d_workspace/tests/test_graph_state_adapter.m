function test_graph_state_adapter()
% TEST_GRAPH_STATE_ADAPTER  온톨로지 그래프 상태 표현의 정보경계와 그래프 무결성.
%
% 요구사항 20번의 Test 4(관측 정보경계)와 Test 5(그래프 무결성)에 해당합니다.
c = landing2d.config.defaultConfig();
c = landing2d.graphstate.applyStateRepresentation(c,'ontology_rgat');
[~,states,~] = landing2d.simulation.initialize(c);
s = states(1);
s.h = 2;
s.mode = 2;

%% Test 4 - 비가시 구간의 패드 참값이 그래프에 들어가지 않아야 함.
far = landing2d.sensing.observePad(s,s.x+100,7,c);
farther = landing2d.sensing.observePad(s,s.x+1000,30,c);
assert(~far.visible && ~farther.visible);
memory = landing2d.rl.initialMemory(1.0);
dtAction = c.dt*c.rl.actionInterval;
[~,memoryA] = landing2d.rl.observation(s,far,memory,c,dtAction);
[~,memoryB] = landing2d.rl.observation(s,farther,memory,c,dtAction);
a = landing2d.graphstate.situationGraph(s,far,memoryA,c);
b = landing2d.graphstate.situationGraph(s,farther,memoryB,c);
assert(isequal(a,b), ...
    'The invisible pad truth must not change the ontology graph.');
assert(all(isfinite(a)),'The node feature matrix must be finite.');

% 보이는 동안에는 관측 오차가 그래프에 반영되어야 함.
s.mode = 1;
near = landing2d.sensing.observePad(s,s.x+0.2,1.5,c);
assert(near.visible);
[~,memoryNear] = landing2d.rl.observation(s,near,memory,c,dtAction);
[~,detail] = landing2d.graphstate.situationGraph(s,near,memoryNear,c);
schema = detail.schema;
positionIndex = nodeIndex(schema,'PositionError');
expected = 0.2/(0.2+c.graphState.positionScale);
assert(abs(detail.values(positionIndex)-expected) < 1e-12, ...
    'PositionError must follow the observed horizontal error.');

% 부드러운 포화라 어느 구간에서도 기울기가 0이 아니어야 합니다. 잘라내기였을 때는
% 패드 근처(또는 먼 거리)에서 값이 상수가 되어 정책이 크기를 구분하지 못했습니다.
% 시야 밖에서는 관측이 아니라 추측 항법 기억값을 쓰므로, 기억값을 바꿔 가며
% 2 cm에서 30 m까지 넓은 범위를 확인합니다.
occluded = landing2d.sensing.observePad(s,s.x+1e4,1.5,c);
assert(~occluded.visible);
previous = -inf;
previousDistance = -inf;
for e = [0.02 0.05 0.1 0.3 1.0 3.0 10.0 30.0]
    guess = memory;
    guess.lastError = e;
    sample = landing2d.graphstate.observationSemantics(s,occluded,guess,c);
    assert(sample.PositionError > previous, ...
        sprintf('PositionError must stay strictly increasing at %.2f m.',e));
    assert(sample.PositionError < 1,'Node values must stay inside [0,1).');
    assert(sample.RelativeDistance > previousDistance, ...
        sprintf('RelativeDistance must stay strictly increasing at %.2f m.',e));
    previous = sample.PositionError;
    previousDistance = sample.RelativeDistance;
end

% 그래프가 쓰는 채널이 기준 관측이 쓰는 정보와 같은 집합인지 출처 표로 확인.
[sem,sources] = landing2d.graphstate.observationSemantics(s,near,memoryNear,c);
allowed = {'obs.','memory.','s.','constant'};
names = fieldnames(sources);
for i = 1:numel(names)
    text = sources.(names{i});
    assert(any(cellfun(@(p)contains(text,p),allowed)), ...
        sprintf('Node %s has an undocumented data source: %s',names{i},text));
    assert(~contains(text,'xUgv') && ~contains(text,'vxUgv') ...
        && ~contains(text,'truth'), ...
        sprintf('Node %s claims a privileged source: %s',names{i},text));
end

% 참값을 쓰는 옛 경로(semanticState)와 달리, 이 적응 계층은 truth 인자를 받지
% 않습니다. 함수 서명 자체가 정보경계를 강제합니다.
assert(nargin('landing2d.graphstate.observationSemantics') == 4, ...
    'observationSemantics must take only (s,obs,memory,c).');
assert(nargin('landing2d.ontology.semanticState') == 5, ...
    'The legacy semanticState keeps its truth argument and stays separate.');

%% Test 5 - 그래프 무결성. 노드/간선/관계/특징 차원과 값 범위.
for mode = {'ontology_rgat','gat','node_pool'}
    name = mode{1};
    [modeSchema,T] = landing2d.graphstate.schemaFor(name);
    assert(modeSchema.nNodes == 9,'The situation graph keeps the 9 ontology nodes.');
    assert(numel(modeSchema.src) == numel(modeSchema.dst) ...
        && numel(modeSchema.src) == numel(modeSchema.rel));
    assert(all(modeSchema.src >= 1 & modeSchema.src <= modeSchema.nNodes));
    assert(all(modeSchema.dst >= 1 & modeSchema.dst <= modeSchema.nNodes));
    assert(all(modeSchema.rel >= 1 & modeSchema.rel <= modeSchema.nRelations));
    % 상태 표현용 특징은 방향 부호 채널이 하나 더 있습니다.
    assert(modeSchema.inDim == 5+modeSchema.nNodes);
    assert(T.nEdges == numel(modeSchema.src));
    assert(T.nNodes == modeSchema.nNodes && T.nRelations == modeSchema.nRelations);
    % 모든 노드에 자기 간선이 있어야 자기 특징이 보존됩니다.
    selfCovered = false(1,modeSchema.nNodes);
    for e = 1:numel(modeSchema.src)
        if modeSchema.src(e) == modeSchema.dst(e)
            selfCovered(modeSchema.src(e)) = true;
        end
    end
    assert(all(selfCovered),'Every node needs a self edge.');
end

% 관계 유형 유지 여부. 제안 모델은 4가지, gat 제거 실험은 1가지.
typed = landing2d.graphstate.schemaFor('ontology_rgat');
collapsed = landing2d.graphstate.schemaFor('gat');
assert(typed.nRelations == 4, ...
    'The proposed graph must keep the four ontology relation types.');
assert(isequal(typed.relationNames, ...
    {'degrades','supports','contributes','self'}));
assert(collapsed.nRelations == 1, ...
    'The gat ablation collapses every relation into one adjacency.');
assert(isequal(typed.src,collapsed.src) && isequal(typed.dst,collapsed.dst), ...
    'Collapsing relation types must not change the graph structure.');

%% 대표 상태 몇 개에서 노드 값과 특징 행렬 점검.
cases = representativeCases(c);
for k = 1:numel(cases)
    sample = cases(k);
    [S,info] = landing2d.graphstate.situationGraph(sample.s,sample.obs, ...
        sample.memory,c);
    values = info.values;
    assert(all(isfinite(values)),'Node values must be finite.');
    assert(all(values >= 0 & values <= 1), ...
        'Every ontology node value must stay inside [0,1].');
    assert(values(info.schema.goalNode) == 0, ...
        'The goal node must stay 0 so no future label leaks in.');
    X = info.X;
    assert(isequal(size(X),[info.schema.inDim,info.schema.nNodes]));
    assert(all(isfinite(X(:))));
    assert(numel(S) == info.schema.inDim*info.schema.nNodes);
    for i = 1:info.schema.nNodes
        assert(abs(X(1,i)-values(i)) < 1e-12);
        assert(abs(X(2,i)-(1-values(i))) < 1e-12);
        assert(X(3,i) == double(ismember(i,info.schema.riskNodes)));
        assert(X(4,i) == 1);
        assert(abs(X(5,i)) <= 1,'The signed channel must stay inside [-1,1].');
        assert(X(5+i,i) == 1 && sum(X(6:end,i)) == 1);
    end
end
assert(isstruct(sem));

%% 방향 부호가 실제로 보존되는지. 온톨로지 노드 값은 모두 절댓값이라
% 이 채널이 없으면 좌/우와 상승/하강을 구분하지 못합니다.
s = states(1);
s.h = 3;
s.mode = 2;
s.vz = -0.3;
left = landing2d.sensing.observePad(s,s.x-0.4,1.5,c);
right = landing2d.sensing.observePad(s,s.x+0.4,1.5,c);
assert(left.visible && right.visible);
[~,ml] = landing2d.rl.observation(s,left,memory,c,dtAction);
[~,mr] = landing2d.rl.observation(s,right,memory,c,dtAction);
[~,dl] = landing2d.graphstate.situationGraph(s,left,ml,c);
[~,dr] = landing2d.graphstate.situationGraph(s,right,mr,c);
assert(max(abs(dl.values-dr.values)) < 1e-12, ...
    'Ontology node values are magnitudes, so they cannot tell left from right.');
assert(dl.signed.PositionError < 0 && dr.signed.PositionError > 0, ...
    'The signed channel must recover the direction of the horizontal error.');
assert(dl.signed.FovMargin < 0 && dr.signed.FovMargin > 0);
% 상승과 하강도 구분되어야 합니다.
climbing = s; climbing.vz = 0.3;
[~,dc] = landing2d.graphstate.situationGraph(climbing,right,mr,c);
assert(abs(dc.values(nodeIndex(schema,'DescentSpeed')) ...
    -dr.values(nodeIndex(schema,'DescentSpeed'))) < 1e-12);
assert(dr.signed.DescentSpeed < 0 && dc.signed.DescentSpeed > 0, ...
    'The signed channel must separate climbing from descending.');

%% 추종 구간과 탐색 구간이 구분되어야 합니다.
% 교사의 수직 명령이 구간에 따라 정반대이므로(h<1.5 m에서 az 평균 0.02 대 2.01),
% 이 구분이 없으면 종말단계 하강 제어를 학습할 수 없습니다.
tracking = s; tracking.mode = 1;
searching = s; searching.mode = 2;
[~,~,st] = landing2d.graphstate.observationSemantics(tracking,right,mr,c);
[~,~,ss] = landing2d.graphstate.observationSemantics(searching,right,mr,c);
assert(st.PadVisibility > 0 && ss.PadVisibility < 0, ...
    'The graph must separate the tracking phase from the search phase.');
landedState = s; landedState.mode = 3;
[~,~,sl] = landing2d.graphstate.observationSemantics(landedState,right,mr,c);
assert(sl.PadVisibility == 0,'A finished episode has no tracking direction.');
% 이 정보는 기준 관측 벡터에도 있으므로 특권 정보가 아닙니다.
[ot,~] = landing2d.rl.observation(tracking,right,memory,c,dtAction);
[os,~] = landing2d.rl.observation(searching,right,memory,c,dtAction);
assert(ot(2) ~= os(2), ...
    'The baseline observation already carries the tracking mode.');
end

function index = nodeIndex(schema,name)
index = find(strcmp(schema.nodeNames,name),1);
assert(~isempty(index),'Missing ontology node %s.',name);
end

function cases = representativeCases(c)
% 대표 상태: 높은 곳에서 포착, 시야 가장자리, 시야 이탈 후 탐색, 접지 직전, 착륙 완료.
[~,states,~] = landing2d.simulation.initialize(c);
base = states(1);
cases = struct('s',{},'obs',{},'memory',{});
cases(1) = makeCase(base,6.0,1,0.1,1.5,c,0);
cases(2) = makeCase(base,3.0,2,3.0*tand(c.cameraFovDeg/2)*0.99,5.0,c,0);
cases(3) = makeCase(base,4.0,2,1e4,7.0,c,3.0);
cases(4) = makeCase(base,0.05,2,0.01,2.0,c,0);
cases(5) = makeCase(base,0.0,3,0.0,2.0,c,0);
end

function item = makeCase(base,h,mode,offset,padSpeed,c,timeSinceSeen)
s = base;
s.h = h;
s.mode = mode;
s.vz = -0.3;
s.vx = padSpeed-0.2;
obs = landing2d.sensing.observePad(s,s.x+offset,padSpeed,c);
memory = landing2d.rl.initialMemory(padSpeed);
memory.lastError = min(offset,5);
memory.timeSinceSeen = timeSinceSeen;
item = struct('s',s,'obs',obs,'memory',memory);
end
