function refreshSegmentBackground(ax)
% REFRESHSEGMENTBACKGROUND  축 확대/축소 시 패치 높이와 라벨 위치 갱신.
if ~isgraphics(ax,'axes') || ~isappdata(ax,'Landing2dBackground')
    return;
end
info = getappdata(ax,'Landing2dBackground');
y = ylim(ax);
x = xlim(ax);
yLabel = y(2)-0.035*diff(y);
for i = 1:numel(info.patches)
    if isgraphics(info.patches(i))
        set(info.patches(i),'YData',y([1,1,2,2]));
    end
    if isgraphics(info.labels(i))
        lo = max(info.edges(i,1),x(1));
        hi = min(info.edges(i,2),x(2));
        if hi > lo
            set(info.labels(i),'Position',[(lo+hi)/2,yLabel,0],'Visible','on');
        else
            set(info.labels(i),'Visible','off');
        end
    end
end
end
