function test_ontology_view_model()
% TEST_ONTOLOGY_VIEW_MODEL  온톨로지 읽기 전용 어댑터와 상세 원문 생성 확인.
% 그래픽을 만들지 않으므로 run_tests(false)에서도 실행됩니다.

%% 1) 실제 소스 세 가지를 모두 읽고 원본으로 역추적할 수 있는지
for source = {'ontology','ontology_design','graphstate'}
    key = source{1};
    model = landing2d.viz.ontologyViewModel(key);
    schema = sourceSchema(key);
    assert(model.nElements == schema.nNodes, ...
        '%s: 요소 수가 스키마와 다릅니다.',key);
    assert(model.nRelations == numel(schema.src), ...
        '%s: 관계 수가 스키마와 다릅니다.',key);
    assert(numel(unique({model.elements.id})) == model.nElements, ...
        '%s: 요소 ID가 유일하지 않습니다.',key);
    assert(numel(unique({model.relations.id})) == model.nRelations, ...
        '%s: 관계 ID가 유일하지 않습니다.',key);
    for i = 1:model.nElements
        assert(strcmp(model.elements(i).name,schema.nodeNames{i}));
        assert(~isempty(model.elements(i).origin), ...
            '%s: 요소에 원본 참조가 없습니다.',key);
    end
    % source -> target 방향과 관계 유형이 원본 그대로인지
    for e = 1:model.nRelations
        r = model.relations(e);
        assert(r.sourceIndex == schema.src(e) && r.targetIndex == schema.dst(e), ...
            '%s: 간선 %d의 방향이 원본과 다릅니다.',key,e);
        assert(r.predicateIndex == schema.rel(e));
        assert(strcmp(r.predicate,schema.relationNames{schema.rel(e)}));
        assert(~isempty(r.origin));
    end
    assert(~isempty(model.metadata.sourceFile));
    assert(~isempty(model.metadata.viewKind));
end

%% 2) 온톨로지와 학습 입력 그래프를 구분해 표시하는지
ontologyModel = landing2d.viz.ontologyViewModel('ontology');
stateModel = landing2d.viz.ontologyViewModel('graphstate');
assert(~strcmp(ontologyModel.metadata.viewKind,stateModel.metadata.viewKind), ...
    '두 표현의 표시 대상 이름이 같으면 화면에서 구분할 수 없습니다.');
assert(~isempty(ontologyModel.mapping) && ~isempty(stateModel.mapping), ...
    '코드에서 확인되는 대응은 상세정보로 남아 있어야 합니다.');

% 제거 실험 표현은 관계 유형이 합쳐져 있다는 사실을 경고로 남겨야 함
gatModel = landing2d.viz.ontologyViewModel('graphstate', ...
    struct('stateRepresentation','gat'));
assert(~isempty(gatModel.metadata.warnings), ...
    'gat 표현은 관계 유형이 합쳐졌다는 경고를 남겨야 합니다.');
assert(numel(gatModel.predicates) == 1);

%% 3) baseline은 그래프가 아니므로 거부하는지
threw = false;
try
    landing2d.viz.ontologyViewModel('graphstate', ...
        struct('stateRepresentation','baseline'));
catch err
    threw = strcmp(err.identifier,'landing2d:OntologyViewSource');
end
assert(threw,'baseline 관측 벡터는 그래프가 아니므로 거부해야 합니다.');

%% 4) 확인되지 않은 분류를 만들어 내지 않는지 (최소 스키마)
fixture = fixtureSchema();
before = fixture;
model = landing2d.viz.ontologyViewModel(fixture);
assert(isequal(before,fixture),'어댑터가 전달된 원본 구조체를 바꾸었습니다.');
for i = 1:model.nElements
    assert(strcmp(model.elements(i).role,'유형 미확인'), ...
        '분류 근거가 없는 요소는 유형 미확인으로 표시해야 합니다.');
    assert(strcmp(model.elements(i).description,'(원본에 설명 필드 없음)'));
end
kinds = {model.statements.kind};
assert(~any(strcmp(kinds,'보상항 대응 선언')), ...
    '원본에 없는 보상항 선언을 만들어 냈습니다.');
assert(all(strcmp({model.statements.status},'명시적 선언 (추론 아님)')), ...
    '추론기를 돌리지 않았으므로 추론 결과로 표시하면 안 됩니다.');
for r = 1:numel(model.predicates)
    assert(contains(model.predicates(r).declaredDomain,'없음'));
    assert(contains(model.predicates(r).declaredRange,'없음'));
end

%% 5) 평행 관계, 자기 연결, 순환, 고립 노드, 중복 이름 보존
assert(model.nRelations == numel(fixture.src));
parallel = 0;
for e = 1:model.nRelations
    if model.relations(e).sourceIndex == 1 && model.relations(e).targetIndex == 2
        parallel = parallel+1;
    end
end
assert(parallel == 2,'평행 관계 두 개가 하나로 합쳐졌습니다.');
assert(any([model.relations.isSelf]),'자기 연결이 사라졌습니다.');
assert(strcmp(model.elements(1).name,model.elements(3).name), ...
    '이 고정 자료는 같은 표시 이름을 가진 서로 다른 요소를 담고 있어야 합니다.');
assert(~strcmp(model.elements(1).id,model.elements(3).id), ...
    '같은 이름의 다른 요소가 하나로 합쳐졌습니다.');
isolated = model.elements(5).index;
touched = false;
for e = 1:model.nRelations
    r = model.relations(e);
    touched = touched || r.sourceIndex == isolated || r.targetIndex == isolated;
end
assert(~touched,'이 고정 자료의 5번 요소는 고립 노드여야 합니다.');

%% 6) 스냅샷 크기가 맞지 않으면 조용히 채우지 않고 거부
threw = false;
try
    landing2d.viz.ontologyViewModel('ontology', ...
        struct('snapshot',struct('values',zeros(1,3))));
catch err
    threw = strcmp(err.identifier,'landing2d:OntologyViewSnapshot');
end
assert(threw,'노드 수가 다른 스냅샷은 거부해야 합니다.');

% 크기가 맞는 스냅샷은 출처와 함께 속성으로 들어가야 함
schema = landing2d.ontology.nodeSchema('core');
values = linspace(0,1,schema.nNodes);
snapModel = landing2d.viz.ontologyViewModel('ontology', ...
    struct('snapshot',struct('values',values,'label','테스트 스냅샷')));
found = false;
for k = 1:numel(snapModel.attributes)
    a = snapModel.attributes(k);
    if strcmp(a.elementId,'N01') && contains(a.name,'노드 값')
        found = true;
        assert(abs(a.value-values(1)) < 1e-12);
        assert(contains(a.origin,'테스트 스냅샷'));
    end
end
assert(found,'스냅샷 값이 속성으로 들어가지 않았습니다.');
assert(contains(snapModel.metadata.snapshotId,'테스트 스냅샷'));

%% 7) 상세 원문: 요약 / 요소 / 관계 / 선언 / 행렬 셀
model = landing2d.viz.ontologyViewModel('ontology');
summary = strjoin(landing2d.viz.ontologyDetailText(model, ...
    struct('kind','summary')),newline);
assert(contains(summary,model.metadata.sourceFile),'요약에 데이터 출처가 없습니다.');
assert(contains(summary,'OWL'),'원본에 없는 OWL 계층에 대한 안내가 필요합니다.');
for k = 1:numel(model.statements)
    assert(contains(summary,model.statements(k).id), ...
        '그래프에 펼치지 않은 선언 %s의 조회 진입점이 없습니다.',model.statements(k).id);
end

elementText = strjoin(landing2d.viz.ontologyDetailText(model, ...
    struct('kind','element','id','N01')),newline);
assert(contains(elementText,'N01') && contains(elementText,'PositionError'));
assert(contains(elementText,'nodeSchema.m'),'요소 상세에 원본 출처가 없습니다.');
assert(contains(elementText,'neutralValue'),'속성이 상세에 나오지 않습니다.');

relationText = strjoin(landing2d.viz.ontologyDetailText(model, ...
    struct('kind','relation','id',model.relations(1).id)),newline);
assert(contains(relationText,'domain'),'관계 상세에 domain 선언 상태가 없습니다.');
assert(contains(relationText,'인과관계'),'인과로 읽지 말라는 주의가 필요합니다.');

statementText = strjoin(landing2d.viz.ontologyDetailText(model, ...
    struct('kind','statement','id','S001')),newline);
assert(contains(statementText,'명시적 선언'));

emptyCell = strjoin(landing2d.viz.ontologyDetailText(model, ...
    struct('kind','cell','sourceId','N09','targetId','N01')),newline);
assert(contains(emptyCell,'거짓'),'0의 뜻을 설명해야 합니다.');

% 같은 셀에 여러 관계가 걸리면 모두 보여야 함
multi = landing2d.viz.ontologyViewModel(fixtureSchema());
cellText = strjoin(landing2d.viz.ontologyDetailText(multi, ...
    struct('kind','cell','sourceId','N01','targetId','N02')),newline);
assert(contains(cellText,'rel_a') && contains(cellText,'rel_b'), ...
    '한 셀에 걸린 여러 관계를 모두 표시해야 합니다.');

%% 8) 고립 노드 상세
isolatedText = strjoin(landing2d.viz.ontologyDetailText(multi, ...
    struct('kind','element','id','N05')),newline);
assert(contains(isolatedText,'고립'),'고립 요소임을 밝혀야 합니다.');
end

% --------------------------------------------------------------------- 보조
function schema = sourceSchema(key)
switch key
    case 'ontology'
        schema = landing2d.ontology.nodeSchema('core');
    case 'ontology_design'
        schema = landing2d.ontology.nodeSchema('design');
    case 'graphstate'
        schema = landing2d.graphstate.schemaFor('ontology_rgat');
end
end

function schema = fixtureSchema()
% 검사 전용 최소 자료. 실제 온톨로지와 분리되어 있으며 화면 기본값이 아닙니다.
% 평행 관계, 자기 연결, 순환, 고립 노드, 중복 표시 이름을 한 번에 담습니다.
schema.nodeNames = {'Alpha','Beta','Alpha','Gamma','Lonely'};
schema.nNodes = 5;
schema.relationNames = {'rel_a','rel_b'};
schema.nRelations = 2;
schema.src = [1 1 2 3 4 2];
schema.dst = [2 2 1 3 1 4];
schema.rel = [1 2 1 2 1 1];
schema.variant = 'fixture';
end
