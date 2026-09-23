function [fig, layout] = createTrajectoryFigure(r, c)
% CREATETRAJECTORYFIGURE  최종 x-z 비행 궤적 + UGV 진행 위치 기준 구간 배경.
% 공간 배경을 드론의 시간 구간으로 해석하지 않도록 제목에 기준을 명시.
visibility = 'on';
if ~c.figureVisible, visibility = 'off'; end
fig = figure('Name',[r.name,' - x-z trajectory'],'NumberTitle','off', ...
    'Position',[100,120,1300,620],'Color','w','Visible',visibility);
layout = tiledlayout(fig,1,1,'TileSpacing','compact','Padding','compact');
ax = nexttile(layout);
landing2d.viz.prepareAxes(ax);
last = numel(r.time);
if c.trajectoryFlightOnly
    endTime = r.time(end);
    if isfinite(r.landingTime), endTime = r.landingTime; end
    if isfinite(r.failureTime), endTime = min(endTime,r.failureTime); end
    last = find(r.time <= endTime+1e-10,1,'last');
end
idx = 1:last;
hDrone = plot(ax,r.xDrone(idx),r.zDrone(idx),'-', ...
    'Color',[0.05,0.20,0.42],'LineWidth',2,'DisplayName','Drone trajectory');
hPad = plot(ax,r.xUgv(idx),r.zPad(idx),'--', ...
    'Color',[0.32,0.32,0.32],'LineWidth',1.4,'DisplayName','UGV / pad trajectory');
hStart = plot(ax,r.xDrone(1),r.zDrone(1),'o','Color',[0.1,0.1,0.1], ...
    'MarkerFaceColor','w','MarkerSize',7,'LineWidth',1.4,'DisplayName','Start');
legendHandles = [hDrone;hPad;hStart];
if c.showEventLines
    h = addPoints(ax,r,r.lossTimes,'x',[0.68,0.17,0.17],'FOV loss');
    if ~isempty(h), legendHandles(end+1,1) = h; end
    h = addPoints(ax,r,r.reacquireTimes,'s',[0.13,0.43,0.28],'Reacquired');
    if ~isempty(h), legendHandles(end+1,1) = h; end
    if isfinite(r.landingTime)
        h = addPoints(ax,r,r.landingTime,'v',[0.1,0.1,0.1],'Landed');
        legendHandles(end+1,1) = h;
    elseif isfinite(r.failureTime)
        h = addPoints(ax,r,r.failureTime,'v',[0.68,0.17,0.17],'Failed');
        legendHandles(end+1,1) = h;
    end
end
xx = [r.xDrone(idx);r.xUgv(idx)];
xSpan = max(max(xx)-min(xx),1);
xlim(ax,[min(xx)-0.03*xSpan,max(xx)+0.03*xSpan]);
zMax = max([r.zDrone(idx);r.zPad(idx)]);
ylim(ax,[0,max(zMax*1.28,c.padHeight+1)]);
segments = landing2d.scenario.segmentMetadata(r,c);
landing2d.viz.addSegmentBackground(ax,segments,'position',c);
for i = 2:3
    xline(ax,segments(i).xStart,':',sprintf('t = %.2g s',segments(i).tStart), ...
        'Color',[0.5,0.5,0.5],'HandleVisibility','off', ...
        'LabelVerticalAlignment','bottom');
end
xlabel(ax,'Forward position x [m]');
ylabel(ax,'Altitude z [m]');
title(layout,{sprintf('%s | x-z trajectory | 0-%.2f s | %s', ...
    r.name,r.time(last),r.status), ...
    'Background boundaries: UGV positions at speed switches (not drone time boundaries)'}, ...
    'Interpreter','none','Color',[0.12,0.12,0.12]);
legend(ax,legendHandles,'Location','southoutside','Orientation','horizontal', ...
    'AutoUpdate','off','Box','off','TextColor',[0.15,0.15,0.15]);
end

function h = addPoints(ax,r,times,marker,color,name)
% 한 종류 사건을 한 그래픽 객체로 생성하여 범례 중복 방지.
h = [];
if isempty(times), return; end
x = interp1(r.time,r.xDrone,times,'linear');
z = interp1(r.time,r.zDrone,times,'linear');
h = plot(ax,x,z,marker,'LineStyle','none','Color',color, ...
    'MarkerFaceColor','w','MarkerSize',8,'LineWidth',1.5,'DisplayName',name);
end
