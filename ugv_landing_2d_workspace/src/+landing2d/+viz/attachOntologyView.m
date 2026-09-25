function tab = attachOntologyView(parent,source,options)
% ATTACHONTOLOGYVIEW  기존 화면에 온톨로지 탭 하나를 붙이고 갱신합니다.
%
%   tab = landing2d.viz.attachOntologyView(parent,source,options)
%
% parent
%   TabGroup : 제목이 '온톨로지'인 탭이 있으면 재사용하고, 없으면 하나만 추가합니다.
%   Tab      : 그 탭 안에 직접 만듭니다.
%   Figure   : 탭 그룹이 있으면 그것을 쓰고, 비어 있는 창이면 탭 그룹을 하나 만듭니다.
%
% source, options는 landing2d.viz.ontologyViewModel과 같습니다.
% options에 아래 항목을 더 넣을 수 있습니다.
%   .maxDisplayNodes  그래프에 한 번에 그릴 노드 수 한도 (기본 60)
%   .sources          표시 대상 선택창에 넣을 소스 목록 (기본: 실제 존재하는 것만)
%
% 같은 parent로 여러 번 불러도 탭과 그래픽 객체를 다시 만들지 않고 값만 갱신합니다.
% 이 함수는 온톨로지 원본, 학습 설정, 저장된 결과를 읽기만 하며 바꾸지 않습니다.
if nargin < 2 || isempty(source)
    source = 'ontology';
end
if nargin < 3 || isempty(options)
    options = struct();
end
if ~(isstruct(options) && isscalar(options))
    error('landing2d:InvalidOptions','options는 스칼라 구조체여야 합니다.');
end
tab = resolveTab(parent);

st = getappdata(tab,'landing2dOntologyView');
if isempty(st) || ~layoutIsValid(st)
    st = buildLayout(tab);
end
st.source = source;
st.options = options;
st.maxDisplayNodes = 60;
if isfield(options,'maxDisplayNodes') && ~isempty(options.maxDisplayNodes)
    st.maxDisplayNodes = max(1,round(options.maxDisplayNodes));
end
st.model = landing2d.viz.ontologyViewModel(source,options);
st.relationFilter = '';
st.searchText = '';
st.selection = struct('kind','summary','id','','sourceId','','targetId','');
st.focusIndex = [];
st.coordKey = '';
st.graphPlot = gobjects(0);
st.matrixImage = gobjects(0);
if all(isgraphics(st.axGraph))
    cla(st.axGraph,'reset');
end
if all(isgraphics(st.axMatrix))
    cla(st.axMatrix,'reset');
end
st = refreshControls(st);
st = renderAll(st);
setappdata(tab,'landing2dOntologyView',st);
end

% ------------------------------------------------------------------ 탭 확보
function tab = resolveTab(parent)
if isempty(parent) || ~isgraphics(parent)
    error('landing2d:OntologyViewParent', ...
        'parent는 유효한 TabGroup, Tab 또는 Figure 핸들이어야 합니다.');
end
if isa(parent,'matlab.ui.container.Tab')
    tab = parent;
    return;
end
if isa(parent,'matlab.ui.container.TabGroup')
    tab = findOrCreateTab(parent);
    return;
end
if isa(parent,'matlab.ui.Figure')
    group = findobj(parent,'Type','uitabgroup','-depth',1);
    if ~isempty(group)
        tab = findOrCreateTab(group(1));
        return;
    end
    if isempty(allchild(parent))
        group = uitabgroup(parent,'Units','normalized','Position',[0,0,1,1]);
        tab = findOrCreateTab(group);
        return;
    end
    error('landing2d:OntologyViewNoTabGroup', ...
        ['이 창에는 TabGroup이 없고 이미 다른 내용이 그려져 있어 ' ...
        '기존 화면을 다시 쓰지 않고 멈췄습니다. 연결 지점은 두 곳입니다. ' ...
        '(1) 창을 만드는 코드에서 uitabgroup을 만든 뒤 그 핸들을 넘기거나, ' ...
        '(2) 빈 uifigure를 만들어 넘기십시오.']);
end
error('landing2d:OntologyViewParent', ...
    ['parent 유형 %s는 지원하지 않습니다. ' ...
    'TabGroup, Tab 또는 Figure를 넘기십시오.'],class(parent));
end

function tab = findOrCreateTab(group)
titleText = '온톨로지';
existing = findobj(group,'Type','uitab','-depth',1);
for i = 1:numel(existing)
    if strcmp(existing(i).Title,titleText)
        tab = existing(i);
        return;
    end
end
previous = group.SelectedTab;
tab = uitab(group,'Title',titleText,'BackgroundColor','w');
if ~isempty(previous) && isvalid(previous)
    % 기존 화면의 선택 탭을 바꾸지 않습니다.
    group.SelectedTab = previous;
end
end

% ------------------------------------------------------------------ 화면 구성
function ok = layoutIsValid(st)
handles = {'grid','axGraph','axMatrix','searchField','relationDrop', ...
    'resetButton','listBox','textArea','statusLabel'};
ok = true;
for i = 1:numel(handles)
    if ~isfield(st,handles{i}) || isempty(st.(handles{i})) ...
            || ~all(isgraphics(st.(handles{i})))
        ok = false;
        return;
    end
end
end

function st = buildLayout(tab)
delete(allchild(tab));
st = struct();
st.tab = tab;

grid = uigridlayout(tab,[4,2]);
grid.ColumnWidth = {'2.2x','1x'};
grid.RowHeight = {'fit','3x','2x','fit'};
grid.RowSpacing = 6;
grid.ColumnSpacing = 8;
grid.Padding = [8,8,8,8];
grid.BackgroundColor = 'w';
st.grid = grid;

% --- 1행: 조작부 (검색 / 관계 선택 / 표시 대상 / 초기화)
controls = uigridlayout(grid,[1,8]);
controls.Layout.Row = 1;
controls.Layout.Column = [1,2];
controls.ColumnWidth = {'fit','2x','fit','1.1x','fit','1.4x','fit',90};
controls.RowHeight = {'fit'};
controls.Padding = [0,0,0,0];
controls.ColumnSpacing = 6;
controls.BackgroundColor = 'w';
st.controls = controls;

st.searchLabel = uilabel(controls,'Text','검색','FontName','Arial');
st.searchField = uieditfield(controls,'text', ...
    'Placeholder','이름 / ID / 관계명 / 선언 원문');
uilabel(controls,'Text','관계 선택','FontName','Arial');
st.relationDrop = uidropdown(controls,'Items',{'전체'},'ItemsData',{''});
uilabel(controls,'Text','표시 대상','FontName','Arial');
st.viewDrop = uidropdown(controls,'Items',{'(없음)'},'ItemsData',{''});
uilabel(controls,'Text','','FontName','Arial');
st.resetButton = uibutton(controls,'Text','초기화');

% --- 2~3행 왼쪽: 의미 관계 그래프
st.axGraph = uiaxes(grid);
st.axGraph.Layout.Row = [2,3];
st.axGraph.Layout.Column = 1;

% --- 2행 오른쪽: 관계행렬
st.axMatrix = uiaxes(grid);
st.axMatrix.Layout.Row = 2;
st.axMatrix.Layout.Column = 2;

% --- 3행 오른쪽: 상세 설명 (목록 + 원문을 같은 패널 안에서 전환)
detail = uigridlayout(grid,[2,1]);
detail.Layout.Row = 3;
detail.Layout.Column = 2;
detail.RowHeight = {'1x','1.6x'};
detail.Padding = [0,0,0,0];
detail.RowSpacing = 4;
detail.BackgroundColor = 'w';
st.detailGrid = detail;
st.listBox = uilistbox(detail,'Items',{},'FontName','Arial','FontSize',11);
st.textArea = uitextarea(detail,'Editable','off','FontName','Arial', ...
    'FontSize',11,'Value',{''});

% --- 4행: 상태 표시줄
st.statusLabel = uilabel(grid,'Text','','FontName','Arial','FontSize',11, ...
    'WordWrap','on','VerticalAlignment','top');
st.statusLabel.Layout.Row = 4;
st.statusLabel.Layout.Column = [1,2];

prepareViewAxes(st.axGraph);
prepareViewAxes(st.axMatrix);

st.searchField.ValueChangedFcn = @(~,~)onSearch(tab);
st.relationDrop.ValueChangedFcn = @(~,~)onRelation(tab);
st.viewDrop.ValueChangedFcn = @(~,~)onView(tab);
st.resetButton.ButtonPushedFcn = @(~,~)onReset(tab);
st.listBox.ValueChangedFcn = @(~,~)onList(tab);
st.axGraph.ButtonDownFcn = @(~,~)onGraphClick(tab);
st.axMatrix.ButtonDownFcn = @(~,~)onMatrixClick(tab);
tab.DeleteFcn = @(~,~)onTabDelete(tab);

% 좌표로 선택을 수행하는 진입점. 마우스 콜백과 자동 검사가 같은 경로를 씁니다.
st.pick = struct('graph',@(px,py)graphPick(tab,px,py), ...
    'matrix',@(x,y)matrixPick(tab,x,y));

st.listItems = struct('label',{},'kind',{},'id',{});
st.displayIndex = [];
st.edgeRows = [];
st.graphPlot = gobjects(0);
st.matrixImage = gobjects(0);
st.displayNote = '';
end

function prepareViewAxes(ax)
% 기존 그림과 같은 글꼴/색 기준. 전역 그래픽 기본값은 바꾸지 않습니다.
set(ax,'FontName','Arial','FontSize',9,'Color','w', ...
    'XColor',[0.15,0.15,0.15],'YColor',[0.15,0.15,0.15], ...
    'LineWidth',0.8,'Box','on','Layer','top');
ax.Title.Color = [0.12,0.12,0.12];
ax.Toolbar.Visible = 'off';
disableDefaultInteractivity(ax);
end

% ------------------------------------------------------------------ 조작부 갱신
function st = refreshControls(st)
model = st.model;
items = {'전체'};
data = {''};
for r = 1:numel(model.predicates)
    p = model.predicates(r);
    items{end+1} = sprintf('%s (%d)',p.name,p.count); %#ok<AGROW>
    data{end+1} = p.id; %#ok<AGROW>
end
st.relationDrop.Items = items;
st.relationDrop.ItemsData = data;
st.relationDrop.Value = '';

[viewItems,viewData] = availableViews(st);
st.viewDrop.Items = viewItems;
st.viewDrop.ItemsData = viewData;
key = currentViewKey(st);
if any(strcmp(viewData,key))
    st.viewDrop.Value = key;
end
% 표시 대상이 하나뿐이면 선택창을 만들지 않습니다.
single = numel(viewData) <= 1;
st.viewDrop.Visible = ~single;
st.viewDrop.Enable = ~single;
st.searchField.Value = '';
end

function [items,data] = availableViews(st)
% 실제로 존재하는 표현만 선택창에 넣습니다.
items = {};
data = {};
if isstruct(st.source)
    items{end+1} = '전달된 스키마';
    data{end+1} = 'struct';
    return;
end
candidates = {'ontology','온톨로지 의미 그래프 (core)'; ...
    'ontology_design','온톨로지 의미 그래프 (design)'; ...
    'graphstate','강화학습 입력 그래프'};
% 소스가 실제로 있는지만 확인합니다. 스냅샷은 스키마마다 크기가 다를 수 있으므로
% 이 확인에는 넣지 않습니다.
probe = st.options;
if isfield(probe,'snapshot')
    probe = rmfield(probe,'snapshot');
end
for k = 1:size(candidates,1)
    try
        landing2d.viz.ontologyViewModel(candidates{k,1},probe);
        items{end+1} = candidates{k,2}; %#ok<AGROW>
        data{end+1} = candidates{k,1}; %#ok<AGROW>
    catch
        % 그 표현이 이 저장소에 없으면 선택창에 넣지 않습니다.
    end
end
end

function key = currentViewKey(st)
if isstruct(st.source)
    key = 'struct';
else
    key = lower(char(st.source));
end
end

% ------------------------------------------------------------------ 전체 그리기
function st = renderAll(st)
st = computeDisplay(st);
st = renderGraph(st);
st = renderMatrix(st);
st = refreshList(st);
st = renderDetails(st);
st = renderStatus(st);
end

function st = computeDisplay(st)
% 표시 범위를 정합니다. 한도를 넘지 않으면 항상 전체를 표시합니다.
% 이것은 UI의 표시 범위일 뿐이며 원본이나 강화학습 입력을 바꾸지 않습니다.
n = st.model.nElements;
if n <= st.maxDisplayNodes
    st.displayIndex = 1:n;
    st.displayNote = '';
    return;
end
if isempty(st.focusIndex)
    idx = 1:st.maxDisplayNodes;
    st.displayNote = sprintf(['부분 조회: 원본 순서 앞쪽 %d개만 그립니다. ' ...
        '검색으로 다른 요소를 고르면 그 요소를 중심으로 다시 조회합니다.'], ...
        numel(idx));
else
    keep = st.focusIndex;
    for k = 1:numel(st.model.relations)
        r = st.model.relations(k);
        if r.sourceIndex == st.focusIndex
            keep(end+1) = r.targetIndex; %#ok<AGROW>
        elseif r.targetIndex == st.focusIndex
            keep(end+1) = r.sourceIndex; %#ok<AGROW>
        end
    end
    idx = unique(keep,'sorted');
    if numel(idx) > st.maxDisplayNodes
        idx = idx(1:st.maxDisplayNodes);
    end
    st.displayNote = sprintf(['부분 조회: %s와 직접 연결된 범위만 그립니다. ' ...
        '표시하지 않은 요소도 검색과 상세 패널에서 모두 조회할 수 있습니다.'], ...
        st.model.elements(st.focusIndex).name);
end
st.displayIndex = idx;
end

% -------------------------------------------------------------- A. 의미 그래프
function st = renderGraph(st)
ax = st.axGraph;
model = st.model;
idx = st.displayIndex;
if isempty(idx)
    st.graphPlot = gobjects(0);
    st.edgeRows = [];
    st.coordKey = '';
    cla(ax,'reset');
    prepareViewAxes(ax);
    axis(ax,'off');
    title(ax,'A. 의미 관계 그래프','Interpreter','none');
    text(ax,0.5,0.5,emptyMessage(model),'Units','normalized', ...
        'HorizontalAlignment','center','FontName','Arial','FontSize',10, ...
        'Color',[0.35,0.35,0.35]);
    ax.Title.Visible = 'on';
    return;
end
[G,edgeRows] = buildDigraph(model,idx);
key = sprintf('%s|%s',currentViewKey(st),strjoin(model.elementIds(idx),','));

st.edgeRows = edgeRows;
if isempty(st.graphPlot) || ~all(isgraphics(st.graphPlot)) ...
        || ~strcmp(st.coordKey,key)
    cla(ax,'reset');
    prepareViewAxes(ax);
    hold(ax,'on');
    st.graphPlot = plotWithFixedLayout(ax,G,st,idx);
    st.coordKey = key;
end
h = st.graphPlot;
h.NodeLabel = displayLabels(model,idx,numel(idx));
styleNodes(h,model,idx,st);
styleEdges(h,model,st);
title(ax,sprintf('A. 의미 관계 그래프 — %s',model.metadata.viewKind), ...
    'Interpreter','none');
subtitle(ax,legendText(model,idx),'Interpreter','none','FontSize',8, ...
    'Color',[0.35,0.35,0.35]);
axis(ax,'off');
ax.Title.Visible = 'on';
ax.Subtitle.Visible = 'on';
end

function text = emptyMessage(model)
% 데모 온톨로지로 조용히 바꾸지 않고, 비어 있다는 사실과 필요한 입력을 적습니다.
if model.nElements == 0
    text = sprintf(['연결된 소스에 요소가 기록되어 있지 않습니다.\n' ...
        '필요한 입력: nodeNames / src / dst / rel 을 가진 스키마\n' ...
        '현재 소스: %s'],model.metadata.sourceFile);
else
    text = '현재 표시 범위에 요소가 없습니다. 초기화를 누르면 전체로 돌아갑니다.';
end
end

function [G,edgeRows] = buildDigraph(model,idx)
% 표시 범위 안의 간선만 모읍니다. 평행 간선과 자기 연결은 그대로 둡니다.
% 노드 이름을 식별자로 쓰지 않으므로 같은 이름의 다른 요소가 합쳐지지 않습니다.
n = numel(idx);
position = zeros(1,model.nElements);
position(idx) = 1:n;
s = [];
t = [];
edgeRows = [];
for k = 1:numel(model.relations)
    r = model.relations(k);
    if position(r.sourceIndex) == 0 || position(r.targetIndex) == 0
        continue;
    end
    s(end+1,1) = position(r.sourceIndex); %#ok<AGROW>
    t(end+1,1) = position(r.targetIndex); %#ok<AGROW>
    edgeRows(end+1,1) = k; %#ok<AGROW>
end
if isempty(s)
    G = digraph(sparse(n,n));
    edgeRows = [];
    return;
end
edgeTable = table([s,t],edgeRows,'VariableNames',{'EndNodes','OrigRelation'});
nodeTable = table((1:n)','VariableNames',{'DisplayIndex'});
G = digraph(edgeTable,nodeTable);
edgeRows = G.Edges.OrigRelation;
end

function h = plotWithFixedLayout(ax,G,st,idx)
% 배치는 표시 노드 집합이 바뀔 때만 계산합니다. 검색, 선택, 관계 강조는
% 좌표를 다시 계산하지 않습니다. 전역 난수 상태도 건드리지 않습니다.
state = rng;
restore = onCleanup(@()rng(state));
if isfield(st.model.metadata,'layout') && ~isempty(st.model.metadata.layout)
    h = plot(ax,G,'XData',st.model.metadata.layout.x(idx), ...
        'YData',st.model.metadata.layout.y(idx));
else
    % layered는 난수를 쓰지 않는 결정적 배치입니다. 순환과 자기 연결이 있어도
    % 원본 간선을 지우지 않고 그대로 배치합니다.
    h = plot(ax,G,'Layout','layered');
end
h.ArrowSize = 9;
h.NodeFontName = 'Arial';
h.NodeFontSize = 9;
h.EdgeFontName = 'Arial';
h.EdgeFontSize = 8;
h.Interpreter = 'none';
try
    h.PickableParts = 'none';
catch
    h.HitTest = 'off';
end
end

function labels = displayLabels(model,idx,shown)
% 라벨이 너무 촘촘하면 먼저 라벨 밀도를 줄이고 구조는 그대로 둡니다.
labels = cell(1,numel(idx));
dense = shown > 40;
for k = 1:numel(idx)
    if dense && mod(k,2) == 0
        labels{k} = '';
    else
        labels{k} = model.elements(idx(k)).name;
    end
end
end

function styleNodes(h,model,idx,st)
markers = cell(1,numel(idx));
sizes = zeros(1,numel(idx));
colors = zeros(numel(idx),3);
selected = selectedElementIndex(st);
for k = 1:numel(idx)
    markers{k} = roleMarker(model.elements(idx(k)).role);
    if idx(k) == selected
        sizes(k) = 11;
        colors(k,:) = [0,0,0];
    elseif isNeighbor(model,selected,idx(k))
        sizes(k) = 8;
        colors(k,:) = [0.25,0.25,0.25];
    else
        sizes(k) = 6;
        colors(k,:) = [0.55,0.55,0.55];
    end
end
h.Marker = markers;
h.MarkerSize = sizes;
h.NodeColor = colors;
h.NodeLabelColor = [0.12,0.12,0.12];
end

function marker = roleMarker(role)
% 원본에서 확인된 역할만 모양으로 구분합니다. 확인되지 않으면 중립 모양입니다.
% '비위험 노드'가 '위험 노드'를 포함하므로 더 긴 이름을 먼저 확인합니다.
if contains(role,'목표 노드')
    marker = 's';
elseif contains(role,'보상 가중치 노드')
    marker = 'd';
elseif contains(role,'정책 가치 노드')
    marker = 'p';
elseif contains(role,'비위험 노드')
    marker = 'o';
elseif contains(role,'위험 노드')
    marker = '^';
else
    marker = 'o';
end
end

function styleEdges(h,model,st)
rows = st.edgeRows;
if isempty(rows)
    return;
end
nEdges = numel(rows);
widths = zeros(1,nEdges);
colors = zeros(nEdges,3);
styles = cell(1,nEdges);
labels = cell(1,nEdges);
selectedRelation = '';
if strcmp(st.selection.kind,'relation')
    selectedRelation = st.selection.id;
end
selectedElement = selectedElementIndex(st);
showLabels = nEdges <= 40;
for e = 1:nEdges
    r = model.relations(rows(e));
    styles{e} = predicateLineStyle(r.predicateIndex);
    emphasise = false;
    if ~isempty(selectedRelation) && strcmp(r.id,selectedRelation)
        emphasise = true;
    elseif ~isempty(selectedElement) ...
            && (r.sourceIndex == selectedElement || r.targetIndex == selectedElement)
        emphasise = true;
    end
    filtered = isempty(st.relationFilter) ...
        || strcmp(r.predicateId,st.relationFilter);
    if emphasise && filtered
        widths(e) = 2.2;
        colors(e,:) = [0,0,0];
    elseif filtered
        widths(e) = 1.1;
        colors(e,:) = [0.30,0.30,0.30];
    else
        widths(e) = 0.5;
        colors(e,:) = [0.82,0.82,0.82];
    end
    if showLabels && ~r.isSelf && filtered
        labels{e} = r.predicate;
    else
        labels{e} = '';
    end
end
h.LineWidth = widths;
h.EdgeColor = colors;
h.LineStyle = styles;
h.EdgeLabel = labels;
h.EdgeLabelColor = [0.35,0.35,0.35];
end

function style = predicateLineStyle(index)
styles = {'-','--',':','-.'};
if index >= 1 && index <= numel(styles)
    style = styles{index};
else
    style = '-';
end
end

function text = legendText(model,idx)
% 실제로 있는 종류만 범례에 넣습니다.
roles = unique({model.elements(idx).role},'stable');
shapes = cell(1,0);
for k = 1:numel(roles)
    shapes{end+1} = sprintf('%s=%s',shortRole(roles{k}), ...
        markerName(roleMarker(roles{k}))); %#ok<AGROW>
end
usedRel = unique([model.relations.predicateIndex],'stable');
lineParts = cell(1,0);
for k = 1:numel(usedRel)
    r = usedRel(k);
    if r >= 1 && r <= numel(model.predicates)
        lineParts{end+1} = sprintf('%s=%s',model.predicates(r).name, ...
            styleName(predicateLineStyle(r))); %#ok<AGROW>
    end
end
text = sprintf('노드 모양: %s   |   선 모양: %s   |   화살표는 원본의 출발→도착 방향', ...
    strjoin(shapes,', '),strjoin(lineParts,', '));
end

function short = shortRole(role)
token = regexp(role,'^[^(]*','match','once');
short = strtrim(token);
if isempty(short)
    short = role;
end
end

function name = markerName(marker)
switch marker
    case 's', name = '사각형';
    case 'd', name = '마름모';
    case 'p', name = '오각형';
    case '^', name = '삼각형';
    otherwise, name = '원형';
end
end

function name = styleName(style)
switch style
    case '-', name = '실선';
    case '--', name = '파선';
    case ':', name = '점선';
    case '-.', name = '일점쇄선';
    otherwise, name = style;
end
end

% -------------------------------------------------------------- B. 관계행렬
function st = renderMatrix(st)
ax = st.axMatrix;
model = st.model;
idx = st.displayIndex;
n = numel(idx);
if n == 0
    st.matrixImage = gobjects(0);
    cla(ax,'reset');
    prepareViewAxes(ax);
    axis(ax,'off');
    title(ax,'B. 관계행렬','Interpreter','none');
    text(ax,0.5,0.5,'표시할 요소가 없습니다.','Units','normalized', ...
        'HorizontalAlignment','center','FontName','Arial','FontSize',10, ...
        'Color',[0.35,0.35,0.35]);
    ax.Title.Visible = 'on';
    return;
end
A = relationMatrix(model,idx,st.relationFilter);
% 이미 같은 크기의 그림이 있으면 값만 갱신합니다.
if isfield(st,'matrixImage') && ~isempty(st.matrixImage) ...
        && all(isgraphics(st.matrixImage)) && isequal(size(st.matrixImage.CData),[n,n])
    st.matrixImage.CData = A;
    st.matrixImage.AlphaData = ~isnan(A);
    title(ax,matrixTitle(st),'Interpreter','none');
    st = drawMatrixMarker(st);
    return;
end
cla(ax,'reset');
prepareViewAxes(ax);
hold(ax,'on');
% 결측(미지원/판정 불가)과 실제 0을 구분합니다. 결측은 회색 바탕이 비칩니다.
ax.Color = [0.88,0.88,0.88];
im = imagesc(ax,1:n,1:n,A);
im.AlphaData = ~isnan(A);
try
    im.PickableParts = 'none';
catch
    im.HitTest = 'off';
end
colormap(ax,[1,1,1;0,0,0]);
% 명암 범위는 0과 1로 고정합니다. 선택이나 시점에 따라 바꾸지 않습니다.
clim(ax,[0,1]);
axis(ax,'image');
ax.XLim = [0.5,n+0.5];
ax.YLim = [0.5,n+0.5];
ax.YDir = 'reverse';
labels = {model.elements(idx).name};
if n <= 24
    ax.XTick = 1:n;
    ax.YTick = 1:n;
    ax.XTickLabel = labels;
    ax.YTickLabel = labels;
    ax.XTickLabelRotation = 90;
else
    step = ceil(n/12);
    ax.XTick = 1:step:n;
    ax.YTick = 1:step:n;
    ax.XTickLabel = labels(1:step:n);
    ax.YTickLabel = labels(1:step:n);
    ax.XTickLabelRotation = 90;
end
ax.TickLabelInterpreter = 'none';
ax.FontSize = 8;
title(ax,matrixTitle(st),'Interpreter','none');
xlabel(ax,'도착 요소 (열)');
ylabel(ax,'출발 요소 (행)');
grid(ax,'off');
st.matrixImage = im;
st = drawMatrixMarker(st);
end

function A = relationMatrix(model,idx,filterId)
n = numel(idx);
position = zeros(1,model.nElements);
position(idx) = 1:n;
A = zeros(n,n);
for k = 1:numel(model.relations)
    r = model.relations(k);
    if ~isempty(filterId) && ~strcmp(r.predicateId,filterId)
        continue;
    end
    i = position(r.sourceIndex);
    j = position(r.targetIndex);
    if i == 0 || j == 0
        continue;
    end
    if strcmp(r.status,'유형 미확인')
        A(i,j) = NaN;   % 관계 유형을 확인할 수 없는 칸은 결측으로 둡니다.
    elseif ~isnan(A(i,j))
        A(i,j) = 1;
    end
end
end

function text = matrixTitle(st)
if isempty(st.relationFilter)
    text = 'B. 관계행렬 — 전체 관계 (1 = 하나 이상 기록됨)';
else
    idx = find(strcmp({st.model.predicates.id},st.relationFilter),1);
    name = st.relationFilter;
    if ~isempty(idx)
        name = st.model.predicates(idx).name;
    end
    text = sprintf('B. 관계행렬 — %s (1 = i에서 j로 기록됨)',name);
end
end

function st = drawMatrixMarker(st)
% 선택한 요소의 행과 열, 또는 선택한 셀을 표시합니다.
ax = st.axMatrix;
n = numel(st.displayIndex);
position = zeros(1,st.model.nElements);
position(st.displayIndex) = 1:n;
delete(findobj(ax,'Tag','ontologyMatrixMarker'));
switch st.selection.kind
    case {'element','relation'}
        [i,j] = selectionCells(st,position);
        if ~isempty(i)
            drawBand(ax,'row',i,n);
        end
        if ~isempty(j)
            drawBand(ax,'col',j,n);
        end
    case 'cell'
        si = position(elementIndexById(st.model,st.selection.sourceId));
        ti = position(elementIndexById(st.model,st.selection.targetId));
        if si > 0 && ti > 0
            rectangle(ax,'Position',[ti-0.5,si-0.5,1,1],'EdgeColor',[0,0,0], ...
                'LineWidth',1.8,'Tag','ontologyMatrixMarker');
        end
end
end

function [i,j] = selectionCells(st,position)
i = [];
j = [];
switch st.selection.kind
    case 'element'
        k = elementIndexById(st.model,st.selection.id);
        if k > 0 && position(k) > 0
            i = position(k);
            j = position(k);
        end
    case 'relation'
        k = find(strcmp({st.model.relations.id},st.selection.id),1);
        if ~isempty(k)
            r = st.model.relations(k);
            if position(r.sourceIndex) > 0
                i = position(r.sourceIndex);
            end
            if position(r.targetIndex) > 0
                j = position(r.targetIndex);
            end
        end
end
end

function drawBand(ax,kind,index,n)
if strcmp(kind,'row')
    x = [0.5,n+0.5,n+0.5,0.5];
    y = [index-0.5,index-0.5,index+0.5,index+0.5];
else
    x = [index-0.5,index+0.5,index+0.5,index-0.5];
    y = [0.5,0.5,n+0.5,n+0.5];
end
patch(ax,'XData',x,'YData',y,'FaceColor',[0.2,0.2,0.2],'FaceAlpha',0.12, ...
    'EdgeColor',[0.2,0.2,0.2],'LineWidth',1.0,'LineStyle','--', ...
    'Tag','ontologyMatrixMarker','PickableParts','none');
end

% -------------------------------------------------------------- C. 상세 패널
function st = refreshList(st)
model = st.model;
query = lower(strtrim(st.searchText));
items = struct('label',{},'kind',{},'id',{});
if isempty(query)
    items(end+1) = listItem('■ 기본 요약','summary','');
    for i = 1:numel(model.elements)
        e = model.elements(i);
        items(end+1) = listItem(sprintf('요소  %s  %s',e.id,e.name), ...
            'element',e.id); %#ok<AGROW>
    end
    for k = 1:numel(model.statements)
        s = model.statements(k);
        items(end+1) = listItem(sprintf('선언  %s  [%s]',s.id,s.kind), ...
            'statement',s.id); %#ok<AGROW>
    end
    for r = 1:numel(model.predicates)
        p = model.predicates(r);
        items(end+1) = listItem(sprintf('관계유형  %s  %s',p.id,p.name), ...
            'predicate',p.id); %#ok<AGROW>
    end
else
    for i = 1:numel(model.elements)
        e = model.elements(i);
        if matches(query,{e.id,e.name,e.role})
            items(end+1) = listItem(sprintf('요소  %s  %s',e.id,e.name), ...
                'element',e.id); %#ok<AGROW>
        end
    end
    for k = 1:numel(model.relations)
        r = model.relations(k);
        subject = model.elements(r.sourceIndex).name;
        object = model.elements(r.targetIndex).name;
        if matches(query,{r.id,r.predicate,subject,object})
            items(end+1) = listItem(sprintf('관계  %s  %s -%s-> %s', ...
                r.id,subject,r.predicate,object),'relation',r.id); %#ok<AGROW>
        end
    end
    for r = 1:numel(model.predicates)
        p = model.predicates(r);
        if matches(query,{p.id,p.name})
            items(end+1) = listItem(sprintf('관계유형  %s  %s',p.id,p.name), ...
                'predicate',p.id); %#ok<AGROW>
        end
    end
    for k = 1:numel(model.statements)
        s = model.statements(k);
        if matches(query,{s.id,s.kind,s.text})
            items(end+1) = listItem(sprintf('선언  %s  [%s]',s.id,s.kind), ...
                'statement',s.id); %#ok<AGROW>
        end
    end
end
st.listItems = items;
if isempty(items)
    st.listBox.Items = {'(검색 결과 없음)'};
    st.listBox.ItemsData = {0};
    st.listBox.Value = 0;
else
    st.listBox.Items = {items.label};
    st.listBox.ItemsData = num2cell(1:numel(items));
    st.listBox.Value = listValueFor(st);
end
end

function value = listValueFor(st)
% 목록에 현재 선택과 같은 항목이 있으면 그 줄을, 없으면 첫 줄을 고릅니다.
value = 1;
if isempty(st.listItems)
    return;
end
for k = 1:numel(st.listItems)
    if strcmp(st.listItems(k).kind,st.selection.kind) ...
            && strcmp(st.listItems(k).id,st.selection.id)
        value = k;
        return;
    end
end
end

function syncListSelection(st)
% 목록에 선택 항목이 있을 때만 목록 커서를 옮깁니다.
% 없으면 그대로 두어 상세 패널의 내용과 어긋난 줄을 강조하지 않습니다.
if isempty(st.listItems)
    return;
end
for k = 1:numel(st.listItems)
    if strcmp(st.listItems(k).kind,st.selection.kind) ...
            && strcmp(st.listItems(k).id,st.selection.id)
        st.listBox.Value = k;
        return;
    end
end
end

function item = listItem(label,kind,id)
item = struct('label',label,'kind',kind,'id',id);
end

function ok = matches(query,fields)
ok = false;
for k = 1:numel(fields)
    if ~isempty(strfind(lower(char(fields{k})),query)) %#ok<STREMP>
        ok = true;
        return;
    end
end
end

function st = renderDetails(st)
lines = landing2d.viz.ontologyDetailText(st.model,st.selection);
st.textArea.Value = lines;
end

% -------------------------------------------------------------- 상태 표시줄
function st = renderStatus(st)
model = st.model;
shownRelations = 0;
position = zeros(1,model.nElements);
position(st.displayIndex) = 1:numel(st.displayIndex);
for k = 1:numel(model.relations)
    r = model.relations(k);
    if position(r.sourceIndex) == 0 || position(r.targetIndex) == 0
        continue;
    end
    if isempty(st.relationFilter) || strcmp(r.predicateId,st.relationFilter)
        shownRelations = shownRelations+1;
    end
end
filterName = '전체';
if ~isempty(st.relationFilter)
    idx = find(strcmp({model.predicates.id},st.relationFilter),1);
    if ~isempty(idx)
        filterName = model.predicates(idx).name;
    end
end
parts = {};
parts{end+1} = sprintf('데이터 출처: %s',model.metadata.sourceFile);
parts{end+1} = sprintf('표시 대상: %s',model.metadata.viewKind);
parts{end+1} = sprintf('표시 범위: 노드 %d/%d, 관계 %d/%d (관계 선택: %s)', ...
    numel(st.displayIndex),model.nElements,shownRelations, ...
    model.nRelations,filterName);
parts{end+1} = sprintf('스냅샷: %s',model.metadata.snapshotId);
parts{end+1} = sprintf('선택 문장: %s',selectionSentence(st));
text = strjoin(parts,'  |  ');
extra = {};
if isfield(st,'displayNote') && ~isempty(st.displayNote)
    extra{end+1} = st.displayNote;
end
if ~isempty(model.metadata.warnings)
    extra{end+1} = ['경고: ',strjoin(model.metadata.warnings,' / ')];
end
extra{end+1} = ['관계행렬의 0은 선택한 범위에 연결이 기록되어 있지 않다는 뜻이며, ' ...
    '관계가 거짓이라고 판정한 값이 아닙니다. 회색 칸은 유형을 확인할 수 없는 결측입니다.'];
st.statusLabel.Text = [text,newline,strjoin(extra,'  ')];
end

function text = selectionSentence(st)
model = st.model;
switch st.selection.kind
    case 'element'
        k = elementIndexById(model,st.selection.id);
        if k > 0
            text = sprintf('요소 %s (%s)',model.elements(k).name,model.elements(k).id);
        else
            text = '(요소 없음)';
        end
    case 'relation'
        k = find(strcmp({model.relations.id},st.selection.id),1);
        if ~isempty(k)
            r = model.relations(k);
            text = sprintf('%s —%s→ %s (%s)', ...
                model.elements(r.sourceIndex).name,r.predicate, ...
                model.elements(r.targetIndex).name,r.id);
        else
            text = '(관계 없음)';
        end
    case 'predicate'
        text = sprintf('관계 유형 %s',st.selection.id);
    case 'statement'
        text = sprintf('선언 %s',st.selection.id);
    case 'cell'
        text = sprintf('관계행렬 셀 %s -> %s', ...
            st.selection.sourceId,st.selection.targetId);
    otherwise
        text = '기본 요약';
end
end

% ---------------------------------------------------------------------- 콜백
function onSearch(tab)
st = getappdata(tab,'landing2dOntologyView');
if isempty(st), return; end
st.searchText = char(st.searchField.Value);
st = refreshList(st);
st = renderStatus(st);
setappdata(tab,'landing2dOntologyView',st);
end

function onRelation(tab)
st = getappdata(tab,'landing2dOntologyView');
if isempty(st), return; end
st.relationFilter = char(st.relationDrop.Value);
% 노드 좌표는 다시 계산하지 않습니다.
st = renderGraph(st);
st = renderMatrix(st);
st = renderStatus(st);
setappdata(tab,'landing2dOntologyView',st);
end

function onView(tab)
st = getappdata(tab,'landing2dOntologyView');
if isempty(st), return; end
key = char(st.viewDrop.Value);
if isempty(key) || strcmp(key,currentViewKey(st))
    return;
end
try
    landing2d.viz.attachOntologyView(tab,key,st.options);
catch err
    % 표시 대상을 바꾸지 못해도 현재 화면은 그대로 두고 이유만 알립니다.
    st.viewDrop.Value = currentViewKey(st);
    st.statusLabel.Text = sprintf('표시 대상을 바꾸지 못했습니다: %s',err.message);
    setappdata(tab,'landing2dOntologyView',st);
end
end

function onReset(tab)
st = getappdata(tab,'landing2dOntologyView');
if isempty(st), return; end
st.searchText = '';
st.searchField.Value = '';
st.relationFilter = '';
st.relationDrop.Value = '';
st.selection = struct('kind','summary','id','','sourceId','','targetId','');
st.focusIndex = [];
st = renderAll(st);
setappdata(tab,'landing2dOntologyView',st);
end

function onList(tab)
st = getappdata(tab,'landing2dOntologyView');
if isempty(st), return; end
value = st.listBox.Value;
if isempty(value) || ~isnumeric(value) || value < 1 || value > numel(st.listItems)
    return;
end
item = st.listItems(value);
st = applySelection(st,item.kind,item.id,'','');
setappdata(tab,'landing2dOntologyView',st);
end

function onGraphClick(tab)
st = getappdata(tab,'landing2dOntologyView');
if isempty(st) || isempty(st.axGraph) || ~all(isgraphics(st.axGraph))
    return;
end
point = st.axGraph.CurrentPoint;
graphPick(tab,point(1,1),point(1,2));
end

function graphPick(tab,px,py)
% 좌표 하나를 받아 선택을 수행하는 진입점. 클릭 콜백과 테스트가 함께 씁니다.
% GraphPlot은 클릭한 노드나 간선 ID를 돌려주지 않으므로 직접 찾습니다.
st = getappdata(tab,'landing2dOntologyView');
if isempty(st) || isempty(st.graphPlot) || ~all(isgraphics(st.graphPlot))
    return;
end
h = st.graphPlot;
% range()는 Statistics Toolbox 함수이므로 쓰지 않습니다.
span = max([max(h.XData)-min(h.XData),max(h.YData)-min(h.YData),1]);
tolerance = 0.06*span;

d = hypot(h.XData-px,h.YData-py);
[best,k] = min(d);
if ~isempty(best) && best <= tolerance
    st = applySelection(st,'element',st.model.elements(st.displayIndex(k)).id,'','');
    setappdata(tab,'landing2dOntologyView',st);
    return;
end

[bestEdge,dEdge] = nearestEdge(st,px,py);
if ~isempty(bestEdge) && dEdge <= tolerance
    st = applySelection(st,'relation',st.model.relations(bestEdge).id,'','');
    setappdata(tab,'landing2dOntologyView',st);
    return;
end

st = applySelection(st,'summary','','','');
setappdata(tab,'landing2dOntologyView',st);
end

function [relationIndex,distance] = nearestEdge(st,px,py)
relationIndex = [];
distance = Inf;
rows = st.edgeRows;
if isempty(rows)
    return;
end
h = st.graphPlot;
position = zeros(1,st.model.nElements);
position(st.displayIndex) = 1:numel(st.displayIndex);
for e = 1:numel(rows)
    r = st.model.relations(rows(e));
    if ~isempty(st.relationFilter) && ~strcmp(r.predicateId,st.relationFilter)
        continue;
    end
    a = position(r.sourceIndex);
    b = position(r.targetIndex);
    if a == 0 || b == 0
        continue;
    end
    d = pointSegmentDistance(px,py,h.XData(a),h.YData(a),h.XData(b),h.YData(b));
    if d < distance
        distance = d;
        relationIndex = rows(e);
    end
end
end

function d = pointSegmentDistance(px,py,x1,y1,x2,y2)
dx = x2-x1;
dy = y2-y1;
denom = dx*dx+dy*dy;
if denom < eps
    d = hypot(px-x1,py-y1);
    return;
end
t = ((px-x1)*dx+(py-y1)*dy)/denom;
t = min(max(t,0),1);
d = hypot(px-(x1+t*dx),py-(y1+t*dy));
end

function onMatrixClick(tab)
st = getappdata(tab,'landing2dOntologyView');
if isempty(st) || isempty(st.axMatrix) || ~all(isgraphics(st.axMatrix))
    return;
end
point = st.axMatrix.CurrentPoint;
matrixPick(tab,point(1,1),point(1,2));
end

function matrixPick(tab,x,y)
% 행렬 좌표 하나를 받아 선택을 수행하는 진입점. x는 열(도착), y는 행(출발)입니다.
st = getappdata(tab,'landing2dOntologyView');
if isempty(st), return; end
col = round(x);
row = round(y);
n = numel(st.displayIndex);
if row < 1 || row > n || col < 1 || col > n
    st = applySelection(st,'summary','','','');
    setappdata(tab,'landing2dOntologyView',st);
    return;
end
sourceId = st.model.elements(st.displayIndex(row)).id;
targetId = st.model.elements(st.displayIndex(col)).id;
hits = matchingRelations(st,st.displayIndex(row),st.displayIndex(col));
if numel(hits) == 1
    st = applySelection(st,'relation',st.model.relations(hits).id,'','');
else
    st = applySelection(st,'cell','',sourceId,targetId);
end
setappdata(tab,'landing2dOntologyView',st);
end

function hits = matchingRelations(st,sourceIndex,targetIndex)
hits = [];
for k = 1:numel(st.model.relations)
    r = st.model.relations(k);
    if r.sourceIndex ~= sourceIndex || r.targetIndex ~= targetIndex
        continue;
    end
    if ~isempty(st.relationFilter) && ~strcmp(r.predicateId,st.relationFilter)
        continue;
    end
    hits(end+1) = k; %#ok<AGROW>
end
end

% ------------------------------------------------------------------ 선택 처리
function st = applySelection(st,kind,id,sourceId,targetId)
st.selection = struct('kind',kind,'id',id, ...
    'sourceId',sourceId,'targetId',targetId);
needsRedraw = false;
focus = selectedElementIndex(st);
if ~isempty(focus) && st.model.nElements > st.maxDisplayNodes ...
        && ~ismember(focus,st.displayIndex)
    st.focusIndex = focus;
    needsRedraw = true;
end
if needsRedraw
    st = computeDisplay(st);
end
st = renderGraph(st);
st = renderMatrix(st);
st = renderDetails(st);
st = renderStatus(st);
syncListSelection(st);
end

function index = selectedElementIndex(st)
index = [];
switch st.selection.kind
    case 'element'
        k = elementIndexById(st.model,st.selection.id);
        if k > 0
            index = k;
        end
    case 'cell'
        k = elementIndexById(st.model,st.selection.sourceId);
        if k > 0
            index = k;
        end
end
end

function index = elementIndexById(model,id)
index = find(strcmp(model.elementIds,id),1);
if isempty(index)
    index = 0;
end
end

function ok = isNeighbor(model,selected,index)
ok = false;
if isempty(selected) || selected == 0
    return;
end
for k = 1:numel(model.relations)
    r = model.relations(k);
    if (r.sourceIndex == selected && r.targetIndex == index) ...
            || (r.targetIndex == selected && r.sourceIndex == index)
        ok = true;
        return;
    end
end
end

% ------------------------------------------------------------------ 정리
function onTabDelete(tab)
% 탭이 닫히면 콜백이 참조하던 자료를 정리합니다.
if isappdata(tab,'landing2dOntologyView')
    rmappdata(tab,'landing2dOntologyView');
end
end
