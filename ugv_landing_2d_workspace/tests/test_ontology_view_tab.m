function test_ontology_view_tab()
% TEST_ONTOLOGY_VIEW_TAB  온톨로지 탭의 생성/재사용과 세 영역의 연동 확인.
% 창을 만들므로 run_tests(true)에서만 실행됩니다.
fig = figure('Visible','off','Color','w');
cleanup = onCleanup(@()close(fig)); %#ok<NASGU>
group = uitabgroup(fig,'Units','normalized','Position',[0,0,1,1]);
other = uitab(group,'Title','Scenario 1');
axes(other); %#ok<LAXES>

figuresBefore = numel(findall(groot,'Type','figure'));
schemaBefore = landing2d.ontology.nodeSchema('core');
rngBefore = rng;

tab = landing2d.viz.attachOntologyView(group,'ontology');

%% 1) 탭이 정확히 하나만 생기고 기존 탭은 그대로
assert(countOntologyTabs(group) == 1,'온톨로지 탭은 하나여야 합니다.');
assert(isvalid(other) && strcmp(other.Title,'Scenario 1'), ...
    '기존 탭이 사라졌습니다.');
assert(group.SelectedTab == other, ...
    '온톨로지 탭을 붙이면서 기존 선택 탭을 바꾸면 안 됩니다.');
assert(numel(findall(groot,'Type','figure')) == figuresBefore, ...
    '별도 Figure가 새로 만들어졌습니다.');

%% 2) 기본 화면은 플롯 두 개와 상세 패널 하나
st = state(tab);
axesList = findall(tab,'Type','axes');
assert(numel(axesList) == 2, ...
    '기본 화면의 플롯은 두 개여야 합니다 (현재 %d개).',numel(axesList));
assert(isempty(findall(tab,'Type','uitabgroup')),'하위 탭을 만들면 안 됩니다.');
assert(all(isgraphics([st.listBox,st.textArea])),'상세 패널이 없습니다.');
assert(~isempty(st.graphPlot) && isgraphics(st.graphPlot));
assert(~isempty(st.matrixImage) && isgraphics(st.matrixImage));
assert(contains(st.statusLabel.Text,'nodeSchema.m'), ...
    '상태 표시줄에 데이터 출처가 없습니다.');
assert(contains(st.statusLabel.Text,'노드 9/9'), ...
    '상태 표시줄에 표시 범위가 없습니다.');

% 확인된 역할마다 다른 마커를 쓰고, 범례도 같은 수만큼 구분해야 함
roles = unique({st.model.elements.role});
markers = cellstr(string(st.graphPlot.Marker));
assert(numel(unique(markers)) == numel(roles), ...
    '확인된 역할 %d종에 마커가 %d종만 쓰였습니다.', ...
    numel(roles),numel(unique(markers)));
% 범례는 같은 roleMarker를 쓰므로 실제로 있는 역할만, 서로 다른 모양으로 적힘
legendText = st.axGraph.Subtitle.String;
for k = 1:numel(roles)
    short = strtrim(regexp(roles{k},'^[^(]*','match','once'));
    assert(contains(legendText,short), ...
        '범례에 역할 %s가 빠졌습니다: %s',short,legendText);
end
assert(contains(legendText,'출발') && contains(legendText,'도착'), ...
    '범례가 화살표 방향의 뜻을 밝혀야 합니다.');

%% 3) 반복 호출해도 탭과 그래픽 객체를 다시 만들지 않음
axesHandles = axesList;
tab2 = landing2d.viz.attachOntologyView(group,'ontology');
assert(tab2 == tab,'같은 탭을 재사용해야 합니다.');
assert(countOntologyTabs(group) == 1,'탭이 중복 생성되었습니다.');
assert(isequal(sort(double(findall(tab,'Type','axes'))),sort(double(axesHandles))), ...
    'axes가 중복 생성되었습니다.');
assert(numel(findall(groot,'Type','figure')) == figuresBefore);

%% 4) 관계행렬의 행/열 방향이 원본 source -> target과 일치
st = state(tab);
A = st.matrixImage.CData;
model = st.model;
for e = 1:model.nRelations
    r = model.relations(e);
    assert(A(r.sourceIndex,r.targetIndex) == 1, ...
        '관계 %s가 행렬에서 행=출발, 열=도착으로 표시되지 않았습니다.',r.id);
end
% 원본에 없는 역방향을 임의로 채우지 않았는지 (비대칭이 남아 있어야 함)
assert(~isequal(A,A'),'행렬이 대칭이면 방향 정보가 사라진 것입니다.');
expected = expectedMatrix(model);
assert(isequal(A,expected),'행렬 값이 원본 관계 목록과 다릅니다.');

%% 5) 그래프 선택 / 행렬 선택 / 검색이 같은 원본 요소를 가리킴
coords = [st.graphPlot.XData(:),st.graphPlot.YData(:)];
st.pick.graph(coords(1,1),coords(1,2));
st = state(tab);
assert(strcmp(st.selection.kind,'element') && strcmp(st.selection.id,'N01'), ...
    '그래프 노드 선택이 원본 요소를 가리키지 않습니다.');
assert(contains(strjoin(st.textArea.Value,newline),'PositionError'));
assert(~isempty(findobj(st.axMatrix,'Tag','ontologyMatrixMarker')), ...
    '노드를 선택하면 행렬의 대응 행과 열을 표시해야 합니다.');

% 행렬 셀 선택: x는 열(도착), y는 행(출발)
firstRelation = st.model.relations(1);
st.pick.matrix(firstRelation.targetIndex,firstRelation.sourceIndex);
st = state(tab);
assert(strcmp(st.selection.kind,'relation') ...
    && strcmp(st.selection.id,firstRelation.id), ...
    '행렬 셀 선택이 실제 관계 ID로 이어지지 않았습니다.');
detail = strjoin(st.textArea.Value,newline);
assert(contains(detail,firstRelation.origin),'상세에 원본 출처가 없습니다.');

% 검색: 결과 목록에서 고르면 같은 요소가 선택됨
st.searchField.Value = 'SafeLanding';
st.searchField.ValueChangedFcn(st.searchField,[]);
st = state(tab);
assert(~isempty(st.listItems),'검색 결과가 비어 있습니다.');
hit = find(strcmp({st.listItems.kind},'element'),1);
assert(~isempty(hit),'검색 결과에 요소가 없습니다.');
st.listBox.Value = hit;
st.listBox.ValueChangedFcn(st.listBox,[]);
st = state(tab);
assert(strcmp(st.selection.kind,'element'));
assert(strcmp(st.model.elements(elementIndex(st.model,st.selection.id)).name, ...
    'SafeLanding'),'검색 결과 선택이 다른 요소를 가리킵니다.');

%% 6) 속성과 선언이 검색과 상세 패널에서 조회됨
st.searchField.Value = 'captureWeight';
st.searchField.ValueChangedFcn(st.searchField,[]);
st = state(tab);
assert(any(strcmp({st.listItems.kind},'statement')), ...
    '그래프에 펼치지 않은 선언이 검색되지 않습니다.');

%% 7) 관계 선택(필터)과 선택 후에도 노드 좌표가 유지됨
before = [st.graphPlot.XData(:),st.graphPlot.YData(:)];
st.relationDrop.Value = st.model.predicates(2).id;
st.relationDrop.ValueChangedFcn(st.relationDrop,[]);
st = state(tab);
after = [st.graphPlot.XData(:),st.graphPlot.YData(:)];
assert(isequal(before,after),'관계 선택 때문에 노드 위치가 바뀌었습니다.');
filtered = st.matrixImage.CData;
assert(sum(filtered(:) == 1) == st.model.predicates(2).count, ...
    '관계를 고르면 행렬도 같은 범위로 갱신되어야 합니다.');
assert(isequal(st.axMatrix.CLim,[0,1]),'명암 범위는 0과 1로 고정해야 합니다.');

%% 8) 초기화 버튼이 선택과 표시 범위를 되돌림
st.resetButton.ButtonPushedFcn(st.resetButton,[]);
st = state(tab);
assert(strcmp(st.selection.kind,'summary'),'초기화가 선택을 지우지 않았습니다.');
assert(isempty(st.relationFilter) && isempty(st.searchText));
assert(sum(st.matrixImage.CData(:) == 1) == st.model.nRelations - ...
    duplicateCells(st.model),'초기화 뒤 행렬이 전체 관계로 돌아가지 않았습니다.');
assert(isequal([st.graphPlot.XData(:),st.graphPlot.YData(:)],before), ...
    '초기화 때문에 노드 위치가 바뀌었습니다.');

%% 9) 표시 대상 전환 (온톨로지 <-> 학습 입력 그래프)
assert(numel(st.viewDrop.ItemsData) >= 2, ...
    '두 표현이 모두 있으므로 표시 대상 선택창이 있어야 합니다.');
st.viewDrop.Value = 'graphstate';
st.viewDrop.ValueChangedFcn(st.viewDrop,[]);
st = state(tab);
assert(strcmp(st.model.metadata.sourceKey,'graphstate'));
assert(countOntologyTabs(group) == 1,'표시 대상을 바꾸며 탭이 늘었습니다.');
assert(numel(findall(tab,'Type','axes')) == 2);
assert(contains(st.statusLabel.Text,'강화학습 입력 그래프'), ...
    '현재 표시 대상을 화면에 밝혀야 합니다.');

%% 10) 빈 데이터와 큰 데이터
emptyTab = landing2d.viz.attachOntologyView(group,emptySchema());
stEmpty = state(emptyTab);
assert(stEmpty.model.nElements == 0 && stEmpty.model.nRelations == 0);
assert(contains(stEmpty.statusLabel.Text,'노드 0/0'), ...
    '빈 자료에서도 표시 범위를 정확히 알려야 합니다.');

bigTab = landing2d.viz.attachOntologyView(group,bigSchema(30), ...
    struct('maxDisplayNodes',8));
stBig = state(bigTab);
assert(numel(stBig.displayIndex) == 8,'표시 한도가 지켜지지 않았습니다.');
assert(contains(stBig.statusLabel.Text,'노드 8/30'), ...
    '부분 조회의 표시 노드 수와 전체 노드 수를 알려야 합니다.');
assert(contains(stBig.statusLabel.Text,'부분 조회'));
assert(isequal(size(stBig.matrixImage.CData),[8,8]), ...
    '부분 조회 때 행렬도 같은 범위여야 합니다.');
% 표시에서 빠진 요소도 검색과 상세 패널에서 조회 가능해야 함
stBig.searchField.Value = 'Node30';
stBig.searchField.ValueChangedFcn(stBig.searchField,[]);
stBig = state(bigTab);
hit = find(strcmp({stBig.listItems.kind},'element'),1);
assert(~isempty(hit),'표시하지 않은 요소가 검색되지 않습니다.');
stBig.listBox.Value = hit;
stBig.listBox.ValueChangedFcn(stBig.listBox,[]);
stBig = state(bigTab);
assert(contains(strjoin(stBig.textArea.Value,newline),'Node30'), ...
    '표시하지 않은 요소의 상세를 볼 수 없습니다.');

%% 11) 원본 데이터와 전역 상태가 변하지 않았는지
assert(isequal(schemaBefore,landing2d.ontology.nodeSchema('core')), ...
    '시각화가 온톨로지 원본을 바꾸었습니다.');
rngAfter = rng;
assert(isequal(rngBefore.Type,rngAfter.Type) ...
    && isequal(rngBefore.Seed,rngAfter.Seed) ...
    && isequal(rngBefore.State,rngAfter.State), ...
    '시각화가 전역 난수 상태를 바꾸었습니다.');

%% 12) 탭을 닫으면 붙여 둔 자료를 정리
% emptyTab / bigTab은 모두 같은 온톨로지 탭을 재사용한 핸들입니다.
assert(bigTab == tab && emptyTab == tab, ...
    '소스를 바꿔도 같은 탭을 재사용해야 합니다.');
delete(tab);
drawnow;
assert(countOntologyTabs(group) == 0,'탭이 닫히지 않았습니다.');
assert(isvalid(other),'온톨로지 탭을 닫으면서 다른 탭이 사라졌습니다.');
end

% --------------------------------------------------------------------- 보조
function st = state(tab)
st = getappdata(tab,'landing2dOntologyView');
assert(~isempty(st),'온톨로지 탭의 상태를 찾을 수 없습니다.');
end

function count = countOntologyTabs(group)
tabs = findobj(group,'Type','uitab','-depth',1);
count = sum(strcmp({tabs.Title},'온톨로지'));
end

function index = elementIndex(model,id)
index = find(strcmp(model.elementIds,id),1);
end

function A = expectedMatrix(model)
n = model.nElements;
A = zeros(n,n);
for e = 1:model.nRelations
    r = model.relations(e);
    A(r.sourceIndex,r.targetIndex) = 1;
end
end

function count = duplicateCells(model)
% 같은 칸에 여러 관계가 겹친 만큼 1의 개수는 관계 수보다 적습니다.
pairs = [[model.relations.sourceIndex]',[model.relations.targetIndex]'];
count = size(pairs,1)-size(unique(pairs,'rows'),1);
end

function schema = emptySchema()
% 검사 전용 빈 자료. 실제 온톨로지와 분리되어 있습니다.
schema.nodeNames = {};
schema.nNodes = 0;
schema.relationNames = {};
schema.nRelations = 0;
schema.src = [];
schema.dst = [];
schema.rel = [];
schema.variant = 'fixture-empty';
end

function schema = bigSchema(n)
% 검사 전용 큰 자료. 표시 한도와 부분 조회를 확인합니다.
schema.nodeNames = cell(1,n);
for i = 1:n
    schema.nodeNames{i} = sprintf('Node%d',i);
end
schema.nNodes = n;
schema.relationNames = {'link'};
schema.nRelations = 1;
schema.src = 1:n-1;
schema.dst = 2:n;
schema.rel = ones(1,n-1);
schema.variant = 'fixture-big';
end
