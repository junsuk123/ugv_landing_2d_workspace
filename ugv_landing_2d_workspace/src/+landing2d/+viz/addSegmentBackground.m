function bands = addSegmentBackground(ax, segments, coordinate, c)
% ADDSEGMENTBACKGROUND  공통 반투명 구간 배경. coordinate='time' 또는 'position'.
% time: 실제 구간 전환 시각. position: 해당 시각의 UGV 진행 위치.
% FaceAlpha만 적용하며 데이터/축 범위를 바꾸지 않음.
% label은 현재 보이는 부분의 중앙에 배치. YLim 변경 시 배경 높이 갱신.
if ~(strcmp(coordinate,'time') || strcmp(coordinate,'position'))
    error('landing2d:InvalidCoordinate','coordinate must be time or position.');
end
if isappdata(ax,'Landing2dBackground')
    error('landing2d:DuplicateBackground','This axes already has segment shading.');
end
xLimits = xlim(ax);
yLimits = ylim(ax);
hold(ax,'on');
% 구간 패치가 자동 축 범위를 다시 늘리지 않도록 범위를 먼저 고정.
xlim(ax,xLimits);
ylim(ax,yLimits);
bands = gobjects(3,1);
labels = gobjects(3,1);
edges = zeros(3,2);
for i = 1:3
    if strcmp(coordinate,'time')
        edges(i,:) = [segments(i).tStart,segments(i).tEnd];
    else
        edges(i,:) = [segments(i).xStart,segments(i).xEnd];
    end
    xx = edges(i,[1,2,2,1]);
    yy = yLimits([1,1,2,2]);
    bands(i) = patch(ax,xx,yy,segments(i).color, ...
        'FaceAlpha',c.segmentAlpha,'EdgeColor','none', ...
        'HandleVisibility','off','HitTest','off','PickableParts','none', ...
        'Tag','Landing2dSegmentBackground');
    if c.showSegmentLabels
        labels(i) = text(ax,mean(edges(i,:)),yLimits(2),segments(i).label, ...
            'HorizontalAlignment','center','VerticalAlignment','top', ...
            'FontSize',9,'FontWeight','bold','Interpreter','none', ...
            'Color',0.60*segments(i).color,'Clipping','on', ...
            'HandleVisibility','off','HitTest','off','PickableParts','none', ...
            'Tag','Landing2dSegmentLabel');
    end
end
% 곡선 뒤로 배치하여 반투명 패치가 궤적/속도 선을 가리지 않도록 함.
uistack(bands,'bottom');
setappdata(ax,'Landing2dBackground',struct( ...
    'patches',bands,'labels',labels,'edges',edges));
landing2d.viz.refreshSegmentBackground(ax);
% addlistener의 수명은 소스 axes에 연결. 핸들을 MAT/FIG appdata에 저장하지 않음.
addlistener(ax,'YLim','PostSet',@(~,~)landing2d.viz.refreshSegmentBackground(ax));
addlistener(ax,'XLim','PostSet',@(~,~)landing2d.viz.refreshSegmentBackground(ax));
end
