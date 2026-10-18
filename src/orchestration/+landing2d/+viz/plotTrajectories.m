function fig = plotTrajectories(F,cfg,visible)
% PLOTTRAJECTORIES  S1-S4 flights of the display training seed (every replicate).
%   fig = landing2d.viz.plotTrajectories(factorialResult,cfg,visible)
% Left: pad-relative x-z path with the level-attitude camera FOV edges.
% Right: aim error e_aim = e_x - h tan(camera pitch offset) over time, with
% the UGV acceleration phase (orange) and the marker dropout (gray).
% Bold = replicate 1, faint = other noise replicates.
if nargin < 3, visible = false; end
vis = 'off'; if visible, vis = 'on'; end
registry = landing2d.config.methodRegistry();
specs = F.cases;
present = intersect({specs.id},{F.display.case},'stable');
specs = specs(ismember({specs.id},present));
nS = numel(specs);
fig = figure('Name','S1-S4 trajectories','Color','w','Visible',vis, ...
    'Position',[40 30 1500 max(420,250*nS)]);
layout = tiledlayout(fig,nS,2,'TileSpacing','compact','Padding','compact');
title(layout,sprintf('Controlled cases, training seed %d (bold = replicate 1, faint = others)', ...
    F.displaySeed));
sensor = cfg.experiment.sensor;
for s = 1:nS
    spec = specs(s);
    entries = F.display(strcmp({F.display.case},spec.id));
    axPath = nexttile(layout,2*s-1); hold(axPath,'on'); grid(axPath,'on'); box(axPath,'on');
    axErr = nexttile(layout,2*s); hold(axErr,'on'); grid(axErr,'on'); box(axErr,'on');
    shade(axErr,spec);
    hMax = spec.scenario.height+0.5;
    hRef = linspace(0,hMax,50);
    for edge = [-1,1]
        plot(axPath,hRef*tan(sensor.cameraPitchOffset+edge*sensor.fov/2),hRef,':', ...
            'Color',[.6 .6 .6],'HandleVisibility','off');
    end
    for e = 1:numel(entries)
        method = registry.methods(strcmp({registry.methods.id},entries(e).methodId));
        results = entries(e).results;
        success = sum(cellfun(@(r)strcmp(r.terminalReason,'SUCCESS'),results));
        for r = numel(results):-1:1
            res = results{r};
            h = res.zDrone-res.scenario.padHeight;
            xr = res.xDrone-res.xPad;
            aim = (res.xPad-res.xDrone)-max(h,0)*tan(sensor.cameraPitchOffset);
            if r==1
                plot(axPath,xr,h,method.lineStyle,'Color',method.color,'LineWidth',1.6, ...
                    'DisplayName',sprintf('%s | success %d/%d',method.label,success,numel(results)));
                plot(axErr,res.time,aim,method.lineStyle,'Color',method.color,'LineWidth',1.4, ...
                    'DisplayName',method.label);
            else
                plot(axPath,xr,h,'-','Color',[method.color,0.2],'LineWidth',0.5,'HandleVisibility','off');
                plot(axErr,res.time,aim,'-','Color',[method.color,0.2],'LineWidth',0.5, ...
                    'HandleVisibility','off');
            end
        end
    end
    yline(axPath,cfg.experiment.safety.touchdownHeight,'--','Color',[.3 .3 .3],'HandleVisibility','off');
    xlabel(axPath,'drone x - pad x [m]'); ylabel(axPath,'height above pad [m]');
    title(axPath,sprintf('%s  %s',spec.id,spec.name)); legend(axPath,'Location','northeast','FontSize',7);
    yline(axErr,0,'-','Color',[.3 .3 .3],'HandleVisibility','off');
    xlabel(axErr,'time [s]'); ylabel(axErr,'aim error [m]');
    title(axErr,sprintf('%s: CA %.1f-%.1f s (a = %.1f m/s^2), dropout %s',spec.id, ...
        spec.scenario.T1,spec.scenario.T1+spec.scenario.T2,spec.scenario.a2,dropoutText(spec)));
end
end

function shade(ax,spec)
s = spec.scenario; e = spec.sensorEvents;
limits = [-3,3];
if s.a2>0
    patch(ax,[s.T1,s.T1+s.T2,s.T1+s.T2,s.T1],limits([1 1 2 2]),[1 .85 .6], ...
        'FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');
end
if isfinite(e.dropoutStart)
    patch(ax,[e.dropoutStart,e.dropoutEnd,e.dropoutEnd,e.dropoutStart],limits([1 1 2 2]), ...
        [.6 .6 .6],'FaceAlpha',0.35,'EdgeColor','none','HandleVisibility','off');
end
ylim(ax,limits);
end

function text = dropoutText(spec)
e = spec.sensorEvents;
if isfinite(e.dropoutStart)
    text = sprintf('%.1f-%.1f s',e.dropoutStart,e.dropoutEnd);
else
    text = 'none';
end
end
