function fig = plotCaseTimeSeries(F,cfg,caseId,visible)
% PLOTCASETIMESERIES  One controlled case over time for every method (default S4).
%   fig = landing2d.viz.plotCaseTimeSeries(factorialResult,cfg,'S4',visible)
% Rows: aim error e_aim (landing2d.evaluation.aimError), relative velocity
% v_r = v_pad - v_drone, requested a_x and requested a_z. Orange = UGV
% acceleration phase, gray = injected marker dropout. Bold = replicate 1,
% faint = the other noise replicates of the display training seed (same
% physical scenario, different sensor-noise tables). Shows whether a policy
% reacts to the acceleration it must follow and how much its commands move
% during the dropout; every number comes from the stored rollouts.
if nargin < 3 || isempty(caseId), caseId = 'S4'; end
if nargin < 4, visible = false; end
vis = 'off'; if visible, vis = 'on'; end
registry = landing2d.config.methodRegistry(cfg);
spec = F.cases(strcmp({F.cases.id},caseId));
entries = F.display(strcmp({F.display.case},caseId));
assert(~isempty(spec) && ~isempty(entries),'landing2d:CaseTimeSeries', ...
    'No stored rollouts of case %s.',caseId);
fig = figure('Name',sprintf('%s time series',caseId),'Color','w','Visible',vis, ...
    'Position',[60 40 1100 900]);
layout = tiledlayout(fig,4,1,'TileSpacing','compact','Padding','compact');
title(layout,sprintf(['%s  %s, training seed %d (bold = replicate 1, faint = other ' ...
    'noise replicates)'],spec.id,spec.name,F.displaySeed));
labels = {'aim error e_{aim} [m]','relative velocity v_r [m/s]', ...
    'requested a_x [m/s^2]','requested a_z [m/s^2]'};
axs = gobjects(4,1);
for k = 1:4
    axs(k) = nexttile(layout); hold(axs(k),'on'); grid(axs(k),'on'); box(axs(k),'on');
    ylabel(axs(k),labels{k});
end
for e = 1:numel(entries)
    method = registry.methods(strcmp({registry.methods.id},entries(e).methodId));
    results = entries(e).results;
    success = sum(cellfun(@(r)strcmp(r.terminalReason,'SUCCESS'),results));
    for r = numel(results):-1:1
        res = results{r};
        n = size(res.command,2);
        t = res.time(1:n);
        h = res.zDrone(1:n)-res.scenario.padHeight;
        y = {landing2d.evaluation.aimError(res.xPad(1:n),res.xDrone(1:n),h,cfg), ...
            res.vxPad(1:n)-res.vxDrone(1:n),res.command(1,:),res.command(2,:)};
        for k = 1:4
            if r == 1
                handle = plot(axs(k),t,y{k},method.lineStyle,'Color',method.color, ...
                    'LineWidth',1.4,'DisplayName',sprintf('%s | success %d/%d', ...
                    method.label,success,numel(results)));
                if k > 1, handle.HandleVisibility = 'off'; end
            else
                plot(axs(k),t,y{k},'-','Color',[method.color,0.15],'LineWidth',0.5, ...
                    'HandleVisibility','off');
            end
        end
    end
end
s = spec.scenario; ev = spec.sensorEvents;
for k = 1:4
    if s.a2 > 0
        xregion(axs(k),s.T1,s.T1+s.T2,'FaceColor',[1 .85 .6],'FaceAlpha',0.35, ...
            'HandleVisibility','off');
    end
    if isfinite(ev.dropoutStart)
        xregion(axs(k),ev.dropoutStart,ev.dropoutEnd,'FaceColor',[.6 .6 .6], ...
            'FaceAlpha',0.35,'HandleVisibility','off');
    end
    yline(axs(k),0,'-','Color',[.3 .3 .3],'HandleVisibility','off');
end
linkaxes(axs,'x');
xlabel(axs(4),'time [s]');
legend(axs(1),'Location','northeast','FontSize',7);
end
