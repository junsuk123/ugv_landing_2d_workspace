function fig = plotMonteCarloComparison(monteCarlo,c)
% PLOTMONTECARLOCOMPARISON  Mean +/- one-standard-deviation trajectories.
fields = fieldnames(monteCarlo);
fields = fields(~cellfun(@(key)isempty(monteCarlo.(key)),fields));
if isempty(fields)
    fig = gobjects(0);
    return;
end
nCases = numel(monteCarlo.(fields{1}));
colors = lines(max(numel(fields),3));
visibility = 'on';
if ~c.figureVisible, visibility = 'off'; end
fig = figure('Name','Monte Carlo mean and variance trajectories', ...
    'NumberTitle','off','Position',[80,80,1450,720], ...
    'Color','w','Visible',visibility);
group = uitabgroup(fig,'Units','normalized','Position',[0,0,1,1]);
tabs = gobjects(nCases,1);
layouts = gobjects(nCases,1);
for j = 1:nCases
    tabs(j) = uitab(group,'Title',sprintf('Scenario %d',j), ...
        'BackgroundColor','w');
    layouts(j) = tiledlayout(tabs(j),1,2,'TileSpacing','compact', ...
        'Padding','compact');
    axX = nexttile(layouts(j));
    axZ = nexttile(layouts(j));
    landing2d.viz.prepareAxes(axX);
    landing2d.viz.prepareAxes(axZ);
    handles = gobjects(numel(fields),1);
    labels = cell(numel(fields),1);
    for i = 1:numel(fields)
        item = monteCarlo.(fields{i})(j);
        t = item.time(:);
        sx = sqrt(max(item.varX(:),0));
        sz = sqrt(max(item.varZ(:),0));
        band(axX,t,item.meanX(:),sx,colors(i,:));
        band(axZ,t,item.meanZ(:),sz,colors(i,:));
        handles(i) = plot(axX,t,item.meanX,'Color',colors(i,:), ...
            'LineWidth',1.9);
        plot(axZ,t,item.meanZ,'Color',colors(i,:),'LineWidth',1.9, ...
            'HandleVisibility','off');
        labels{i} = item.label;
    end
    title(axX,'Horizontal trajectory: mean +/- 1 sigma');
    xlabel(axX,'Time [s]'); ylabel(axX,'x [m]');
    title(axZ,'Altitude trajectory: mean +/- 1 sigma');
    xlabel(axZ,'Time [s]'); ylabel(axZ,'z [m]');
    legend(axX,handles,labels,'Location','best','Box','off');
    title(layouts(j),sprintf(['Scenario %d Monte Carlo (%d samples/arm) | ' ...
        'bands show trajectory variance only'],j,item.nRuns), ...
        'Interpreter','none');
end
group.SelectedTab = tabs(1);
if c.saveResults
    names = arrayfun(@(j)sprintf('scenario_%d_monte_carlo',j), ...
        1:nCases,'UniformOutput',false);
    landing2d.io.saveTabbedFigure(fig,tabs,layouts,c,names, ...
        'monte_carlo_tabs');
end
end

function band(ax,t,mu,sigma,color)
fill(ax,[t;flipud(t)],[mu-sigma;flipud(mu+sigma)],color, ...
    'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
end
