function [fig, layout] = createPositionVelocityFigure(r, c)
% CREATEPOSITIONVELOCITYFIGURE  위치/고도/수평속도/수직속도 + 시간 구간 배경.
visibility = 'on';
if ~c.figureVisible, visibility = 'off'; end
fig = figure('Name',[r.name,' - position and velocity'], ...
    'NumberTitle','off','Position',[70,60,1400,900], ...
    'Color','w','Visible',visibility);
layout = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
title(layout,{sprintf('%s | UGV targets %.2g / %.2g / %.2g m/s | %s', ...
    r.name,r.speeds,r.status), ...
    'Background: S1 / S2 / S3 target-speed segments (actual speed includes ramps)'}, ...
    'Interpreter','none','Color',[0.12,0.12,0.12]);
ax = gobjects(4,1);
handles = cell(4,1);
labels = {{'UGV / pad','Drone'}, {'Drone','Pad'}, ...
    {'UGV actual','Drone','UGV target'}, {'Drone','UGV / pad'}};
for i = 1:4
    ax(i) = nexttile(layout);
    landing2d.viz.prepareAxes(ax(i));
end
ugvColor = [0.25,0.27,0.30];
droneColor = [0.05,0.20,0.42];
handles{1} = [plot(ax(1),r.time,r.xUgv,'-','Color',ugvColor,'LineWidth',1.5); ...
    plot(ax(1),r.time,r.xDrone,'--','Color',droneColor,'LineWidth',1.7)];
title(ax(1),'Forward position'); ylabel(ax(1),'x [m]');
handles{2} = [plot(ax(2),r.time,r.zDrone,'-','Color',droneColor,'LineWidth',1.7); ...
    plot(ax(2),r.time,r.zPad,'--','Color',ugvColor,'LineWidth',1.3)];
title(ax(2),'Altitude (ground reference)'); ylabel(ax(2),'z [m]');
handles{3} = [plot(ax(3),r.time,r.vxUgv,'-','Color',ugvColor,'LineWidth',1.5); ...
    plot(ax(3),r.time,r.vxDrone,'--','Color',droneColor,'LineWidth',1.7); ...
    plot(ax(3),r.time,r.vxUgvCommand,':','Color',[0.40,0.40,0.40],'LineWidth',1.3)];
title(ax(3),'Forward velocity'); ylabel(ax(3),'v_x [m/s]');
handles{4} = [plot(ax(4),r.time,r.vzDrone,'-','Color',droneColor,'LineWidth',1.7); ...
    plot(ax(4),r.time,zeros(size(r.time)),'--','Color',ugvColor,'LineWidth',1.3)];
title(ax(4),'Vertical velocity (+ up / - down)'); ylabel(ax(4),'v_z [m/s]');
segments = landing2d.scenario.segmentMetadata(r,c);
for i = 1:4
    xlabel(ax(i),'Time [s]');
    xlim(ax(i),[r.time(1),r.time(end)]);
    % 라벨 전용 상단 여백. 기존 데이터 값은 변경하지 않음.
    y = ylim(ax(i));
    span = max(diff(y),0.1);
    ylim(ax(i),[y(1)-0.02*span,y(2)+0.24*span]);
    landing2d.viz.addSegmentBackground(ax(i),segments,'time',c);
    for tb = c.segmentTimes
        xline(ax(i),tb,':','Color',[0.50,0.50,0.50],'HandleVisibility','off');
    end
    legend(ax(i),handles{i},labels{i},'Location','southoutside', ...
        'Orientation','horizontal','AutoUpdate','off','Box','off','TextColor',[0.15,0.15,0.15]);
end
landing2d.viz.addEventLines(ax(2),r,c);
linkaxes(ax,'x');
end
