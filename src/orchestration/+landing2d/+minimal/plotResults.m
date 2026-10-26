function figures = plotResults(results,c,visible,folder)
% PLOTRESULTS Generalization performance first; no numerical bias score.
if visible, visibility = 'on'; else, visibility = 'off'; end
registry = landing2d.config.methodRegistry(c);
figures = struct();
if isfield(results,'generalizationSummary')
    figures.generalization = landing2d.minimal.plotGeneralization(results,visible,c);
end
figures.learning = figure('Visible',visibility,'Name','Minimal study: learning','Color','w');
hold on;
curves = results.learningCurves;
for method = registry.methods
    rows = curves(curves.MethodId==string(method.id),:);
    if isempty(rows), continue; end
    seeds = unique(rows.TrainSeed); updateAxis = 0:c.rl.evaluateEvery:c.rl.ppoIterations;
    y = nan(numel(seeds),numel(updateAxis));
    for j = 1:numel(seeds)
        r = rows(rows.TrainSeed==seeds(j),:);
        y(j,:) = interp1(r.Iteration,r.ValidationSuccess,min(updateAxis,max(r.Iteration)), ...
            'linear','extrap');
    end
    plot(updateAxis,mean(y,1),'Color',method.color,'LineStyle',method.lineStyle, ...
        'LineWidth',1.6,'DisplayName',method.label);
end
xlabel('PPO update'); ylabel('Validation landing rate'); ylim([0 1]); grid on;
legend('Location','southeast'); title('Mean over training seeds; validation selects checkpoints');
if isfield(results,'caseSummary')
figures.cases = figure('Visible',visibility,'Name','Minimal study: three cases', ...
    'Color','w','Position',[100 100 1100 650]);
tiledlayout(2,2);
metrics = {'Success','WindowAimErrorRMS_m','WindowCommandRateRMS_mps3','CommandVariance_m2ps4'};
labels = {'Landing rate','Aim error RMS (m)','Command rate RMS (m/s^3)','Command variance (m^2/s^4)'};
S = results.caseSummary;
for k = 1:numel(metrics)
    nexttile; hold on;
    for j = 1:numel(registry.methods)
        method = registry.methods(j); y = nan(1,3); ci = y;
        for s = 1:3
            row = S(S.MethodId==string(method.id) & S.Case==string(results.cases(s).id),:);
            if ~isempty(row), y(s)=row.(metrics{k}); ci(s)=row.([metrics{k},'_ci']); end
        end
        errorbar((1:3)+0.12*(j-2),y,ci,method.marker, ...
            'Color',method.color,'LineWidth',1.3,'DisplayName',method.label);
    end
    xticks(1:3); xticklabels({'S1 reference','S2 dropout','S3 acceleration'});
    xlim([0.5 3.5]); ylabel(labels{k}); grid on;
    if k==1, ylim([0 1]); legend('Location','best'); end
end
sgtitle('Read command variation with tracking and outcomes; bars: 95% seed intervals');
end
if isfield(results,'isSmoke') && results.isSmoke
    title(findobj(figures.learning,'Type','axes'),'TEST ONLY: one-update smoke, no performance evidence');
    if isfield(figures,'cases'), sgtitle(figures.cases,'TEST ONLY: one-update smoke, no performance evidence'); end
end
if ~isempty(folder)
    if ~isfolder(folder), mkdir(folder); end
    for name = fieldnames(figures)'
        exportgraphics(figures.(name{1}),fullfile(folder,[name{1},'.png']),'Resolution',160);
    end
end
end
