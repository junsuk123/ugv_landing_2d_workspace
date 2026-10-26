function files = plots(A,d,folder)
% PLOTS Horizontal response gains at the motion_v2 reference states, v5 versus R1.
% Top: per-method means over the five seeds (hollow v5, filled R1) with 95%
% t intervals; dashed: the reference driver. Bottom: paired R1 - v5, method
% means (95%) and the seed-block mean with the Bonferroni interval (black).
% Validated categorical slots and marker shapes of bias_diagnostics.plots.
style = struct('ids',{d.methods},'labels',{{'PPO','Residual-MLP','TOSM','Shuffled'}}, ...
    'colors',[0.165 0.471 0.839;0 0.514 0;0.910 0.482 0.643;0.929 0.631 0], ...
    'markers',{{'o','d','s','^'}},'ink',[0.32 0.32 0.31],'grid',[0.88 0.88 0.87]);
labels = {'a_x / UGV velocity [(m/s^2)/(m/s)]','a_x / UGV position [(m/s^2)/m]','-a_x / own velocity [(m/s^2)/(m/s)]'};
refs = {'ReferenceRugvX','ReferenceRposX','ReferenceRdroneX'};
M = A.byModel(A.byModel.Family==d.primaryFamily,:);
f = figure('Visible','off','Name','response gain r1','Color','w','Position',[50 50 1500 900]);
layout = tiledlayout(f,2,3,'TileSpacing','compact','Padding','compact');
for k = 1:3
    m = d.primary{k};
    ax = nexttile(layout,k); hold(ax,'on');
    for j = 1:numel(style.ids)
        rows = M.MethodId==style.ids{j};
        for s = 1:2
            v = M.([m,ifelse(s==1,'_v5','_r1')])(rows); x = j+0.18*(2*s-3);
            face = ifelse(s==1,'w',style.colors(j,:));
            errorbar(ax,x,mean(v),ci(v),style.markers{j},'Color',style.colors(j,:), ...
                'MarkerFaceColor',face,'MarkerSize',8,'LineWidth',1.2,'CapSize',4);
        end
    end
    reference = mean(M.([refs{k},'_v5']));
    if strcmp(m,'RdroneXNeg'), reference = -reference; end
    yline(ax,reference,'--','Color',style.ink); yline(ax,0,'-','Color',style.grid*0.8);
    set(ax,'XTick',1:4,'XTickLabel',style.labels); xlim(ax,[0.5 4.5]); grid(ax,'on');
    ax.GridColor = style.grid; ax.XColor = style.ink; ax.YColor = style.ink;
    title(ax,labels{k},'Color',style.ink,'FontWeight','normal');
    if k==1, ylabel(ax,'Response (hollow v5, filled R1; dashed reference)'); end
    ax = nexttile(layout,3+k); hold(ax,'on');
    for j = 1:numel(style.ids)
        v = M.(['d',m])(M.MethodId==style.ids{j});
        errorbar(ax,j,mean(v),ci(v),style.markers{j},'Color',style.colors(j,:), ...
            'MarkerFaceColor',style.colors(j,:),'MarkerEdgeColor','w','MarkerSize',8,'LineWidth',1.2,'CapSize',4);
    end
    row = A.verdicts(A.verdicts.Metric==string(m),:);
    errorbar(ax,5,row.Mean,row.Mean-row.BonferroniLow,row.BonferroniHigh-row.Mean,'_','Color','k', ...
        'LineWidth',2,'MarkerSize',18,'CapSize',10);
    yline(ax,0,'-','Color',style.ink);
    set(ax,'XTick',1:5,'XTickLabel',[style.labels,{'Seed block'}]); xlim(ax,[0.5 5.5]); grid(ax,'on');
    ax.GridColor = style.grid; ax.XColor = style.ink; ax.YColor = style.ink;
    title(ax,char(row.Label),'Color',style.ink,'FontWeight','normal');
    if k==1, ylabel(ax,'R1 - v5 (black: Bonferroni 98.3%)'); end
end
title(layout,sprintf(['Horizontal response at %d motion\\_v2 reference states: training a2 %s (R1) vs %s (v5), ' ...
    'seeds %d-%d'],max(A.byModel.States_v5(A.byModel.Family==d.primaryFamily)), ...
    mat2str(d.r1.c.experiment.scenario.a2Range),mat2str(d.r1.v5.experiment.scenario.a2Range), ...
    min(M.TrainSeed),max(M.TrainSeed)),'Color',style.ink,'FontSize',12);
files = string(fullfile(folder,'response_gain_r1.png'));
exportgraphics(f,files,'Resolution',150); close(f);
end

function h = ci(v)
h = NaN;
if numel(v)>=2
    q = betaincinv(0.05,(numel(v)-1)/2,0.5); h = sqrt((numel(v)-1)*(1-q)/q)*std(v)/sqrt(numel(v));
end
end

function v = ifelse(condition,a,b)
if condition
    v = a;
else
    v = b;
end
end
