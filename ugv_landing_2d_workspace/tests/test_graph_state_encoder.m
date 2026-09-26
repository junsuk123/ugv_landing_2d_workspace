function test_graph_state_encoder()
% TEST_GRAPH_STATE_ENCODER  그래프 부호기의 기울기, 치환 정합, 읽기 범위 점검.
%
% 요구사항 20번의 Test 6(치환 정합), Test 7(R-GAT 기울기), Test 8(읽기 범위)에
% 해당합니다. 기울기는 중앙 차분과 비교합니다.
gs = landing2d.graphstate.defaultGraphStateConfig();
gs.hiddenDim = 5;
gs.relationDim = 3;
gs.graphDim = 4;

%% Test 7 - 부호기 기울기가 중앙 차분과 맞는지 (모드/읽기 조합 전부)
for mode = {'ontology_rgat','gat','node_pool'}
    for readout = {'meanmax','mean'}
        checkGradients(gs,mode{1},readout{1});
    end
end

%% 기준 모델의 부호기는 항등이어야 함 (기준 수치 보존)
baselineGs = gs;
baselineGs.stateRepresentation = 'baseline';
rs = RandStream('threefry','Seed',11);
[params,spec] = landing2d.graphstate.encoderInit(baselineGs,11,rs);
assert(isempty(fieldnames(params)), ...
    'The baseline encoder must hold no parameters.');
assert(spec.stateDim == 11 && spec.graphDim == 11);
S = randn(rs,11,7);
g = landing2d.graphstate.encoderForward(params,spec,S);
assert(isequal(g,S),'The baseline encoder must be the identity map.');
[grads,dS] = landing2d.graphstate.encoderBackward(params,spec, ...
    struct('mode','baseline'),S);
assert(isempty(fieldnames(grads)) && isequal(dS,S));
% 빈 부호기가 Adam과 기울기 노름에 아무 영향도 주지 않아야 합니다.
assert(landing2d.util.clipGradient(struct('a',3),1).a ...
    == landing2d.util.clipGradient(struct('a',3,'encoder',struct()),1).a, ...
    'An empty encoder must not change the clipped gradient norm.');

% Semantic-flat receives exactly the graph feature tensor, but has no graph
% encoder parameters or message passing.
flatGs = gs;
flatGs.stateRepresentation = 'semantic_flat';
[flatParams,flatSpec] = landing2d.graphstate.encoderInit(flatGs,11,rs);
flatState = randn(rs,flatSpec.stateDim,4);
flatOutput = landing2d.graphstate.encoderForward(flatParams,flatSpec,flatState);
assert(isempty(fieldnames(flatParams)) && isequal(flatOutput,flatState));

%% Test 6 - 노드 이름표를 바꿔도 그래프 수준 표현이 같아야 함.
% 노드를 다시 번호 매기면서 간선과 노드 특징을 함께 옮기면, R-GAT은 같은 임베딩을
% 순서만 바꿔 내놓고 평균/최댓값 읽기는 순서에 무관하므로 g_t가 같아야 합니다.
% 노드 특징 벡터는 정체성 one-hot까지 노드를 따라갑니다. 이것이 "같은 그래프"입니다.
for mode = {'ontology_rgat','gat'}
    checkPermutation(gs,mode{1});
end

%% Test 8 - 읽기가 모든 노드를 쓰는지. 이 그래프에는 덧붙임(padding)이 없습니다.
% 노드 수가 스키마에 고정되어 있어 가변 길이 배치가 없고, 따라서 가림(mask)이
% 필요 없습니다. 대신 "무시되는 노드가 없다"를 직접 확인합니다.
checkEveryNodeMatters(gs,'ontology_rgat');
end

% ---------------------------------------------------------------- 기울기 점검
function checkGradients(gs,mode,readout)
gs.stateRepresentation = mode;
gs.readout = readout;
rs = RandStream('threefry','Seed',17);
[params,spec] = landing2d.graphstate.encoderInit(gs,11,rs);
batch = 3;
S = 0.5*randn(rs,spec.stateDim,batch);
W = randn(rs,spec.graphDim,batch);   % 고정 가중치로 스칼라 손실을 만듭니다.
[loss,grads] = lossAndGrads(params,spec,S,W);
assert(isfinite(loss));
names = fieldnames(params);
assert(~isempty(names),'A graph encoder must have trainable parameters.');
step = 1e-6;
for n = 1:numel(names)
    key = names{n};
    total = numel(params.(key));
    indices = unique([1,round(total/2),total]);
    for i = indices
        plus = params; minus = params;
        plus.(key)(i) = plus.(key)(i)+step;
        minus.(key)(i) = minus.(key)(i)-step;
        numeric = (lossAndGrads(plus,spec,S,W) ...
            -lossAndGrads(minus,spec,S,W))/(2*step);
        analytic = grads.(key)(i);
        tolerance = 1e-4*max(abs(numeric),1e-6)+1e-9;
        assert(abs(numeric-analytic) <= tolerance, ...
            sprintf('Encoder gradient mismatch (%s/%s) at %s(%d): %.3e vs %.3e', ...
            mode,readout,key,i,numeric,analytic));
    end
    % Test 7: 부호기 파라미터가 실제로 0이 아닌 기울기를 받아야 합니다.
    assert(norm(grads.(key)(:)) > 0, ...
        sprintf('Encoder parameter %s received a zero gradient (%s/%s).', ...
        key,mode,readout));
end
end

function [loss,grads] = lossAndGrads(params,spec,S,W)
[g,cache] = landing2d.graphstate.encoderForward(params,spec,S);
loss = sum(sum(W.*g));
if nargout > 1
    grads = landing2d.graphstate.encoderBackward(params,spec,cache,W);
end
end

% ------------------------------------------------------------- 치환 정합 점검
function checkPermutation(gs,mode)
gs.stateRepresentation = mode;
rs = RandStream('threefry','Seed',23);
[params,spec] = landing2d.graphstate.encoderInit(gs,11,rs);
schema = spec.schema;
N = schema.nNodes;
values = rand(rs,1,N);
values(schema.goalNode) = 0;
signed = signedSample(schema,rs);
X = landing2d.graphstate.nodeFeatures(values,signed,schema);
g = landing2d.graphstate.encoderForward(params,spec,X(:));

p = randperm(rs,N);            % 새 위치 j 에 놓일 옛 노드 번호 p(j)
inverse = zeros(1,N);
inverse(p) = 1:N;
% 노드 특징 벡터 전체가 노드를 따라갑니다. 정체성 one-hot도 마찬가지입니다.
% 온톨로지에서 노드 정체성은 의미의 일부이므로(PositionError와 FovMargin은
% 값이 같아도 다른 노드입니다), 정체성은 번호가 아니라 노드에 붙어 있어야
% "같은 그래프"입니다. 바뀌는 것은 저장 순서뿐입니다.
Xp = X(:,p);
permutedSchema = schema;
permutedSchema.src = inverse(schema.src);
permutedSchema.dst = inverse(schema.dst);
permutedSchema.goalNode = inverse(schema.goalNode);
permutedSpec = spec;
permutedSpec.schema = permutedSchema;
permutedSpec.T = landing2d.rgat.topology(permutedSchema);
gPermuted = landing2d.graphstate.encoderForward(params,permutedSpec,Xp(:));
assert(norm(g-gPermuted) < 1e-10, ...
    sprintf(['Relabelling the nodes changed the graph representation ' ...
    '(%s): %.3e'],mode,norm(g-gPermuted)));
end

% ------------------------------------------- 모든 노드가 읽기에 기여하는지 점검
function checkEveryNodeMatters(gs,mode)
gs.stateRepresentation = mode;
rs = RandStream('threefry','Seed',29);
[params,spec] = landing2d.graphstate.encoderInit(gs,11,rs);
% 무작위 초기값은 너무 작아 차이가 묻힐 수 있으므로 조금 키웁니다.
params.W1 = 5*params.W1;
params.W2 = 5*params.W2;
schema = spec.schema;
N = schema.nNodes;
values = 0.5*ones(1,N);
values(schema.goalNode) = 0;
signed = signedSample(schema,[]);
X = landing2d.graphstate.nodeFeatures(values,signed,schema);
reference = landing2d.graphstate.encoderForward(params,spec,X(:));
for i = 1:N
    if i == schema.goalNode
        continue;   % 목표 노드 값은 언제나 0으로 고정입니다
    end
    changed = values;
    changed(i) = 0.9;
    Xi = landing2d.graphstate.nodeFeatures(changed,signed,schema);
    gi = landing2d.graphstate.encoderForward(params,spec,Xi(:));
    assert(norm(gi-reference) > 1e-9, ...
        sprintf(['Node %s does not reach the graph readout. The readout ' ...
        'must use every node.'],schema.nodeNames{i}));
end
% 덧붙임 노드가 없다는 사실을 명시적으로 기록합니다.
assert(spec.nNodes == schema.nNodes, ...
    'The situation graph has a fixed node count and needs no padding mask.');
end

function signed = signedSample(schema,rs)
% 방향 부호 채널의 시험값. 방향이 없는 노드는 0으로 둡니다.
signed = struct();
directional = {'PositionError','DescentSpeed','PadMotion','FovMargin'};
for i = 1:numel(schema.nodeNames)
    name = schema.nodeNames{i};
    if ~ismember(name,directional)
        signed.(name) = 0;
    elseif isempty(rs)
        signed.(name) = 0.3;
    else
        signed.(name) = 2*rand(rs)-1;
    end
end
end
