function model = ontologyViewModel(source,options)
% ONTOLOGYVIEWMODEL  기존 온톨로지 정의를 표시용 자료로 바꾸는 읽기 전용 어댑터.
%
%   model = landing2d.viz.ontologyViewModel(source,options)
%
% 이 함수는 원본을 읽기만 합니다. 스키마를 만들지도, 고치지도, 저장하지도 않습니다.
% 원본에 없는 클래스, 개체, 관계, 공리, 추론 결과를 새로 만들지 않습니다.
%
% source (문자열 또는 스키마 구조체)
%   'ontology'         landing2d.ontology.nodeSchema('core')   의미 그래프 (기본값)
%   'ontology_design'  landing2d.ontology.nodeSchema('design') 보상 가중치 설계용 확장
%   'graphstate'       landing2d.graphstate.schemaFor(mode)    강화학습 입력 그래프
%   구조체             호출자가 이미 읽어 둔 스키마를 그대로 사용
%
% options
%   .stateRepresentation  'graphstate'일 때의 표현 방식 (기본 'ontology_rgat')
%   .snapshot             현재 상태 스냅샷 (선택). 아래 항목만 읽습니다.
%       .values     [1 x nNodes] 노드 값
%       .signed     구조체 또는 [1 x nNodes] 방향 부호 채널
%       .sources    구조체. 노드 이름 -> 의미 채널의 원 자료 설명
%       .label      스냅샷 식별 문자열
%   .sourceFileOverride   구조체 source를 넘길 때 출처 문자열
%
% 돌려주는 model
%   .metadata   소스 경로, 스냅샷 식별자, 표시 대상 종류, 파싱 범위, 경고
%   .elements   원본 ID / 표시 이름 / 확인된 역할 / 설명 / 원본 참조
%   .relations  관계 ID / source ID / predicate / target ID / 원본 참조
%   .predicates 관계 유형 선언과 (선언되지 않은 경우) 관찰된 사용 범위
%   .attributes 소유 요소 ID / 속성명 / 원래 값 / 데이터형 / 단위 / 유효 상태 / 출처
%   .statements 그래프로 펼치지 않는 원본 선언 문장
%   .mapping    온톨로지와 학습 입력 그래프의 대응 (코드에서 확인되는 경우에만)
%   .schema     읽어 온 원본 스키마의 값 사본 (역추적용, 수정하지 않음)
if nargin < 1 || isempty(source)
    source = 'ontology';
end
if nargin < 2 || isempty(options)
    options = struct();
end
if ~(isstruct(options) && isscalar(options))
    error('landing2d:InvalidOptions','options는 스칼라 구조체여야 합니다.');
end

[schema,meta] = resolveSource(source,options);
snapshot = snapshotOf(options,schema,meta);
meta.snapshotId = snapshot.label;

elements = buildElements(schema,meta);
[predicates,meta] = buildPredicates(schema,meta);
relations = buildRelations(schema,elements,predicates,meta);
predicates = observedScope(predicates,relations,elements);
attributes = buildAttributes(schema,elements,snapshot,meta);
statements = buildStatements(schema,elements,predicates,meta);

model = struct();
model.metadata = meta;
model.elements = elements;
model.elementIds = {elements.id};
model.relations = relations;
model.predicates = predicates;
model.attributes = attributes;
model.statements = statements;
model.mapping = meta.mapping;
model.schema = schema;
model.nElements = schema.nNodes;
model.nRelations = numel(relations);
end

% ------------------------------------------------------------------ 소스 해석
function [schema,meta] = resolveSource(source,options)
meta = struct('sourceKey','','sourceLabel','','sourceFile','','variant','', ...
    'viewKind','','scope','','snapshotId','(없음)','warnings',{{}}, ...
    'mapping',{{}},'note','');
if isstruct(source)
    schema = source;
    meta.sourceKey = 'struct';
    meta.sourceLabel = '호출자가 전달한 스키마 구조체';
    meta.sourceFile = getOption(options,'sourceFileOverride','(호출자 제공)');
    meta.viewKind = '전달된 관계 그래프';
    assertSchema(schema,meta.sourceFile);
    if ~isfield(schema,'variant')
        schema.variant = '(미지정)';
    end
    meta.variant = schema.variant;
    meta.scope = '호출자가 전달한 스키마의 노드와 간선 전체';
    return;
end
if isstring(source) && isscalar(source)
    source = char(source);
end
if ~(ischar(source) && isrow(source))
    error('landing2d:OntologyViewSource', ...
        'source는 문자열이거나 스키마 구조체여야 합니다.');
end
switch lower(source)
    case 'ontology'
        schema = landing2d.ontology.nodeSchema('core');
        meta.sourceKey = 'ontology';
        meta.sourceLabel = '온톨로지 의미 그래프 (core)';
        meta.sourceFile = 'src/+landing2d/+ontology/nodeSchema.m (variant=core)';
        meta.viewKind = '온톨로지 의미 그래프';
        meta.scope = '노드 정의, 관계형 간선, 관계 유형, 보상항 대응 선언';
        meta.mapping = {sprintf(['강화학습 입력 그래프는 이 스키마를 그대로 읽습니다. ' ...
            'landing2d.graphstate.schemaFor가 nodeSchema(core)를 호출하며 ' ...
            '노드와 간선을 바꾸지 않습니다(gat 표현만 관계 유형을 하나로 합침). ' ...
            '노드 특징 행렬만 방향 부호 채널 하나가 더 붙어 inDim이 %d에서 %d가 됩니다.'], ...
            4+schema.nNodes,5+schema.nNodes)};
    case 'ontology_design'
        schema = landing2d.ontology.nodeSchema('design');
        meta.sourceKey = 'ontology_design';
        meta.sourceLabel = '온톨로지 의미 그래프 (design)';
        meta.sourceFile = 'src/+landing2d/+ontology/nodeSchema.m (variant=design)';
        meta.viewKind = '온톨로지 의미 그래프 (보상 가중치 설계용 확장)';
        meta.scope = '노드 정의, 관계형 간선, 관계 유형, 보상항 대응, 가중치/가치 노드 선언';
        meta.mapping = {['이 확장 변형은 보상 가중치 설계 경로 전용입니다. ' ...
            'landing2d.graphstate.schemaFor는 core 변형만 사용하므로 ' ...
            '강화학습 입력 그래프에는 들어가지 않습니다.']};
    case 'graphstate'
        mode = getOption(options,'stateRepresentation','ontology_rgat');
        if strcmpi(mode,'baseline')
            error('landing2d:OntologyViewSource', ...
                ['stateRepresentation=baseline은 그래프 상태 표현이 아니라 ' ...
                '11차원 관측 벡터입니다. 표시할 그래프가 없습니다.']);
        end
        schema = landing2d.graphstate.schemaFor(mode);
        meta.sourceKey = 'graphstate';
        meta.sourceLabel = sprintf('강화학습 입력 그래프 (%s)',mode);
        meta.sourceFile = sprintf( ...
            'src/+landing2d/+graphstate/schemaFor.m (mode=%s)',mode);
        meta.viewKind = '강화학습 입력 그래프 G_t';
        meta.scope = '노드 정의, 관계형 간선, 관계 유형, 노드 특징 구성';
        meta.mapping = {['이 그래프의 노드 집합과 간선 집합은 ' ...
            'landing2d.ontology.nodeSchema(core)에서 그대로 옵니다 ' ...
            '(landing2d.graphstate.schemaFor). 새 노드나 새 관계를 만들지 않습니다.']};
        if strcmpi(mode,'gat')
            meta.warnings{end+1} = ['제거 실험 표현입니다. 원본 관계 유형 4종이 ' ...
                'adjacent 하나로 합쳐져 있습니다(schemaFor.m). ' ...
                '원본 관계 구분을 보려면 표시 대상을 온톨로지 의미 그래프로 바꾸십시오.'];
        elseif strcmpi(mode,'node_pool')
            meta.warnings{end+1} = ['제거 실험 표현입니다. schemaFor.m 주석에 따르면 ' ...
                '이 표현의 부호기는 간선을 사용하지 않습니다. ' ...
                '아래 간선은 스키마에 기록된 구조이며 계산에 쓰이지 않습니다.'];
        end
    otherwise
        error('landing2d:OntologyViewSource', ...
            ['알 수 없는 source입니다: %s. ' ...
            'ontology / ontology_design / graphstate 중 하나이거나 ' ...
            '스키마 구조체여야 합니다.'],source);
end
assertSchema(schema,meta.sourceFile);
meta.variant = schema.variant;
end

function assertSchema(schema,where)
required = {'nodeNames','nNodes','src','dst','rel','relationNames','nRelations'};
for i = 1:numel(required)
    if ~isfield(schema,required{i})
        error('landing2d:OntologyViewSchema', ...
            '스키마에 필드 %s가 없습니다 (출처: %s).',required{i},where);
    end
end
if numel(schema.src) ~= numel(schema.dst) || numel(schema.src) ~= numel(schema.rel)
    error('landing2d:OntologyViewSchema', ...
        'src / dst / rel의 길이가 서로 다릅니다 (출처: %s).',where);
end
if numel(schema.nodeNames) ~= schema.nNodes
    error('landing2d:OntologyViewSchema', ...
        'nodeNames의 길이가 nNodes와 다릅니다 (출처: %s).',where);
end
end

function value = getOption(options,name,fallback)
if isfield(options,name) && ~isempty(options.(name))
    value = options.(name);
else
    value = fallback;
end
end

% ---------------------------------------------------------------- 스냅샷 해석
function snapshot = snapshotOf(options,schema,meta)
snapshot = struct('has',false,'values',[],'signed',[],'sources',struct(), ...
    'label','(없음 - 정적 스키마만 표시)');
if ~isfield(options,'snapshot') || isempty(options.snapshot)
    return;
end
s = options.snapshot;
if ~(isstruct(s) && isscalar(s))
    error('landing2d:OntologyViewSnapshot','snapshot은 스칼라 구조체여야 합니다.');
end
if isfield(s,'values') && ~isempty(s.values)
    v = s.values(:)';
    if numel(v) ~= schema.nNodes
        error('landing2d:OntologyViewSnapshot', ...
            ['snapshot.values의 길이(%d)가 노드 수(%d)와 다릅니다. ' ...
            '표시 대상 %s의 스키마와 같은 스냅샷인지 확인하십시오.'], ...
            numel(v),schema.nNodes,meta.sourceLabel);
    end
    snapshot.values = v;
    snapshot.has = true;
end
if isfield(s,'signed') && ~isempty(s.signed)
    snapshot.signed = s.signed;
end
if isfield(s,'sources') && isstruct(s.sources)
    snapshot.sources = s.sources;
end
if isfield(s,'label') && ~isempty(s.label)
    snapshot.label = char(s.label);
elseif snapshot.has
    snapshot.label = '(호출자 스냅샷, 이름 없음)';
end
end

% -------------------------------------------------------------------- 요소 목록
function elements = buildElements(schema,meta)
template = struct('id','','name','','label','','kind','','role','', ...
    'description','','origin','','index',0);
elements = repmat(template,1,schema.nNodes);
for i = 1:schema.nNodes
    elements(i).id = sprintf('N%02d',i);
    elements(i).name = schema.nodeNames{i};
    elements(i).label = schema.nodeNames{i};
    elements(i).kind = '그래프 노드';
    elements(i).role = elementRole(schema,i);
    elements(i).description = '(원본에 설명 필드 없음)';
    elements(i).origin = sprintf('%s : nodeNames{%d}',meta.sourceFile,i);
    elements(i).index = i;
end
end

function role = elementRole(schema,i)
% 원본 스키마가 명시한 필드만 근거로 삼습니다. 이름의 단어로 추측하지 않습니다.
if isfield(schema,'goalNode') && ~isempty(schema.goalNode) && i == schema.goalNode
    role = '목표 노드 (schema.goalNode)';
elseif isfield(schema,'weightNodes') && ismember(i,schema.weightNodes)
    role = '보상 가중치 노드 (schema.weightNodes)';
elseif isfield(schema,'valueNode') && ~isempty(schema.valueNode) && i == schema.valueNode
    role = '정책 가치 노드 (schema.valueNode)';
elseif isfield(schema,'riskNodes') && ismember(i,schema.riskNodes)
    role = '위험 노드 (schema.riskNodes)';
elseif isfield(schema,'riskNodes')
    role = '비위험 노드 (schema.riskNodes에 없음)';
else
    role = '유형 미확인';
end
end

% ---------------------------------------------------------------- 관계 유형 목록
function [predicates,meta] = buildPredicates(schema,meta)
template = struct('id','','name','','label','','declaredDomain','', ...
    'declaredRange','','observedDomain',{{}},'observedRange',{{}}, ...
    'count',0,'origin','','index',0);
predicates = repmat(template,1,schema.nRelations);
for r = 1:schema.nRelations
    predicates(r).id = sprintf('R%d',r);
    predicates(r).name = schema.relationNames{r};
    predicates(r).label = schema.relationNames{r};
    predicates(r).declaredDomain = '(원본에 domain 선언 없음)';
    predicates(r).declaredRange = '(원본에 range 선언 없음)';
    predicates(r).origin = sprintf('%s : relationNames{%d}',meta.sourceFile,r);
    predicates(r).index = r;
end
used = unique(schema.rel(:)');
if ~isempty(used) && (min(used) < 1 || max(used) > schema.nRelations)
    meta.warnings{end+1} = ['간선의 관계 번호가 relationNames 범위를 벗어납니다. ' ...
        '해당 간선은 유형 미확인으로 표시합니다.'];
end
end

function predicates = observedScope(predicates,relations,elements)
% 선언된 domain/range가 없으므로, 실제 간선에서 관찰된 사용 범위만 따로 적어 둡니다.
% 이것은 선언이 아니라 파생값이며 상세 패널에서도 그렇게 표시합니다.
for r = 1:numel(predicates)
    srcNames = {};
    dstNames = {};
    count = 0;
    for k = 1:numel(relations)
        if ~strcmp(relations(k).predicateId,predicates(r).id)
            continue;
        end
        count = count+1;
        srcNames{end+1} = elements(relations(k).sourceIndex).name; %#ok<AGROW>
        dstNames{end+1} = elements(relations(k).targetIndex).name; %#ok<AGROW>
    end
    predicates(r).count = count;
    predicates(r).observedDomain = unique(srcNames,'stable');
    predicates(r).observedRange = unique(dstNames,'stable');
end
end

% -------------------------------------------------------------------- 관계 목록
function relations = buildRelations(schema,elements,predicates,meta)
nEdges = numel(schema.src);
template = struct('id','','sourceId','','targetId','','predicateId','', ...
    'predicate','','sourceIndex',0,'targetIndex',0,'predicateIndex',0, ...
    'isSelf',false,'status','확인','origin','','index',0);
relations = repmat(template,1,nEdges);
unusedEdges = strcmp(meta.sourceKey,'graphstate') ...
    && contains(meta.sourceLabel,'node_pool');
for e = 1:nEdges
    i = schema.src(e);
    j = schema.dst(e);
    r = schema.rel(e);
    relations(e).id = sprintf('E%03d',e);
    relations(e).sourceIndex = i;
    relations(e).targetIndex = j;
    relations(e).predicateIndex = r;
    relations(e).sourceId = elements(i).id;
    relations(e).targetId = elements(j).id;
    if r >= 1 && r <= numel(predicates)
        relations(e).predicateId = predicates(r).id;
        relations(e).predicate = predicates(r).name;
    else
        relations(e).predicateId = sprintf('R%d',r);
        relations(e).predicate = '(relationNames에 없는 관계 번호)';
        relations(e).status = '유형 미확인';
    end
    relations(e).isSelf = (i == j);
    relations(e).origin = sprintf('%s : src/rel/dst의 %d번째 간선',meta.sourceFile,e);
    relations(e).index = e;
    if unusedEdges
        relations(e).status = '스키마에 기록됨 / 이 표현의 부호기는 사용하지 않음';
    end
end
end

% -------------------------------------------------------------------- 속성 목록
function attributes = buildAttributes(schema,elements,snapshot,meta)
template = struct('elementId','','name','','value',[],'valueText','', ...
    'dataType','','unit','','status','','origin','');
attributes = repmat(template,1,0);
termOf = termMembership(schema);
for i = 1:numel(elements)
    id = elements(i).id;
    attributes(end+1) = makeAttr(id,'노드 색인',i,sprintf('%d',i), ...
        'double','','확인 (선언)', ...
        sprintf('%s : 노드 순서',meta.sourceFile)); %#ok<AGROW>
    if isfield(schema,'riskNodes')
        flag = ismember(i,schema.riskNodes);
        attributes(end+1) = makeAttr(id,'위험 노드 여부',flag,boolText(flag), ...
            'logical','','확인 (선언)', ...
            sprintf('%s : riskNodes',meta.sourceFile)); %#ok<AGROW>
    end
    if isfield(schema,'neutralValue') && numel(schema.neutralValue) >= i
        v = schema.neutralValue(i);
        attributes(end+1) = makeAttr(id,'반사실 기준값 neutralValue',v, ...
            sprintf('%g',v),'double','정규화 값 [0,1]','확인 (선언)', ...
            sprintf('%s : neutralValue(%d)',meta.sourceFile,i)); %#ok<AGROW>
    end
    if ~isempty(termOf{i})
        attributes(end+1) = makeAttr(id,'보상항 소속',termOf{i},termOf{i}, ...
            'char','','확인 (선언)', ...
            sprintf('%s : terms(...).nodes',meta.sourceFile)); %#ok<AGROW>
    end
    if snapshot.has
        v = snapshot.values(i);
        attributes(end+1) = makeAttr(id,'노드 값 (스냅샷)',v,sprintf('%.6g',v), ...
            'double','정규화 값','확인 (스냅샷)', ...
            sprintf('snapshot.values(%d) / %s',i,snapshot.label)); %#ok<AGROW>
    end
    sv = signedValue(snapshot,elements(i).name,i);
    if ~isempty(sv)
        attributes(end+1) = makeAttr(id,'방향 부호 채널 (스냅샷)',sv, ...
            sprintf('%.6g',sv),'double','[-1,1]','확인 (스냅샷)', ...
            sprintf('snapshot.signed.%s / %s',elements(i).name, ...
            snapshot.label)); %#ok<AGROW>
    end
    if isfield(snapshot.sources,elements(i).name)
        txt = snapshot.sources.(elements(i).name);
        attributes(end+1) = makeAttr(id,'의미 채널 원 자료',txt,txt, ...
            'char','','확인 (스냅샷)', ...
            sprintf('snapshot.sources.%s',elements(i).name)); %#ok<AGROW>
    end
end
end

function a = makeAttr(elementId,name,value,valueText,dataType,unit,status,origin)
a = struct('elementId',elementId,'name',name,'value',value, ...
    'valueText',valueText,'dataType',dataType,'unit',unit, ...
    'status',status,'origin',origin);
end

function text = boolText(flag)
if flag
    text = 'true';
else
    text = 'false';
end
end

function value = signedValue(snapshot,name,index)
value = [];
if isempty(snapshot.signed)
    return;
end
if isstruct(snapshot.signed)
    if isfield(snapshot.signed,name)
        value = snapshot.signed.(name);
    end
elseif isnumeric(snapshot.signed) && numel(snapshot.signed) >= index
    value = snapshot.signed(index);
end
end

function termOf = termMembership(schema)
termOf = repmat({''},1,schema.nNodes);
if ~isfield(schema,'terms') || isempty(schema.terms)
    return;
end
for k = 1:numel(schema.terms)
    nodes = schema.terms(k).nodes;
    for m = 1:numel(nodes)
        idx = nodes(m);
        if idx < 1 || idx > schema.nNodes
            continue;
        end
        label = schema.terms(k).name;
        if isfield(schema.terms,'label') && ~isempty(schema.terms(k).label)
            label = sprintf('%s (%s)',schema.terms(k).name,schema.terms(k).label);
        end
        if isempty(termOf{idx})
            termOf{idx} = label;
        else
            termOf{idx} = [termOf{idx},', ',label];
        end
    end
end
end

% ---------------------------------------------------------------- 선언 문장 목록
function statements = buildStatements(schema,elements,predicates,meta)
% 원본 스키마가 명시적으로 담고 있는 선언만 옮겨 적습니다.
% 추론기를 돌리지 않았으므로 어떤 항목도 추론 결과로 표시하지 않습니다.
template = struct('id','','kind','','text','','refs',{{}}, ...
    'status','','origin','');
statements = repmat(template,1,0);
counter = 0;

if isfield(schema,'riskNodes')
    counter = counter+1;
    statements(end+1) = makeStatement(counter,'스키마 선언', ...
        sprintf('위험 노드 선언: %s. 값이 클수록 나쁜 노드입니다.', ...
        nameList(elements,schema.riskNodes)), ...
        idList(elements,schema.riskNodes), ...
        sprintf('%s : riskNodes',meta.sourceFile)); %#ok<AGROW>
end
if isfield(schema,'goalNode') && ~isempty(schema.goalNode)
    g = schema.goalNode;
    counter = counter+1;
    statements(end+1) = makeStatement(counter,'스키마 선언', ...
        sprintf('목표 노드 선언: %s (색인 %d).',elements(g).name,g), ...
        {elements(g).id},sprintf('%s : goalNode',meta.sourceFile)); %#ok<AGROW>
end
if isfield(schema,'neutralValue')
    counter = counter+1;
    statements(end+1) = makeStatement(counter,'스키마 선언', ...
        ['반사실 기준값 선언: 각 노드를 무해한 값으로 바꿀 때 쓰는 기준값 ' ...
        'neutralValue가 노드마다 선언되어 있습니다. 노드별 값은 속성 목록에 있습니다.'], ...
        {elements.id},sprintf('%s : neutralValue',meta.sourceFile)); %#ok<AGROW>
end
if isfield(schema,'terms') && ~isempty(schema.terms)
    for k = 1:numel(schema.terms)
        t = schema.terms(k);
        label = t.name;
        if isfield(t,'label') && ~isempty(t.label)
            label = sprintf('%s (%s)',t.name,t.label);
        end
        weightField = '(미지정)';
        if isfield(t,'weightField') && ~isempty(t.weightField)
            weightField = t.weightField;
        end
        counter = counter+1;
        statements(end+1) = makeStatement(counter,'보상항 대응 선언', ...
            sprintf(['보상항 %s는 온톨로지 노드 %s의 묶음에 대응하고, ' ...
            '설계 결과는 rl.%s에 들어갑니다.'], ...
            label,nameList(elements,t.nodes),weightField), ...
            idList(elements,t.nodes), ...
            sprintf('%s : terms(%d)',meta.sourceFile,k)); %#ok<AGROW>
    end
end
if isfield(schema,'weightNodes') && ~isempty(schema.weightNodes)
    counter = counter+1;
    statements(end+1) = makeStatement(counter,'스키마 선언', ...
        sprintf('보상 가중치 노드 선언: %s.', ...
        nameList(elements,schema.weightNodes)), ...
        idList(elements,schema.weightNodes), ...
        sprintf('%s : weightNodes',meta.sourceFile)); %#ok<AGROW>
end
if isfield(schema,'valueNode') && ~isempty(schema.valueNode)
    counter = counter+1;
    statements(end+1) = makeStatement(counter,'스키마 선언', ...
        sprintf('정책 가치 노드 선언: %s.', ...
        nameList(elements,schema.valueNode)), ...
        idList(elements,schema.valueNode), ...
        sprintf('%s : valueNode',meta.sourceFile)); %#ok<AGROW>
end
for r = 1:numel(predicates)
    counter = counter+1;
    statements(end+1) = makeStatement(counter,'관계 유형 선언', ...
        sprintf(['관계 유형 %s (%s): 원본에 domain/range 선언이 없습니다. ' ...
        '상세 패널의 관찰된 사용 범위는 실제 간선에서 뽑은 파생값입니다.'], ...
        predicates(r).name,predicates(r).id), ...
        {},predicates(r).origin); %#ok<AGROW>
end
if isfield(schema,'inDim')
    if strcmp(meta.sourceKey,'graphstate')
        featureText = sprintf(['노드 특징 선언: X_t = [값; 1-값; 위험 표시; 편향; ' ...
            '방향 부호; 노드 정체성 one-hot], inDim = %d ' ...
            '(landing2d.graphstate.nodeFeatures).'],schema.inDim);
    else
        featureText = sprintf(['노드 특징 선언: X = [값; 1-값; 위험 표시; 편향; ' ...
            '노드 정체성 one-hot], inDim = %d ' ...
            '(landing2d.ontology.buildGraph).'],schema.inDim);
    end
    counter = counter+1;
    statements(end+1) = makeStatement(counter,'노드 특징 선언',featureText, ...
        {},sprintf('%s : inDim',meta.sourceFile)); %#ok<AGROW>
end
counter = counter+1;
statements(end+1) = makeStatement(counter,'표현 범위 안내', ...
    ['이 원본은 관계 유형이 붙은 방향 그래프와 그에 딸린 선언으로 이루어져 있습니다. ' ...
    'OWL의 Class / Instance / rdf:type / subClassOf / 복합 공리 계층은 원본에 없어 ' ...
    '표시하지 않습니다. 추론기나 검증기는 실행하지 않았습니다.'], ...
    {},meta.sourceFile); %#ok<AGROW>
end

function s = makeStatement(counter,kind,text,refs,origin)
s = struct('id',sprintf('S%03d',counter),'kind',kind,'text',text, ...
    'refs',{refs},'status','명시적 선언 (추론 아님)','origin',origin);
end

function text = nameList(elements,idx)
idx = idx(:)';
parts = cell(1,numel(idx));
for k = 1:numel(idx)
    parts{k} = elements(idx(k)).name;
end
text = strjoin(parts,', ');
end

function ids = idList(elements,idx)
idx = idx(:)';
ids = cell(1,numel(idx));
for k = 1:numel(idx)
    ids{k} = elements(idx(k)).id;
end
end
