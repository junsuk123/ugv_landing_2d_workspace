function fig = replayAgentComparison(runs,c)
% REPLAYAGENTCOMPARISON  Replay three agents together on fixed full-path axes.
runs = landing2d.viz.normalizeRuns(runs);
nAgents = numel(runs);
nCases = numel(runs(1).results);
assert(nAgents == 3,'landing2d:AgentCount', ...
    'The checkpoint comparison expects exactly three agents.');
for i = 2:nAgents
    assert(numel(runs(i).results) == nCases,'landing2d:RunMismatch', ...
        'Every agent must have the same scenario count.');
end

visibility = 'on';
if ~c.figureVisible, visibility = 'off'; end
fig = figure('Name','PN vs PPO RL vs Ontology-RGAT RL - real-time', ...
    'Tag','landing2dFinalTest', ...
    'NumberTitle','off','Position',[55,55,1540,820], ...
    'Color','w','Visible',visibility);
group = uitabgroup(fig,'Units','normalized','Position',[0,0,1,1]);
views = cell(1,nCases);
for j = 1:nCases
    tab = uitab(group,'Title',sprintf('Scenario %d',j), ...
        'BackgroundColor','w');
    ax = axes('Parent',tab,'Position',[0.055,0.10,0.69,0.83]);
    hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    [xLimits,zLimits] = fixedBounds(runs,j,c);
    xlim(ax,xLimits); ylim(ax,zLimits);
    set(ax,'XLimMode','manual','YLimMode','manual');
    speedSegments = landing2d.scenario.segmentMetadata( ...
        runs(1).results(j),c);
    landing2d.viz.addSegmentBackground(ax,speedSegments,'position',c);
    xlabel(ax,'Forward position x [m]');
    ylabel(ax,'Altitude z [m]');
    title(ax,sprintf('Scenario %d | target %.1f / %.1f / %.1f m/s', ...
        j,c.scenarioSpeeds(j,:)));
    plot(ax,xLimits,[0,0],'-','Color',[0.35,0.35,0.35], ...
        'HandleVisibility','off');
    base = runs(1).results(j);
    plot(ax,base.xUgv,base.zPad,'--','Color',[0.35,0.35,0.35], ...
        'LineWidth',1.1,'DisplayName','UGV/pad full path');
    hUgv = rectangle(ax,'Position',[base.xUgv(1)-0.9,0,1.8,c.padHeight], ...
        'LineWidth',1.4,'EdgeColor',[0.15,0.15,0.15], ...
        'FaceColor',[0.82,0.82,0.82],'HandleVisibility','off');
    hPad = plot(ax,base.xUgv(1)+[-c.padHalfLength,c.padHalfLength], ...
        [c.padHeight,c.padHeight],'-','Color',[0.12,0.12,0.12], ...
        'LineWidth',5,'HandleVisibility','off');
    hFov = gobjects(1,nAgents);
    hTrail = gobjects(1,nAgents);
    hDrone = gobjects(1,nAgents);
    for i = 1:nAgents
        color = runs(i).color;
        hFov(i) = patch(ax,nan,nan,color,'FaceAlpha',0.055, ...
            'EdgeColor',color,'LineStyle',':','HandleVisibility','off');
        hTrail(i) = plot(ax,nan,nan,runs(i).lineStyle,'Color',color, ...
            'LineWidth',2.0,'DisplayName',runs(i).label);
        hDrone(i) = plot(ax,nan,nan,'o','Color',color, ...
            'MarkerFaceColor',color,'MarkerSize',7, ...
            'HandleVisibility','off');
    end
    legend(ax,'Location','southoutside','Orientation','horizontal', ...
        'Box','off','AutoUpdate','off');
    info = uicontrol(tab,'Style','text','Units','normalized', ...
        'Position',[0.765,0.13,0.22,0.76], ...
        'HorizontalAlignment','left','BackgroundColor','w', ...
        'FontName','Consolas','FontSize',10,'String','');
    views{j} = struct('tab',tab,'ax',ax,'ugv',hUgv,'pad',hPad, ...
        'fov',hFov,'trail',hTrail,'drone',hDrone,'info',info, ...
        'xLimits',xLimits,'zLimits',zLimits);
end
group.SelectedTab = views{1}.tab;

t = runs(1).results(1).time;
frameStride = max(1,round(1/(c.animationHz*c.dt)));
wallClock = tic;
for k = 1:numel(t)
    if ~isgraphics(fig), return; end
    if mod(k-1,frameStride) ~= 0 && k ~= numel(t), continue; end
    if isfinite(c.playbackSpeed)
        remaining = t(k)/c.playbackSpeed-toc(wallClock);
        if remaining > 0, pause(remaining); end
    end
    for j = 1:nCases
        updateScenario(views{j},runs,j,k,c);
    end
    drawnow limitrate;
end
if isgraphics(fig), drawnow; end
end

function updateScenario(view,runs,j,k,c)
base = runs(1).results(j);
xp = base.xUgv(k);
set(view.ugv,'Position',[xp-0.9,0,1.8,c.padHeight]);
set(view.pad,'XData',xp+[-c.padHalfLength,c.padHalfLength], ...
    'YData',[c.padHeight,c.padHeight]);
lines = cell(1,numel(runs)+2);
lines{1} = sprintf('t = %6.2f / %.2f s',base.time(k),base.time(end));
lines{2} = sprintf('UGV speed = %5.2f m/s',base.vxUgv(k));
for i = 1:numel(runs)
    r = runs(i).results(j);
    xd = r.xDrone(k);
    zd = r.zDrone(k);
    width = r.fovHalfWidth(k);
    set(view.fov(i),'XData',[xd,xd-width,xd+width], ...
        'YData',[zd,c.padHeight,c.padHeight]);
    set(view.trail(i),'XData',r.xDrone(1:k),'YData',r.zDrone(1:k));
    set(view.drone(i),'XData',xd,'YData',zd);
    lines{i+2} = sprintf(['\n%s\n  %-17s | visible %-3s\n' ...
        '  error %+7.2f m | h %6.2f m'],runs(i).label, ...
        modeText(r,k),yesNo(r.visible(k)),r.xError(k),zd-c.padHeight);
end
set(view.info,'String',strjoin(lines,newline));
% Re-assert fixed bounds so callbacks or drawing operations cannot autoscale.
xlim(view.ax,view.xLimits); ylim(view.ax,view.zLimits);
end

function [xLimits,zLimits] = fixedBounds(runs,j,c)
x = [];
z = [];
for i = 1:numel(runs)
    r = runs(i).results(j);
    x = [x;r.xDrone(:);r.xUgv(:); ...
        r.xDrone(:)-r.fovHalfWidth(:);r.xDrone(:)+r.fovHalfWidth(:)]; %#ok<AGROW>
    z = [z;r.zDrone(:);r.zPad(:)]; %#ok<AGROW>
end
x = x(isfinite(x)); z = z(isfinite(z));
span = max(max(x)-min(x),1);
xLimits = [min(x)-0.03*span,max(x)+0.03*span];
zTop = min(c.padHeight+c.ceilingHeight,max(max(z)+1,c.padHeight+c.initialHeight));
zLimits = [0,zTop];
end

function text = modeText(r,k)
labels = {'TRACK/ALIGN','SEARCH/CLIMB','LANDED','FAILED'};
index = max(1,min(numel(labels),round(r.mode(k))));
text = labels{index};
if index == 1 && r.descending(k), text = 'TRACK/DESCEND'; end
end

function text = yesNo(value)
if value, text = 'yes'; else, text = 'no'; end
end
