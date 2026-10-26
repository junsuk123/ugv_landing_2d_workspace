function files = plots(A,d,folder)
% PLOTS Paired k = 2 - k = 1 differences per protocol-v2 cell (one figure, three panels).
% Black: seed-block mean +/- 95% t interval (df = 4, the unit of the criteria).
% Colored: method means over the five training seeds with their own interval,
% offset horizontally; validated categorical slots of bias_diagnostics.plots
% with marker shapes, so color never carries the identity alone.
style = struct('ids',{d.methods},'labels',{{'PPO','Residual-MLP','TOSM','Shuffled'}}, ...
    'colors',[0.165 0.471 0.839;0 0.514 0;0.910 0.482 0.643;0.929 0.631 0], ...
    'markers',{{'o','d','s','^'}},'ink',[0.32 0.32 0.31],'grid',[0.88 0.88 0.87]);
cellNames = strcat(string(d.cells(:,1)),"/",string(d.cells(:,2)));
spec = {'dS','\Delta landing rate [%p]';'dU','\Delta unsafe contact [%p]';'dE','\Delta aim error RMS [m]'};
f = figure('Visible','off','Name','control gain audit','Color','w','Position',[50 50 1500 1050]);
layout = tiledlayout(f,3,1,'TileSpacing','compact','Padding','compact');
axesList = gobjects(1,3);
for p = 1:3
    ax = nexttile(layout); axesList(p) = ax; hold(ax,'on'); m = spec{p,1};
    for c = 1:numel(cellNames)
        fac = string(d.cells{c,1}); sh = string(d.cells{c,2});
        row = A.cells(A.cells.Factor==fac & A.cells.Shift==sh,:);
        errorbar(ax,c,row.([m,'_mean']),row.([m,'_mean'])-row.([m,'_low']), ...
            row.([m,'_high'])-row.([m,'_mean']),'_','Color','k','LineWidth',2,'MarkerSize',18, ...
            'CapSize',10,'HandleVisibility','off');
        for k = 1:numel(style.ids)
            r = A.byMethod(A.byMethod.MethodId==style.ids{k} & A.byMethod.Factor==fac ...
                & A.byMethod.Shift==sh,:);
            x = c+0.12*(k-2.5);
            errorbar(ax,x,r.([m,'_mean']),r.([m,'_mean'])-r.([m,'_low']),r.([m,'_high'])-r.([m,'_mean']), ...
                style.markers{k},'Color',style.colors(k,:),'MarkerFaceColor',style.colors(k,:), ...
                'MarkerEdgeColor','w','MarkerSize',8,'LineWidth',1.2,'CapSize',4,'HandleVisibility','off');
        end
    end
    yline(ax,0,'-','Color',style.ink,'HandleVisibility','off');
    set(ax,'XTick',1:numel(cellNames),'XTickLabel',cellstr(cellNames),'TickLabelInterpreter','none');
    xlim(ax,[0.5 numel(cellNames)+0.5]); grid(ax,'on'); ax.GridColor = style.grid;
    ax.XColor = style.ink; ax.YColor = style.ink; ylabel(ax,spec{p,2});
end
trainSeeds = unique(A.bySeed.TrainSeed); environments = numel(unique(A.pairs.EpisodeSeed));
title(layout,sprintf(['a_x gain k = 2 vs k = 1, frozen v5 seeds %d-%d x %d environments ' ...
    '(black: seed-block mean, 95%% t, df = %d). Verdict: %s'],min(trainSeeds),max(trainSeeds), ...
    environments,numel(trainSeeds)-1,strrep(A.verdict,'_',' ')),'Color',style.ink,'FontSize',12);
ax = axesList(1); h = gobjects(1,numel(style.ids)+1);
for k = 1:numel(style.ids)
    h(k) = plot(ax,NaN,NaN,style.markers{k},'Color',style.colors(k,:),'MarkerFaceColor', ...
        style.colors(k,:),'MarkerEdgeColor','w','MarkerSize',8);
end
h(end) = plot(ax,NaN,NaN,'_','Color','k','MarkerSize',18,'LineWidth',2);
lg = legend(ax,h,[style.labels,{'Seed block (4 methods)'}],'Box','off','TextColor',style.ink);
lg.Layout.Tile = 'east';
files = string(fullfile(folder,'gain_audit_deltas.png'));
exportgraphics(f,files,'Resolution',150); close(f);
end
