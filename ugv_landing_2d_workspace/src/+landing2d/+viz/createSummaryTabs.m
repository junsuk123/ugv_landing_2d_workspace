function [fig, tabs, layouts] = createSummaryTabs(runs, c, figureName)
% CREATESUMMARYTABS  시나리오마다 탭 하나, 탭마다 그래프 두 개.
%   왼쪽: 시간 - 패드/드론 상대거리.  오른쪽: 드론과 착륙 패드의 전체 궤적.
%
%   runs(i).results   : 시나리오 결과 배열 (모든 run이 같은 시나리오 수)
%   runs(i).label     : 범례 이름 (예: 'PD', 'PPO RL')
%   runs(i).color     : 선 색
%   runs(i).lineStyle : 선 종류
%
% 왼쪽 배경은 시간 구간, 오른쪽 배경은 구간 전환 시각의 UGV 진행 위치입니다.
% 두 배경은 같은 뜻이 아니므로 제목에 기준을 함께 적습니다.
if nargin < 3 || isempty(figureName)
    figureName = 'UGV landing summary';
end
runs = landing2d.viz.normalizeRuns(runs);
nCases = numel(runs(1).results);
for i = 2:numel(runs)
    assert(numel(runs(i).results) == nCases, ...
        'landing2d:RunMismatch','All runs must have the same scenario count.');
end
visibility = 'on';
if ~c.figureVisible, visibility = 'off'; end
fig = figure('Name',figureName,'NumberTitle','off', ...
    'Position',[70,70,1500,720],'Color','w','Visible',visibility);
group = uitabgroup(fig,'Units','normalized','Position',[0,0,1,1]);
tabs = gobjects(nCases,1);
layouts = gobjects(nCases,1);
for j = 1:nCases
    tabs(j) = uitab(group,'Title',sprintf('Scenario %d',j),'BackgroundColor','w');
    layouts(j) = tiledlayout(tabs(j),1,2,'TileSpacing','compact','Padding','compact');
    axDistance = nexttile(layouts(j));
    landing2d.viz.prepareAxes(axDistance);
    axTrajectory = nexttile(layouts(j));
    landing2d.viz.prepareAxes(axTrajectory);
    drawRecoveryTimePanel(axDistance,runs,j,c);
    drawRelativeTrajectoryPanel(axTrajectory,runs,j,c);
    title(layouts(j),tabTitle(runs,j),'Interpreter','none','Color',[0.12,0.12,0.12]);
end
group.SelectedTab = tabs(1);
end

% ---------------------------------------------------------------- 왼쪽 패널
function drawDistancePanel(ax,runs,j,c) %#ok<DEFNU>
handles = gobjects(0,1);
labels = {};
tShow = 0;
dMax = 0;
for i = 1:numel(runs)
    r = runs(i).results(j);
    d = landing2d.metrics.relativeDistance(r);
    handles(end+1,1) = plot(ax,r.time,d,runs(i).lineStyle, ...
        'Color',runs(i).color,'LineWidth',1.9); %#ok<AGROW>
    labels{end+1} = runs(i).label; %#ok<AGROW>
    tShow = max(tShow,landing2d.viz.flightEndTime(r));
    dMax = max(dMax,max(d(isfinite(d))));
end
tFull = runs(1).results(j).time(end);
tShow = min(tFull,max(1.12*tShow+1,0.2*tFull));
xlim(ax,[0,tShow]);
ylim(ax,[0,max(1.32*dMax,0.5)]);
title(ax,'Pad-drone relative distance');
xlabel(ax,'Time [s]');
ylabel(ax,'Relative distance [m]');
segments = landing2d.scenario.segmentMetadata(runs(1).results(j),c);
landing2d.viz.addSegmentBackground(ax,segments,'time',c);
for tb = c.segmentTimes
    if tb < tShow
        xline(ax,tb,':','Color',[0.50,0.50,0.50],'HandleVisibility','off');
    end
end
if c.showEventLines
    for i = 1:numel(runs)
        r = runs(i).results(j);
        d = landing2d.metrics.relativeDistance(r);
        [h,name] = markEvents(ax,r,r.time,d);
        handles = [handles;h]; %#ok<AGROW>
        labels = [labels,name]; %#ok<AGROW>
    end
end
[handles,labels] = uniqueEntries(handles,labels);
legend(ax,handles,labels,'Location','northeast','AutoUpdate','off', ...
    'Box','off','TextColor',[0.15,0.15,0.15]);
end

% -------------------------------------------------------------- 오른쪽 패널
function drawTrajectoryPanel(ax,runs,j,c) %#ok<DEFNU>
handles = gobjects(0,1);
labels = {};
base = runs(1).results(j);
lastPad = numel(base.time);
if c.trajectoryFlightOnly
    tEnd = 0;
    for i = 1:numel(runs)
        tEnd = max(tEnd,landing2d.viz.flightEndTime(runs(i).results(j)));
    end
    lastPad = find(base.time <= tEnd+1e-10,1,'last');
end
padIdx = 1:lastPad;
handles(end+1,1) = plot(ax,base.xUgv(padIdx),base.zPad(padIdx),'--', ...
    'Color',[0.32,0.32,0.32],'LineWidth',1.4);
labels{end+1} = 'UGV / pad';
allX = base.xUgv(padIdx);
allZ = base.zPad(padIdx);
for i = 1:numel(runs)
    r = runs(i).results(j);
    last = numel(r.time);
    if c.trajectoryFlightOnly
        last = find(r.time <= landing2d.viz.flightEndTime(r)+1e-10,1,'last');
    end
    idx = 1:last;
    handles(end+1,1) = plot(ax,r.xDrone(idx),r.zDrone(idx),runs(i).lineStyle, ...
        'Color',runs(i).color,'LineWidth',2); %#ok<AGROW>
    labels{end+1} = runs(i).label; %#ok<AGROW>
    allX = [allX;r.xDrone(idx)]; %#ok<AGROW>
    allZ = [allZ;r.zDrone(idx)]; %#ok<AGROW>
end
hStart = plot(ax,base.xUgv(1),runs(1).results(j).zDrone(1),'o', ...
    'Color',[0.1,0.1,0.1],'MarkerFaceColor','w','MarkerSize',7,'LineWidth',1.4);
handles(end+1,1) = hStart;
labels{end+1} = 'Start';
xSpan = max(max(allX)-min(allX),1);
xlim(ax,[min(allX)-0.03*xSpan,max(allX)+0.03*xSpan]);
ylim(ax,[0,max(1.30*max(allZ),c.padHeight+1)]);
title(ax,'Drone and pad trajectory (x-z)');
xlabel(ax,'Forward position x [m]');
ylabel(ax,'Altitude z [m]');
segments = landing2d.scenario.segmentMetadata(base,c);
landing2d.viz.addSegmentBackground(ax,segments,'position',c);
for i = 2:3
    xline(ax,segments(i).xStart,':',sprintf('t = %.2g s',segments(i).tStart), ...
        'Color',[0.5,0.5,0.5],'HandleVisibility','off', ...
        'LabelVerticalAlignment','bottom');
end
if c.showEventLines
    for i = 1:numel(runs)
        r = runs(i).results(j);
        [h,name] = markEvents(ax,r,r.xDrone,r.zDrone);
        handles = [handles;h]; %#ok<AGROW>
        labels = [labels,name]; %#ok<AGROW>
    end
end
[handles,labels] = uniqueEntries(handles,labels);
legend(ax,handles,labels,'Location','northeast','AutoUpdate','off', ...
    'Box','off','TextColor',[0.15,0.15,0.15]);
end

% ------------------------------------------------------------------ 보조 함수
function [handles,labels] = markEvents(ax,r,xVec,yVec)
% 사건 시각을 각 곡선 위의 점으로 표시. 시간축/공간축 모두 같은 규칙 사용.
handles = gobjects(0,1);
labels = {};
styles = landing2d.viz.eventStyles();
for k = 1:numel(styles)
    times = r.(styles(k).field);
    times = times(isfinite(times));
    if isempty(times), continue; end
    x = interp1(r.time,xVec,times,'linear');
    y = interp1(r.time,yVec,times,'linear');
    handles(end+1,1) = plot(ax,x,y,styles(k).marker,'LineStyle','none', ...
        'Color',styles(k).color,'MarkerFaceColor',styles(k).faceColor, ...
        'MarkerSize',8,'LineWidth',1.5); %#ok<AGROW>
    labels{end+1} = styles(k).label; %#ok<AGROW>
end
end

function [handles,labels] = uniqueEntries(handles,labels)
% 두 제어기가 같은 사건을 가질 때 범례 항목이 중복되지 않도록 정리.
[~,keep] = unique(labels,'stable');
handles = handles(keep);
labels = labels(keep);
end

function text = tabTitle(runs,j)
r = runs(1).results(j);
status = cell(1,numel(runs));
for i = 1:numel(runs)
    ri = runs(i).results(j);
    if isfinite(ri.landingTime)
        status{i} = sprintf('%s: landed at %.2f s',runs(i).label,ri.landingTime);
    else
        status{i} = sprintf('%s: %s',runs(i).label,ri.status);
    end
end
text = {sprintf('%s | UGV target %.2g / %.2g / %.2g m/s',r.name,r.speeds), ...
    strjoin(status,'   |   ')};
notes = {};
for i = 1:numel(runs)
    if isfield(runs,'note') && ~isempty(runs(i).note)
        notes{end+1} = sprintf('%s: %s',runs(i).label,runs(i).note); %#ok<AGROW>
    end
end
if ~isempty(notes)
    text{end+1} = strjoin(notes,'   |   ');
end
text{end+1} = ['Left: signed error with +/- FOV limits.  ' ...
    'Right: pad-relative recovery path with loss/reacquire/landing events.'];
end

function drawRecoveryTimePanel(ax,runs,j,c)
% Signed horizontal error with the altitude-dependent camera boundaries.
handles = gobjects(0,1);
labels = {};
tShow = 0;
yMax = 0;
for i = 1:numel(runs)
    r = runs(i).results(j);
    last = find(r.time <= landing2d.viz.flightEndTime(r)+1e-10,1,'last');
    idx = 1:last;
    handles(end+1,1) = plot(ax,r.time(idx),r.xError(idx), ...
        runs(i).lineStyle,'Color',runs(i).color,'LineWidth',1.9); %#ok<AGROW>
    labels{end+1} = runs(i).label; %#ok<AGROW>
    plot(ax,r.time(idx),r.fovHalfWidth(idx),':','Color',runs(i).color, ...
        'LineWidth',1.0,'HandleVisibility','off');
    plot(ax,r.time(idx),-r.fovHalfWidth(idx),':','Color',runs(i).color, ...
        'LineWidth',1.0,'HandleVisibility','off');
    tShow = max(tShow,r.time(last));
    yMax = max(yMax,max([abs(r.xError(idx));r.fovHalfWidth(idx)]));
    if c.showEventLines
        [h,name] = markEvents(ax,r,r.time,r.xError);
        handles = [handles;h]; %#ok<AGROW>
        labels = [labels,name]; %#ok<AGROW>
    end
end
xlim(ax,[0,max(tShow,c.dt)]);
ylim(ax,1.08*[-max(yMax,0.5),max(yMax,0.5)]);
yline(ax,0,'-','Color',[0.55,0.55,0.55],'HandleVisibility','off');
segments = landing2d.scenario.segmentMetadata(runs(1).results(j),c);
landing2d.viz.addSegmentBackground(ax,segments,'time',c);
title(ax,'Signed tracking error and FOV boundaries');
xlabel(ax,'Time [s]');
ylabel(ax,'Pad-relative horizontal error [m]');
[handles,labels] = uniqueEntries(handles,labels);
legend(ax,handles,labels,'Location','northeast','AutoUpdate','off', ...
    'Box','off','TextColor',[0.15,0.15,0.15]);
end

function drawRelativeTrajectoryPanel(ax,runs,j,c)
% Pad-relative trajectory exposes recovery direction and climb directly.
handles = gobjects(0,1);
labels = {};
allX = [];
allH = [];
for i = 1:numel(runs)
    r = runs(i).results(j);
    last = find(r.time <= landing2d.viz.flightEndTime(r)+1e-10,1,'last');
    idx = 1:last;
    height = r.zDrone(idx)-c.padHeight;
    handles(end+1,1) = plot(ax,r.xError(idx),height, ...
        runs(i).lineStyle,'Color',runs(i).color,'LineWidth',2); %#ok<AGROW>
    labels{end+1} = runs(i).label; %#ok<AGROW>
    allX = [allX;r.xError(idx)]; %#ok<AGROW>
    allH = [allH;height]; %#ok<AGROW>
    if c.showEventLines
        [h,name] = markEvents(ax,r,r.xError,r.zDrone-c.padHeight);
        handles = [handles;h]; %#ok<AGROW>
        labels = [labels,name]; %#ok<AGROW>
    end
end
xSpan = max(max(allX)-min(allX),1);
xlim(ax,[min(allX)-0.05*xSpan,max(allX)+0.05*xSpan]);
ylim(ax,[0,max(1.08*max(allH),c.initialHeight)]);
xline(ax,0,'-','Color',[0.45,0.45,0.45],'HandleVisibility','off');
title(ax,'Pad-relative recovery trajectory');
xlabel(ax,'Horizontal error [m]');
ylabel(ax,'Height above pad [m]');
[handles,labels] = uniqueEntries(handles,labels);
legend(ax,handles,labels,'Location','northeast','AutoUpdate','off', ...
    'Box','off','TextColor',[0.15,0.15,0.15]);
end
