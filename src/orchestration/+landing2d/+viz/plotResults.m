function figures = plotResults(results,cfg,options)
% PLOTRESULTS  Figures of relational_policy_v1 (every number read from RESULTS).
%   figures = landing2d.viz.plotResults(results,cfg,struct('outputDir',dir,'visible',false))
%   contrasts       seed-paired key contrasts (TOSM - PPO, TOSM - Shuffled, ...)
%   learning        validation landing rate vs environment steps; steps to
%                   target and area under the curve
%   heldout         training-distribution test per motion x observation cell
%   factorial       S1-S4 outcomes, paired effects and interaction
%   trajectories    S1-S4 paths of the display training seed
%   generalization  outside the training ranges vs the in-distribution test
%   probes          open-loop velocity sensitivity and stale-update response
% Bars = mean over training seeds, whiskers = 95% t interval over seeds (none
% with one seed: one run gives no between-run variation).
if nargin < 3, options = struct(); end
if ~isfield(options,'outputDir'), options.outputDir = ''; end
if ~isfield(options,'visible'), options.visible = false; end
visible = 'off'; if options.visible, visible = 'on'; end
registry = landing2d.config.methodRegistry();
methods = registry.methods(ismember({registry.methods.id},results.methods));
figures = struct();
headline = landing2d.evaluation.headlineContrasts(results);
if ~isempty(headline), figures.contrasts = contrastFigure(headline,methods,visible); end
if isfield(results,'learning'), figures.learning = learningFigure(results.learning,methods,visible); end
if isfield(results,'heldout'), figures.heldout = heldOutFigure(results.heldout,methods,visible); end
if isfield(results,'factorial')
    figures.factorial = factorialFigure(results.factorial,methods,visible);
    if ~isempty(results.factorial.display)
        figures.trajectories = landing2d.viz.plotTrajectories(results.factorial,cfg,options.visible);
    end
end
if isfield(results,'generalization')
    reference = [];
    if isfield(results,'heldout'), reference = results.heldout.summary; end
    figures.generalization = generalizationFigure(results.generalization,reference,methods,visible);
end
if isfield(results,'probes'), figures.probes = probeFigure(results.probes,methods,visible); end
if ~isempty(options.outputDir)
    folder = char(options.outputDir);
    if ~exist(folder,'dir'), mkdir(folder); end
    names = fieldnames(figures);
    for i = 1:numel(names)
        exportgraphics(figures.(names{i}),fullfile(folder,['fig_',names{i},'.png']), ...
            'Resolution',200);
    end
    fprintf('Figures: %s\n',folder);
end
end

% ------------------------------------------------------------------ figures
function fig = contrastFigure(T,methods,visible)
fig = figure('Name','Key contrasts','Color','w','Visible',visible,'Position',[60 60 1100 520]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
quantities = unique(T.Quantity,'stable'); contrasts = unique(T.Contrast,'stable');
offsets = linspace(-0.25,0.25,numel(contrasts));
colors = lines(numel(contrasts));
for j = 1:numel(contrasts)
    for i = 1:numel(quantities)
        row = T(T.Quantity==quantities(i) & T.Contrast==contrasts(j),:);
        if isempty(row), continue; end
        y = numel(quantities)-i+1+offsets(j);
        scale = max(abs(T.Delta(T.Quantity==quantities(i)))+ ...
            fillNaN(T.CI(T.Quantity==quantities(i))));
        scale = max(scale,eps);
        ci = fillNaN(row.CI);
        plot(ax,[row.Delta-ci,row.Delta+ci]/scale,[y,y],'-','Color',colors(j,:), ...
            'LineWidth',1.5,'HandleVisibility','off');
        h = plot(ax,row.Delta/scale,y,'o','MarkerFaceColor',colors(j,:), ...
            'Color',colors(j,:),'DisplayName',char(contrasts(j)));
        if i>1, h.HandleVisibility = 'off'; end
        text(ax,1.05,y,sprintf('%+.3g \\pm %.2g (n=%d, A>B %d)',row.Delta,ci, ...
            row.Seeds,row.Positive),'FontSize',7,'Color',colors(j,:));
    end
end
xline(ax,0,'k-','HandleVisibility','off');
set(ax,'YTick',1:numel(quantities),'YTickLabel',flipud(cellstr(quantities)),'XLim',[-1.1,1.9]);
xlabel(ax,'difference A - B, scaled per row (mean \pm 95% t interval over training seeds)');
title(ax,{'Seed-paired method contrasts','(intervals crossing 0 = no evidence of a difference)'});
legend(ax,'Location','southoutside','Orientation','horizontal','Interpreter','none');
end

function fig = learningFigure(L,methods,visible)
fig = figure('Name','Learning efficiency','Color','w','Visible',visible,'Position',[60 60 1400 420]);
t = tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
title(t,'Learning efficiency (validation split, same budget and loss for every method)');
ax = nexttile(t); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for m = 1:numel(methods)
    C = L.curves(L.curves.MethodId==methods(m).id,:);
    if isempty(C), continue; end
    g = findgroups(C.Iteration);
    x = splitapply(@mean,C.EnvironmentSteps,g); y = splitapply(@mean,C.ValidationSuccess,g);
    lo = splitapply(@min,C.ValidationSuccess,g); hi = splitapply(@max,C.ValidationSuccess,g);
    fill(ax,[x;flipud(x)],[lo;flipud(hi)],methods(m).color,'FaceAlpha',0.12, ...
        'EdgeColor','none','HandleVisibility','off');
    plot(ax,x,y,methods(m).lineStyle,'Color',methods(m).color,'LineWidth',1.6, ...
        'DisplayName',sprintf('%s (%d seeds)',methods(m).label,numel(unique(C.TrainSeed))));
end
for p = L.targets, yline(ax,p,':','Color',[.4 .4 .4],'HandleVisibility','off'); end
xlabel(ax,'environment steps (decisions)'); ylabel(ax,'validation landing rate');
title(ax,'mean over seeds, band = min-max'); legend(ax,'Location','southeast');
ylim(ax,[0,1]);
ax = nexttile(t);
names = arrayfun(@(p)sprintf('StepsTo%02d',round(100*p)),L.targets,'UniformOutput',false);
methodBars(ax,L.summary,names,methods,'environment steps');
title(ax,'steps to first reach the target (censored at the budget)');
set(ax,'XTickLabel',arrayfun(@(p)sprintf('%.0f%%',100*p),L.targets,'UniformOutput',false));
reached = arrayfun(@(p)sprintf('Reached%02d',round(100*p)),L.targets,'UniformOutput',false);
annotateReached(ax,L.summary,reached,methods);
ax = nexttile(t);
methodBars(ax,L.summary,{'AUC','BestValidationSuccess'},methods,'rate');
set(ax,'XTickLabel',{'AUC / budget','best validation'}); ylim(ax,[0,1]);
title(ax,'area under the learning curve');
end

function fig = heldOutFigure(H,methods,visible)
fig = figure('Name','Held-out test','Color','w','Visible',visible,'Position',[60 60 1500 430]);
t = tiledlayout(fig,1,4,'TileSpacing','compact','Padding','compact');
title(t,'Held-out test of the training distribution (test split) per motion x observation cell');
cells = ["all","CV-clean","CV-dropout","CA-clean","CA-dropout"];
spec = {'Success','success rate';'AimErrorRMS_m','aim-error RMS [m]'; ...
    'RelativeSpeedRMS_mps','relative-speed RMS [m/s]';'CommandRateRMS_mps3','command-rate RMS [m/s^3]'};
for k = 1:size(spec,1)
    ax = nexttile(t);
    cellBars(ax,H.summary,'Cell',cells,spec{k,1},methods);
    ylabel(ax,spec{k,2}); title(ax,spec{k,2});
    if k==1, ylim(ax,[0,1.05]); legend(ax,{methods.label},'Location','southoutside'); end
end
end

function fig = factorialFigure(F,methods,visible)
fig = figure('Name','Factorial S1-S4','Color','w','Visible',visible,'Position',[60 60 1500 760]);
t = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
title(t,{'Controlled 2 x 2 cases: UGV motion (CV/CA) x marker observation (clean/dropout)', ...
    'effects are replicate-paired (same seed and window); Interaction = S4 - S3 - S2 + S1'});
ax = nexttile(t); cellBars(ax,F.caseSummary,'Case',["S1","S2","S3","S4"],'Success',methods);
ylim(ax,[0,1.05]); title(ax,'success per case'); ylabel(ax,'rate');
set(ax,'XTickLabel',{'S1 CV+clean','S2 CV+drop','S3 CA+clean','S4 CA+drop'});
legend(ax,{methods.label},'Location','southoutside');
effects = ["Dropout|CV","Dropout|CA","Motion|clean","Motion|dropout","Interaction"];
spec = {'WindowAimErrorRMS_m','\Delta window aim-error RMS [m]'; ...
    'WindowRelativeSpeedRMS_mps','\Delta window relative-speed RMS [m/s]'; ...
    'WindowCommandRateRMS_mps3','\Delta window command-rate RMS [m/s^3]'; ...
    'Failure','\Delta failure rate';'UnsuitableDescent_s','\Delta unsuitable descent [s]'};
for k = 1:size(spec,1)
    ax = nexttile(t); cellBars(ax,F.effectSummary,'Effect',effects,spec{k,1},methods);
    yline(ax,0,'k-'); ylabel(ax,spec{k,2}); title(ax,spec{k,2});
end
end

function fig = generalizationFigure(G,reference,methods,visible)
fig = figure('Name','Generalization','Color','w','Visible',visible,'Position',[60 60 1400 430]);
t = tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
title(t,'Outside the training ranges (stress split) vs the in-distribution test');
S = G.summary;
if ~isempty(reference)
    R = reference(reference.Cell=="all",:);
    R.Condition = repmat("in-distribution",height(R),1);
    keep = intersect(S.Properties.VariableNames,R.Properties.VariableNames,'stable');
    S = [R(:,keep);S(:,keep)];
end
conditions = unique(S.Condition,'stable');
spec = {'Success','success rate';'AimErrorRMS_m','aim-error RMS [m]';'CommandRateRMS_mps3', ...
    'command-rate RMS [m/s^3]'};
for k = 1:size(spec,1)
    ax = nexttile(t); cellBars(ax,S,'Condition',conditions,spec{k,1},methods);
    ylabel(ax,spec{k,2}); title(ax,spec{k,2});
    if k==1, ylim(ax,[0,1.05]); legend(ax,{methods.label},'Location','southoutside'); end
end
end

function fig = probeFigure(P,methods,visible)
fig = figure('Name','Open-loop probes','Color','w','Visible',visible,'Position',[60 60 1500 430]);
t = tiledlayout(fig,1,4,'TileSpacing','compact','Padding','compact');
title(t,{'Open-loop probes: every policy sees identical observations', ...
    sprintf('velocity contrast \\pm%.1f m/s on the UGV velocity estimate; update contrast: last %.1f s of marker frames dropped', ...
    P.meta.velocityDelta,P.meta.staleAge)});
ref = P.velocitySummary(P.velocitySummary.MethodId=="reference_driver",:);
ax = nexttile(t); methodBars(ax,P.velocitySummary,{'SensitivityX'},methods,'da_x / dv_r [1/s]');
if ~isempty(ref), yline(ax,ref.SensitivityX,'k--','reference driver'); end
title(ax,'relative-velocity sensitivity (expected > 0)'); set(ax,'XTickLabel',{''});
ax = nexttile(t); methodBars(ax,P.velocitySummary,{'PositiveSensitivity'},methods,'fraction');
ylim(ax,[0,1.05]); title(ax,'probes with the expected sign'); set(ax,'XTickLabel',{''});
ax = nexttile(t); methodBars(ax,P.updateSummary,{'AbsDeltaAx','AbsDeltaAz'},methods,'|response change| [m/s^2]');
set(ax,'XTickLabel',{'a_x','a_z'}); title(ax,'response to a stale marker update');
legend(ax,{methods.label},'Location','southoutside');
ref = P.updateSummary(P.updateSummary.MethodId=="reference_driver",:);
if ~isempty(ref)
    subtitle(ax,sprintf('estimate-error change %.3f m, %.3f m/s; reference driver |da_x| %.3f', ...
        ref.EstimateShift_m,ref.EstimateShiftV_mps,ref.AbsDeltaAx),'FontSize',7);
end
ax = nexttile(t);
graph = methods(~strcmp({methods.id},'ppo'));
methodBars(ax,P.updateSummary,{'AttentionShift'},graph,'mean |\Delta\alpha|');
set(ax,'XTickLabel',{''}); title(ax,{'attention change on VisionQuality edges','(descriptive, not importance)'});
legend(ax,{graph.label},'Location','southoutside');
end

% ------------------------------------------------------------------ helpers
function cellBars(ax,S,key,categories,metric,methods)
% Grouped bars: categories on x, one bar per method, seed interval whiskers.
hold(ax,'on'); grid(ax,'on'); box(ax,'on');
value = nan(numel(categories),numel(methods)); ci = value;
for g = 1:numel(categories)
    for m = 1:numel(methods)
        row = S(string(S.(key))==categories(g) & S.MethodId==methods(m).id,:);
        if isempty(row), continue; end
        value(g,m) = row.(metric); ci(g,m) = row.([metric,'_ci']);
    end
end
drawBars(ax,value,ci,methods);
set(ax,'XTick',1:numel(categories),'XTickLabel',cellstr(categories),'XTickLabelRotation',20);
end

function methodBars(ax,S,metrics,methods,yLabel)
hold(ax,'on'); grid(ax,'on'); box(ax,'on');
value = nan(numel(metrics),numel(methods)); ci = value;
for k = 1:numel(metrics)
    for m = 1:numel(methods)
        row = S(S.MethodId==methods(m).id,:);
        if isempty(row), continue; end
        value(k,m) = row.(metrics{k}); ci(k,m) = row.([metrics{k},'_ci']);
    end
end
drawBars(ax,value,ci,methods);
set(ax,'XTick',1:numel(metrics),'XTickLabel',metrics);
ylabel(ax,yLabel);
end

function drawBars(ax,value,ci,methods)
if all(isnan(value(:)))
    text(ax,0.5,0.5,'no data','Units','normalized','HorizontalAlignment','center');
    return;
end
single = size(value,1)==1;
if single
    % One category: a padding NaN row keeps one bar series per method.
    value = [value;nan(1,size(value,2))]; ci = [ci;nan(1,size(ci,2))];
end
b = bar(ax,value,'grouped');
if single, xlim(ax,[0.5,1.5]); end
for m = 1:numel(b)
    b(m).FaceColor = methods(m).color; b(m).EdgeColor = 'none';
    x = b(m).XEndPoints; ok = isfinite(value(:,m)) & isfinite(ci(:,m));
    errorbar(ax,x(ok),value(ok,m),ci(ok,m),'k.','LineWidth',0.8,'HandleVisibility','off');
end
end

function annotateReached(ax,S,reached,methods)
for k = 1:numel(reached)
    for m = 1:numel(methods)
        row = S(S.MethodId==methods(m).id,:);
        if isempty(row), continue; end
        text(ax,k+(m-(numel(methods)+1)/2)*0.8/numel(methods),0, ...
            sprintf('%.0f/%d',row.(reached{k})*row.Seeds,row.Seeds), ...
            'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',7);
    end
end
end

function x = fillNaN(x)
x(~isfinite(x)) = 0;
end
