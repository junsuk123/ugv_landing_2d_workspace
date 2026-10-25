function fig = plotGeneralization(results,visible)
% PLOTGENERALIZATION Display each shift so a macro average cannot hide it.
visibility = 'off'; if visible, visibility = 'on'; end
fig = figure('Visible',visibility,'Name','Generalization: predeclared shifts', ...
    'Color','w','Position',[80 80 1100 700]);
tiledlayout(2,2);
registry = landing2d.config.methodRegistry(); factors = ["motion","dropout","noise"];
S = results.generalizationSummary; S = S(S.Shift=="OOD",:);
metrics = {'Success','SuccessDrop','AimErrorRMS_m','Unsafe'};
labels = {'OOD landing rate','Paired ID minus OOD landing rate', ...
    'OOD aim error RMS (m)','OOD unsafe contact rate'};
for k = 1:4
    nexttile; hold on;
    bounds = [0,1];
    data = S;
    if k==2, data = results.generalizationGapSummary; end
    for j = 1:numel(registry.methods)
        method = registry.methods(j); y = nan(1,3); half = y;
        for s = 1:3
            row = data(data.MethodId==string(method.id) & data.Factor==factors(s),:);
            if ~isempty(row), y(s)=row.(metrics{k}); half(s)=row.([metrics{k},'_ci']); end
        end
        errorbar((1:3)+0.12*(j-2),y,half,method.marker, ...
            'Color',method.color,'LineWidth',1.3,'DisplayName',method.label);
        intervalHalf = half; intervalHalf(~isfinite(intervalHalf)) = 0;
        bounds = [bounds,y-intervalHalf,y+intervalHalf]; %#ok<AGROW>
    end
    xticks(1:3); xticklabels({'Acceleration','Dropout duration','Sensor noise'});
    xlim([0.5 3.5]); ylabel(labels{k}); grid on;
    if ismember(k,[1,4])
        bounds = bounds(isfinite(bounds));
        ylim([min(bounds)-.03,max(bounds)+.03]); % retain full, possibly unbounded t intervals
    end
    if k==1, legend('Location','best'); end
    if k==2, yline(0,':'); end
end
sgtitle('Primary: equal-weight OOD landing rate; panels: 95% training-seed intervals');
if isfield(results,'isSmoke') && results.isSmoke
    sgtitle(fig,'TEST ONLY: one-update smoke, no performance evidence');
end
end
