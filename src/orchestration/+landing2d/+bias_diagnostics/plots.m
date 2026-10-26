function files = plots(T,d,folder)
% PLOTS Comparison figures of inductive_bias_diagnostics_v1 (seed points, mean +/- 95% t interval).
% Method colors use the validated categorical slots blue, green, magenta, yellow
% (all-pair CVD dE 13.0, normal dE 19.6); marker shapes repeat the identity, so
% color never carries it alone. One y-scale per panel.
style = struct('ids',{d.methods},'labels',{{'PPO','Residual-MLP','TOSM','Shuffled'}}, ...
    'colors',[0.165 0.471 0.839;0 0.514 0;0.910 0.482 0.643;0.929 0.631 0], ...
    'markers',{{'o','d','s','^'}},'ink',[0.32 0.32 0.31],'grid',[0.88 0.88 0.87]);
files = strings(0);
files(end+1) = figureQ1(T,style,folder);
files(end+1) = figureQ2(T,style,folder);
files(end+1) = figureQ3(T,style,folder);
files(end+1) = figureQ4(T,style,folder);
files(end+1) = figureP6(T,style,folder);
end

function file = figureQ1(T,style,folder)
f = newFigure('Q1 state similarity',[1500 470]);
B = T.q1_state_similarity__by_seed; classes = ["freshUpdate","staleEstimate","fovBoundary","outOfView","nearContact","all"];
for k = 1:2
    family = ["training","motion_v2"]; ax = subplot(1,3,k); hold(ax,'on');
    dots(ax,B(B.Family==family(k),:),'Class',classes,'NormSensitivity',style);
    title(ax,"Normalized action sensitivity ("+family(k)+" states)",'Interpreter','none');
    ylabel(ax,'||J diag(s_o)||_F (normalized action)');
end
ax = subplot(1,3,3); hold(ax,'on');
scatterLink(ax,T.q1_state_similarity__performance_link,'NormSensitivity','MotionOODSuccess',style);
xlabel(ax,'Normalized sensitivity (motion-v2 states)'); ylabel(ax,'v2 motion-OOD landing rate');
title(ax,'Sensitivity vs motion-OOD landing (one point per model)');
legendFor(ax,style); file = saveFigure(f,folder,'q1_state_similarity');
end

function file = figureQ2(T,style,folder)
f = newFigure('Q2 state-dependent action',[1500 900]);
B = T.q2_state_dependent_action__by_seed;
spec = {'RugvX','ReferenceRugvX','(m/s^2)/(m/s)','a_x response to UGV velocity (dashed: reference driver)'; ...
    'RdroneX','ReferenceRdroneX','(m/s^2)/(m/s)','a_x response to own velocity (dashed: reference driver)'; ...
    'RposX','ReferenceRposX','(m/s^2)/m','a_x response to UGV position (dashed: reference driver)'};
for k = 1:3
    ax = subplot(2,2,k); hold(ax,'on');
    dots(ax,B,'Family',["training","motion_v2"],spec{k,1},style);
    reference = splitapply(@mean,B.(spec{k,2}),findgroups(B.Family));
    families = unique(B.Family);
    for j = 1:numel(families)
        x = find(["training","motion_v2"]==families(j));
        plot(ax,x+[-0.4 0.4],reference(j)*[1 1],'--','Color',style.ink,'LineWidth',1.5);
    end
    yline(ax,0,'-','Color',style.grid*0.8);
    ylabel(ax,spec{k,3}); title(ax,spec{k,4});
end
ax = subplot(2,2,4); hold(ax,'on');
dots(ax,T.q2_state_dependent_action__branch_by_seed,'Point', ...
    ["accelerationStart","accelerationMiddle","afterAcceleration"],'PolicyBestReturn',style);
ylim(ax,[0 1]); ylabel(ax,'Share of branch points where the own action is best');
title(ax,'Snapshot branches: own action vs a_x \pm 0.25 (return-to-go)');
legendFor(ax,style); file = saveFigure(f,folder,'q2_state_dependent_action');
end

function file = figureQ3(T,style,folder)
f = newFigure('Q3 reward density',[1500 900]);
C = T.q3_reward_density__pooled_composition; phases = ["tracking","acceleration","dropout","contact"];
names = ["goal","view","control","readiness","shaping","terminal"];
magnitudes = arrayfun(@(n)C.(n+"AbsPerStep"),names,'UniformOutput',false); magnitudes = [magnitudes{:}]; magnitudes = magnitudes(:);
limits = [10^floor(log10(min(magnitudes(magnitudes>0)))),10^(ceil(log10(max(magnitudes)))+2)];
for k = 1:4
    ax = subplot(2,2,k); hold(ax,'on'); row = C(C.Phase==phases(k),:);
    if isempty(row), axis(ax,'off'); continue; end
    v = arrayfun(@(n)row.(n+"AbsPerStep"),names); share = arrayfun(@(n)row.(n+"Share"),names);
    nz = arrayfun(@(n)row.(n+"Nonzero"),names);
    barh(ax,1:6,max(v,limits(1)),0.6,'FaceColor',style.colors(1,:),'EdgeColor','none');
    for j = 1:6
        text(ax,max(v(j),limits(1))*1.3,j,sprintf('%.1f%% of |r|, nonzero in %.2f%% of decisions', ...
            100*share(j),100*nz(j)),'Color',style.ink,'FontSize',9);
    end
    set(ax,'YTick',1:6,'YTickLabel',names,'XScale','log','YDir','reverse','XLim',limits);
    xlabel(ax,'mean |term| per decision (log scale; pooled over 20 models)');
    title(ax,sprintf('%s (%d decisions)',phases(k),row.Steps));
    grid(ax,'on'); ax.GridColor = style.grid; ax.XColor = style.ink; ax.YColor = style.ink;
end
file = saveFigure(f,folder,'q3_reward_density');
end

function file = figureQ4(T,style,folder)
f = newFigure('Q4 action topology',[1500 900]);
A = T.q4_action_topology__by_seed; phases = ["tracking","acceleration","dropout","contact"];
ax = subplot(2,2,1); hold(ax,'on'); dots(ax,A,'Phase',phases,'SaturationX',style);
ylabel(ax,'Share of decisions with |tanh(\mu_x)| > 0.95'); title(ax,'Horizontal action saturation');
ax = subplot(2,2,2); hold(ax,'on'); dots(ax,A,'Phase',phases,'CommandRateRmsX',style);
ylabel(ax,'RMS of \Delta a_x / \Delta t [m/s^3]'); title(ax,'Horizontal command rate');
ax = subplot(2,2,3); hold(ax,'on');
dots(ax,T.q4_action_topology__probe_by_seed,'Family',["training","motion_v2"],'KLNoise',style);
ylabel(ax,'KL(\pi(.|o_{noise}) || \pi(.|o)) [nats]'); title(ax,'Policy change under sensing-noise replicates');
ax = subplot(2,2,4); hold(ax,'on');
scatterLink(ax,T.q4_action_topology__performance_link,'CommandRateRmsX','MotionOODSuccess',style);
xlabel(ax,'Command-rate RMS in v2 motion OOD [m/s^3]'); ylabel(ax,'v2 motion-OOD landing rate');
title(ax,'Smoothness vs motion-OOD landing (one point per model)');
legendFor(ax,style); file = saveFigure(f,folder,'q4_action_topology');
end

function file = figureP6(T,style,folder)
f = newFigure('P6 relation effect',[1500 900]);
C = T.p6_relation_effect__correction_off_by_seed;
ax = subplot(2,2,1); hold(ax,'on'); first = ax; dots(ax,C,'Family',["training","motion_v2"],'CorrectionOff',style);
ylabel(ax,'||a - a_{correction off}|| [m/s^2]'); title(ax,'Open loop: removing the trained correction');
A = T.p6_relation_effect__correction_off_closed_loop;
ax = subplot(2,2,2); hold(ax,'on'); dots(ax,A,'Factor',["motion","noise","dropout"],'SuccessChangeOff',style);
yline(ax,0,'-','Color',style.grid*0.8);
ylabel(ax,'\Delta landing rate (correction off - on)'); title(ax,'Closed loop (v2 OOD, 100 episodes per model)');
S = T.p6_relation_effect__typing_swap_by_seed; S.All = repmat("motion OOD",height(S),1);
ax = subplot(2,2,3); hold(ax,'on'); dots(ax,S,'All',"motion OOD",'SuccessChange',style);
yline(ax,0,'-','Color',style.grid*0.8);
ylabel(ax,'\Delta landing rate (partner typing - own)'); title(ax,'Trained graph actors with the other typing');
D = T.p6_relation_effect__decomposition_summary;
keep = D(ismember(D.Component,["structure","typing"]),:);
ax = subplot(2,2,4); hold(ax,'on');
labels = keep.Component+" | "+keep.Metric;
errorbar(ax,keep.Mean,1:height(keep),keep.Mean-keep.CI95Low,keep.CI95High-keep.Mean,'horizontal', ...
    'o','Color',style.ink,'MarkerFaceColor',style.ink,'MarkerSize',8,'LineWidth',1.5);
xline(ax,0,'-','Color',style.grid*0.8);
set(ax,'YTick',1:height(keep),'YTickLabel',labels,'YDir','reverse','TickLabelInterpreter','none');
xlabel(ax,'Seed-paired difference (mean, 95% t interval)');
title(ax,'Seed-paired: structure = Shuffled - MLP, typing = TOSM - Shuffled');
grid(ax,'on'); ax.GridColor = style.grid;
legendFor(first,style); file = saveFigure(f,folder,'p6_relation_effect');
end

function dots(ax,B,groupVar,levels,metric,style)
% Seed values (small open markers) and method mean +/- 95% t interval over seeds.
offsets = linspace(-0.27,0.27,numel(style.ids));
for g = 1:numel(levels)
    for m = 1:numel(style.ids)
        v = B.(metric)(B.(groupVar)==levels(g) & B.MethodId==style.ids{m});
        v = v(isfinite(v)); if isempty(v), continue; end
        x = g+offsets(m);
        plot(ax,x+zeros(size(v)),v,style.markers{m},'Color',style.colors(m,:),'MarkerSize',5, ...
            'LineWidth',0.75,'HandleVisibility','off');
        hw = 0;
        if numel(v)>=2
            q = betaincinv(0.05,(numel(v)-1)/2,0.5); hw = sqrt((numel(v)-1)*(1-q)/q)*std(v)/sqrt(numel(v));
        end
        errorbar(ax,x,mean(v),hw,style.markers{m},'Color',style.colors(m,:),'MarkerFaceColor', ...
            style.colors(m,:),'MarkerEdgeColor','w','MarkerSize',9,'LineWidth',1.5,'CapSize',6, ...
            'HandleVisibility','off');
    end
end
set(ax,'XTick',1:numel(levels),'XTickLabel',cellstr(levels),'TickLabelInterpreter','none');
xlim(ax,[0.5 numel(levels)+0.5]); grid(ax,'on'); ax.GridColor = style.grid; ax.XColor = style.ink; ax.YColor = style.ink;
end

function scatterLink(ax,L,x,y,style)
for m = 1:numel(style.ids)
    rows = L.MethodId==style.ids{m};
    plot(ax,L.(x)(rows),L.(y)(rows),style.markers{m},'Color',style.colors(m,:), ...
        'MarkerFaceColor',style.colors(m,:),'MarkerEdgeColor','w','MarkerSize',9,'HandleVisibility','off');
end
rho = landing2d.bias_diagnostics.spearman(L.(x),L.(y));
text(ax,0.03,0.06,sprintf('Spearman \\rho = %.2f (20 models, descriptive)',rho),'Units','normalized','Color',style.ink);
grid(ax,'on'); ax.GridColor = style.grid; ax.XColor = style.ink; ax.YColor = style.ink;
end

function legendFor(ax,style)
hold(ax,'on'); h = gobjects(1,numel(style.ids));
for m = 1:numel(style.ids)
    h(m) = plot(ax,NaN,NaN,style.markers{m},'Color',style.colors(m,:),'MarkerFaceColor',style.colors(m,:), ...
        'MarkerEdgeColor','w','MarkerSize',9);
end
legend(ax,h,style.labels,'Location','eastoutside','Box','off','TextColor',style.ink);
end

function f = newFigure(name,sizePx)
f = figure('Visible','off','Name',name,'Color','w','Position',[50 50 sizePx]);
end

function file = saveFigure(f,folder,name)
file = string(fullfile(folder,[name,'.png']));
exportgraphics(f,file,'Resolution',150); close(f);
end
