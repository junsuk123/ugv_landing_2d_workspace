function lines = ontologyDetailText(model,selection)
% ONTOLOGYDETAILTEXT  온톨로지 상세 패널에 표시할 읽기 전용 원문을 만듭니다.
%
%   lines = landing2d.viz.ontologyDetailText(model,selection)
%
% model은 landing2d.viz.ontologyViewModel이 만든 표시 자료입니다.
% selection.kind는 다음 중 하나입니다.
%   'summary'    기본 요약 (데이터 출처, 구성요소/관계 요약, 선언 조회 진입점)
%   'element'    selection.id = 요소 ID
%   'relation'   selection.id = 관계 ID
%   'predicate'  selection.id = 관계 유형 ID
%   'statement'  selection.id = 선언 ID
%   'cell'       selection.sourceId / selection.targetId = 관계행렬 셀
%
% 값이 확인되지 않은 항목은 미지정으로 적습니다. 추론기를 돌리지 않았으므로
% 어떤 항목도 추론 결과나 검증 통과로 적지 않습니다.
if nargin < 2 || isempty(selection)
    selection = struct('kind','summary');
end
if ~isfield(selection,'kind') || isempty(selection.kind)
    selection.kind = 'summary';
end
switch selection.kind
    case 'element'
        lines = elementText(model,selection.id);
    case 'relation'
        lines = relationText(model,selection.id);
    case 'predicate'
        lines = predicateText(model,selection.id);
    case 'statement'
        lines = statementText(model,selection.id);
    case 'cell'
        lines = cellText(model,selection);
    otherwise
        lines = summaryText(model);
end
lines = lines(:);
end

% -------------------------------------------------------------------- 기본 요약
function lines = summaryText(model)
m = model.metadata;
lines = {};
lines{end+1} = '[ 데이터 출처 ]';
lines{end+1} = sprintf('  표시 대상 : %s',m.viewKind);
lines{end+1} = sprintf('  소스      : %s',m.sourceLabel);
lines{end+1} = sprintf('  원본 경로 : %s',m.sourceFile);
lines{end+1} = sprintf('  변형      : %s',valueOr(m.variant,'(미지정)'));
lines{end+1} = sprintf('  파싱 범위 : %s',m.scope);
lines{end+1} = sprintf('  스냅샷    : %s',m.snapshotId);
lines{end+1} = '';
lines{end+1} = '[ 확인된 구성요소 ]';
lines{end+1} = sprintf('  요소 %d개, 관계 %d개, 관계 유형 %d개, 속성 %d개, 선언 %d개', ...
    model.nElements,model.nRelations,numel(model.predicates), ...
    numel(model.attributes),numel(model.statements));
roles = countRoles(model.elements);
for i = 1:numel(roles)
    lines{end+1} = sprintf('  - %s : %d개',roles(i).name,roles(i).count); %#ok<AGROW>
end
lines{end+1} = '';
lines{end+1} = '[ 관계 유형 ]';
for r = 1:numel(model.predicates)
    p = model.predicates(r);
    lines{end+1} = sprintf('  - %s (%s) : 간선 %d개', ...
        p.name,p.id,p.count); %#ok<AGROW>
end
selfCount = sum([model.relations.isSelf]);
parallelCount = countParallel(model.relations);
lines{end+1} = sprintf('  자기 연결 %d개, 평행 관계(같은 두 요소 사이 복수 관계) %d개', ...
    selfCount,parallelCount);
lines{end+1} = '';
lines{end+1} = '[ 그래프에 펼치지 않은 항목 - 여기에서 조회 ]';
for k = 1:numel(model.statements)
    s = model.statements(k);
    lines{end+1} = sprintf('  %s [%s] %s',s.id,s.kind,s.text); %#ok<AGROW>
end
if ~isempty(model.mapping)
    lines{end+1} = '';
    lines{end+1} = '[ 학습 입력 그래프와의 대응 (코드에서 확인된 것만) ]';
    for k = 1:numel(model.mapping)
        lines{end+1} = sprintf('  %s',model.mapping{k}); %#ok<AGROW>
    end
end
if ~isempty(m.warnings)
    lines{end+1} = '';
    lines{end+1} = '[ 경고 ]';
    for k = 1:numel(m.warnings)
        lines{end+1} = sprintf('  %s',m.warnings{k}); %#ok<AGROW>
    end
end
end

% -------------------------------------------------------------------- 요소 상세
function lines = elementText(model,id)
idx = findById({model.elements.id},id);
if isempty(idx)
    lines = {sprintf('요소 %s를 찾을 수 없습니다.',id)};
    return;
end
e = model.elements(idx);
lines = {};
lines{end+1} = sprintf('[ 요소 ] %s',e.label);
lines{end+1} = sprintf('  원본 ID   : %s (원본 참조: %s)',e.id,e.origin);
lines{end+1} = sprintf('  표시 이름 : %s',e.name);
lines{end+1} = sprintf('  확인된 유형 : %s',e.kind);
lines{end+1} = sprintf('  확인된 역할 : %s',e.role);
lines{end+1} = sprintf('  설명      : %s',e.description);
lines{end+1} = '';
lines{end+1} = '[ 직접 연결된 관계 ]';
outCount = 0;
for k = 1:numel(model.relations)
    r = model.relations(k);
    if r.sourceIndex ~= e.index, continue; end
    outCount = outCount+1;
    lines{end+1} = sprintf('  나감  %s : %s -%s-> %s   [%s]', ...
        r.id,e.name,r.predicate,model.elements(r.targetIndex).name,r.status); %#ok<AGROW>
end
inCount = 0;
for k = 1:numel(model.relations)
    r = model.relations(k);
    if r.targetIndex ~= e.index || r.sourceIndex == e.index, continue; end
    inCount = inCount+1;
    lines{end+1} = sprintf('  들어옴 %s : %s -%s-> %s   [%s]', ...
        r.id,model.elements(r.sourceIndex).name,r.predicate,e.name,r.status); %#ok<AGROW>
end
if outCount+inCount == 0
    lines{end+1} = '  (직접 연결된 관계가 기록되어 있지 않습니다 - 고립 요소)';
end
lines{end+1} = '';
lines{end+1} = '[ 속성 ]';
found = false;
for k = 1:numel(model.attributes)
    a = model.attributes(k);
    if ~strcmp(a.elementId,e.id), continue; end
    found = true;
    unit = valueOr(a.unit,'(단위 미지정)');
    lines{end+1} = sprintf('  %s = %s   [형: %s / 단위: %s / 상태: %s]', ...
        a.name,a.valueText,a.dataType,unit,a.status); %#ok<AGROW>
    lines{end+1} = sprintf('      출처: %s',a.origin); %#ok<AGROW>
end
if ~found
    lines{end+1} = '  (이 요소에 기록된 속성이 없습니다)';
end
lines{end+1} = '';
lines{end+1} = '[ 이 요소를 참조하는 선언 ]';
found = false;
for k = 1:numel(model.statements)
    s = model.statements(k);
    if ~any(strcmp(s.refs,e.id)), continue; end
    found = true;
    lines{end+1} = sprintf('  %s [%s] %s',s.id,s.kind,s.text); %#ok<AGROW>
    lines{end+1} = sprintf('      상태: %s / 출처: %s',s.status,s.origin); %#ok<AGROW>
end
if ~found
    lines{end+1} = '  (이 요소를 직접 참조하는 선언이 없습니다)';
end
end

% -------------------------------------------------------------------- 관계 상세
function lines = relationText(model,id)
idx = findById({model.relations.id},id);
if isempty(idx)
    lines = {sprintf('관계 %s를 찾을 수 없습니다.',id)};
    return;
end
r = model.relations(idx);
subject = model.elements(r.sourceIndex);
object = model.elements(r.targetIndex);
lines = {};
lines{end+1} = sprintf('[ 관계 ] %s',r.id);
lines{end+1} = sprintf('  %s  —%s→  %s',subject.name,r.predicate,object.name);
lines{end+1} = sprintf('  주어 : %s (%s)',subject.name,subject.id);
lines{end+1} = sprintf('  관계 : %s (%s)',r.predicate,r.predicateId);
lines{end+1} = sprintf('  목적어 : %s (%s)',object.name,object.id);
lines{end+1} = sprintf('  상태 : %s',r.status);
lines{end+1} = sprintf('  원본 참조 : %s',r.origin);
if r.isSelf
    lines{end+1} = '  (자기 연결입니다. 원본에 기록된 그대로 표시합니다.)';
end
lines{end+1} = '';
lines{end+1} = '[ 관계 유형 정의 ]';
lines = [lines,predicateBody(model,r.predicateId)];
lines{end+1} = '';
lines{end+1} = '[ 이 관계 유형을 언급하는 선언 ]';
found = false;
for k = 1:numel(model.statements)
    s = model.statements(k);
    if ~contains(s.text,r.predicate), continue; end
    found = true;
    lines{end+1} = sprintf('  %s [%s] %s',s.id,s.kind,s.text); %#ok<AGROW>
end
if ~found
    lines{end+1} = '  (연결된 선언이 없습니다)';
end
lines{end+1} = '';
lines{end+1} = ['[ 해석 주의 ] 이 연결은 원본에 기록된 관계입니다. ' ...
    '원본이 인과관계나 행동 결정 근거라고 선언하지 않았으므로 그렇게 읽지 않습니다.'];
end

% --------------------------------------------------------------- 관계 유형 상세
function lines = predicateText(model,id)
lines = {sprintf('[ 관계 유형 ] %s',id)};
lines = [lines,predicateBody(model,id)];
end

function lines = predicateBody(model,id)
idx = findById({model.predicates.id},id);
lines = {};
if isempty(idx)
    lines{end+1} = sprintf('  관계 유형 %s가 relationNames에 없습니다 (유형 미확인).',id);
    return;
end
p = model.predicates(idx);
lines{end+1} = sprintf('  이름 : %s (%s)',p.name,p.id);
lines{end+1} = sprintf('  선언된 domain : %s',p.declaredDomain);
lines{end+1} = sprintf('  선언된 range  : %s',p.declaredRange);
lines{end+1} = sprintf('  사용된 간선 수 : %d',p.count);
lines{end+1} = sprintf('  관찰된 출발 요소 (파생값, 선언 아님) : %s', ...
    joinOr(p.observedDomain,'(없음)'));
lines{end+1} = sprintf('  관찰된 도착 요소 (파생값, 선언 아님) : %s', ...
    joinOr(p.observedRange,'(없음)'));
lines{end+1} = sprintf('  원본 참조 : %s',p.origin);
end

% -------------------------------------------------------------------- 선언 상세
function lines = statementText(model,id)
idx = findById({model.statements.id},id);
if isempty(idx)
    lines = {sprintf('선언 %s를 찾을 수 없습니다.',id)};
    return;
end
s = model.statements(idx);
lines = {};
lines{end+1} = sprintf('[ 선언 ] %s',s.id);
lines{end+1} = sprintf('  유형 : %s',s.kind);
lines{end+1} = '  원래 표현 :';
lines{end+1} = sprintf('    %s',s.text);
lines{end+1} = sprintf('  상태 : %s',s.status);
lines{end+1} = sprintf('  원본 참조 : %s',s.origin);
lines{end+1} = '';
lines{end+1} = '[ 참조하는 요소 ]';
if isempty(s.refs)
    lines{end+1} = '  (참조하는 요소가 지정되어 있지 않습니다)';
else
    for k = 1:numel(s.refs)
        j = findById({model.elements.id},s.refs{k});
        if isempty(j)
            lines{end+1} = sprintf('  %s (모델에서 찾을 수 없음)',s.refs{k}); %#ok<AGROW>
        else
            lines{end+1} = sprintf('  %s : %s',model.elements(j).id, ...
                model.elements(j).name); %#ok<AGROW>
        end
    end
end
end

% ---------------------------------------------------------------- 행렬 셀 상세
function lines = cellText(model,selection)
si = findById({model.elements.id},selection.sourceId);
ti = findById({model.elements.id},selection.targetId);
lines = {};
if isempty(si) || isempty(ti)
    lines{end+1} = '선택한 셀의 요소를 찾을 수 없습니다.';
    return;
end
subject = model.elements(si);
object = model.elements(ti);
lines{end+1} = '[ 관계행렬 셀 ]';
lines{end+1} = sprintf('  행(출발) : %s (%s)',subject.name,subject.id);
lines{end+1} = sprintf('  열(도착) : %s (%s)',object.name,object.id);
lines{end+1} = '';
hits = [];
for k = 1:numel(model.relations)
    r = model.relations(k);
    if r.sourceIndex == subject.index && r.targetIndex == object.index
        hits(end+1) = k; %#ok<AGROW>
    end
end
if isempty(hits)
    lines{end+1} = ['  이 셀에는 관계가 기록되어 있지 않습니다 (값 0). ' ...
        '0은 선택한 데이터 범위에 연결이 기록되어 있지 않다는 뜻이며, ' ...
        '관계가 논리적으로 거짓이라고 판정한 값이 아닙니다.'];
    return;
end
lines{end+1} = sprintf('  기록된 관계 %d개 (모두 표시):',numel(hits));
for m = 1:numel(hits)
    r = model.relations(hits(m));
    lines{end+1} = ''; %#ok<AGROW>
    lines = [lines,reshape(relationText(model,r.id),1,[])]; %#ok<AGROW>
end
end

% ------------------------------------------------------------------ 보조 함수
function idx = findById(ids,id)
idx = find(strcmp(ids,id),1);
end

function text = valueOr(value,fallback)
if isempty(value)
    text = fallback;
else
    text = char(value);
end
end

function text = joinOr(items,fallback)
if isempty(items)
    text = fallback;
else
    text = strjoin(items,', ');
end
end

function roles = countRoles(elements)
roles = struct('name',{},'count',{});
for i = 1:numel(elements)
    name = elements(i).role;
    idx = find(strcmp({roles.name},name),1);
    if isempty(idx)
        roles(end+1) = struct('name',name,'count',1); %#ok<AGROW>
    else
        roles(idx).count = roles(idx).count+1;
    end
end
end

function count = countParallel(relations)
% 같은 (출발, 도착) 쌍에 관계가 둘 이상 기록된 쌍의 개수.
if isempty(relations)
    count = 0;
    return;
end
pairs = [[relations.sourceIndex]',[relations.targetIndex]'];
[~,~,group] = unique(pairs,'rows');
count = sum(accumarray(group,1) > 1);
end
