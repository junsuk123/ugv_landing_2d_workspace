function [fig,stopped] = replayFigure(records,info,options)
% REPLAYFIGURE Animated replay of one stored OOD episode, all methods in lockstep.
%   approach   drone position relative to the pad (pad frame) with the pad
%              (+- touchdown tolerance) and the camera-aim line h*tan(pitch)
%   aim error  e_aim of the common reward (0 at the aim point) with the tolerance band
%   speed      true UGV speed and each drone's horizontal speed
%   a_x        requested horizontal acceleration [m/s^2]
%   height     height above the pad
%   correction pre-tanh a_x mean split: mixed correction sigma(beta)*correction
%              (solid) of the residual arms; base MLP (dotted)
%   attention  first-hop attention on the edges into RelativeState (TOSM solid,
%              Shuffled dashed; the label names each arm's own relation)
% The UGV acceleration phase [T1, T1+T2) is shaded orange, an injected marker
% dropout grey. The side panel lists each method's outcome and study metrics
% once its episode has ended. OPTIONS: speed (simulated s per wall s, Inf =
% draw at once), visible. Closing the window stops the replay.
n = numel(records); scenario = records(1).result.scenario;
events = records(1).result.resetInfo.evaluatorMetadata.sensorEvents;
c = info.config; tolerance = c.experiment.safety.touchdownPositionTolerance;
slope = tan(-c.experiment.sensor.cameraPitchOffset);
endTime = max(arrayfun(@(r)r.result.time(end),records));
fig = figure('Name',sprintf('Showcase replay | episode %d',info.episodeSeed),'Color','w', ...
    'NumberTitle','off','Visible',onOff(options.visible),'Position',[40 40 1560 900]);
layout = tiledlayout(fig,3,4,'TileSpacing','compact','Padding','compact');
title(layout,sprintf(['%s | training seed %d | %s OOD | episode %d (%d of %d, %s) | a_2 = %.2f m/s^2 ' ...
    'during [%.1f, %.1f) s'],info.setLabel,info.trainSeed,info.factor,info.episodeSeed,info.index, ...
    info.count,info.selection,scenario.a2,scenario.T1,scenario.T1+scenario.T2),'Interpreter','none');

approach = nexttile(layout,1,[2 2]); hold(approach,'on'); grid(approach,'on');
maxHeight = max(arrayfun(@(r)max(r.height),records));
fill(approach,[-tolerance tolerance tolerance -tolerance],[-0.05 -0.05 0 0],[0.3 0.7 0.3], ...
    'EdgeColor','none','HandleVisibility','off');
plot(approach,-slope*[0 maxHeight],[0 maxHeight],'--','Color',[0.5 0.5 0.5],'DisplayName','camera-aim line');
xlabel(approach,'x_{drone} - x_{pad} [m]'); ylabel(approach,'height above pad [m]');
title(approach,'Approach in the pad frame (pad = green, +- touchdown tolerance)');
panels = struct('aim',nexttile(layout,3),'speed',nexttile(layout,4),'ax',nexttile(layout,7), ...
    'height',nexttile(layout,8),'correction',nexttile(layout,9),'attention',nexttile(layout,10));
textAxis = nexttile(layout,11,[1 2]); axis(textAxis,'off');
names = fieldnames(panels);
for i = 1:numel(names)
    ax = panels.(names{i}); hold(ax,'on'); grid(ax,'on'); xlim(ax,[0 endTime]);
    shade(ax,scenario.T1,scenario.T1+scenario.T2,[1 0.85 0.6]);
    if isfinite(events.dropoutStart) && events.dropoutEnd>events.dropoutStart
        shade(ax,events.dropoutStart,events.dropoutEnd,[0.85 0.85 0.85]);
    end
end
yline(panels.aim,[-tolerance tolerance],':k','HandleVisibility','off'); ylabel(panels.aim,'aim error [m]'); title(panels.aim,'Aim error');
ylabel(panels.speed,'v_x [m/s]'); title(panels.speed,'UGV (black) and drone horizontal speed');
ylabel(panels.ax,'requested a_x [m/s^2]'); title(panels.ax,'Horizontal command');
ylabel(panels.height,'height [m]'); xlabel(panels.height,'time [s]'); title(panels.height,'Height above pad');
ylabel(panels.correction,'pre-tanh a_x'); xlabel(panels.correction,'time [s]');
title(panels.correction,'a_x mean: correction \sigma(\beta)c (solid), base (dotted)');
ylabel(panels.attention,'attention'); xlabel(panels.attention,'time [s]'); ylim(panels.attention,[0 1]);
title(panels.attention,'Attention into RelativeState (TOSM solid, Shuffled dashed)');
plot(panels.speed,records(1).result.time,records(1).result.vxPad,'k-','LineWidth',1.6,'HandleVisibility','off');

h = struct('path',gobjects(n,1),'head',gobjects(n,1),'aim',gobjects(n,1),'speed',gobjects(n,1), ...
    'ax',gobjects(n,1),'height',gobjects(n,1),'correction',gobjects(n,1),'base',gobjects(n,1),'attention',{cell(n,1)});
for k = 1:n
    r = records(k); color = r.color; name = char(r.label);
    h.path(k) = plot(approach,nan,nan,'-','Color',color,'LineWidth',1.8,'DisplayName',name);
    h.head(k) = plot(approach,nan,nan,'o','Color',color,'MarkerFaceColor',color,'HandleVisibility','off');
    h.aim(k) = plot(panels.aim,nan,nan,'Color',color,'LineWidth',1.3);
    h.speed(k) = plot(panels.speed,nan,nan,'Color',color,'LineWidth',1.3);
    h.ax(k) = plot(panels.ax,nan,nan,'Color',color,'LineWidth',1.3);
    h.height(k) = plot(panels.height,nan,nan,'Color',color,'LineWidth',1.3);
    if ~isempty(r.correction)
        h.correction(k) = plot(panels.correction,nan,nan,'-','Color',color,'LineWidth',1.4);
        h.base(k) = plot(panels.correction,nan,nan,':','Color',color,'LineWidth',1.0);
    end
    if ~isempty(r.attention)
        style = '-'; if contains(r.methodId,'shuffled'), style = '--'; end
        h.attention{k} = gobjects(size(r.attention,1),1);
        for e = 1:size(r.attention,1)
            h.attention{k}(e) = plot(panels.attention,nan,nan,style,'Color',color*(0.55+0.45*e/size(r.attention,1)), ...
                'LineWidth',1.2,'DisplayName',sprintf('%s %s',shortLabel(r.label),r.edgeLabels(e)));
        end
    end
end
ablation = find(arrayfun(@(r)~isempty(r.ablation),records),1); hA = struct();
if ~isempty(ablation)
    color = records(ablation).color;
    hA.path = plot(approach,nan,nan,':','Color',color,'LineWidth',1.8,'DisplayName','TOSM, correction off (counterfactual)');
    hA.speed = plot(panels.speed,nan,nan,':','Color',color,'LineWidth',1.2);
    hA.height = plot(panels.height,nan,nan,':','Color',color,'LineWidth',1.2);
end
legend(approach,'Location','northwest');
if any(arrayfun(@(r)~isempty(r.attention),records)), legend(panels.attention,'Location','eastoutside','FontSize',6); end
summary = text(textAxis,0,1,'','VerticalAlignment','top','FontName','Consolas','FontSize',8.5,'Interpreter','none');

frameStep = c.experiment.policyDt; wall = tic; stopped = false;
times = frameStep:frameStep:endTime+frameStep;
if ~isfinite(options.speed), times = endTime+frameStep; end
for t = times
    if ~isvalid(fig), stopped = true; break; end
    for k = 1:n
        r = records(k);
        i = find(r.result.time<=t,1,'last'); d = find(r.traj.time<=t,1,'last');
        rel = r.result.xDrone(1:i)-r.result.xPad(1:i);
        set(h.path(k),'XData',rel,'YData',r.height(1:i)); set(h.head(k),'XData',rel(end),'YData',r.height(i));
        set(h.aim(k),'XData',r.result.time(1:i),'YData',r.aim(1:i));
        set(h.speed(k),'XData',r.result.time(1:i),'YData',r.result.vxDrone(1:i));
        set(h.height(k),'XData',r.result.time(1:i),'YData',r.height(1:i));
        if ~isempty(d)
            set(h.ax(k),'XData',r.traj.time(1:d),'YData',r.traj.requestedAcceleration(1,1:d));
            if ~isempty(r.correction)
                set(h.correction(k),'XData',r.traj.time(1:d),'YData',r.correction(1,1:d));
                set(h.base(k),'XData',r.traj.time(1:d),'YData',r.base(1,1:d));
            end
            for e = 1:numel(h.attention{k})
                set(h.attention{k}(e),'XData',r.traj.time(1:d),'YData',r.attention(e,1:d));
            end
        end
    end
    if ~isempty(ablation)
        a = records(ablation).ablation; i = find(a.result.time<=t,1,'last');
        set(hA.path,'XData',a.result.xDrone(1:i)-a.result.xPad(1:i),'YData',a.height(1:i));
        set(hA.speed,'XData',a.result.time(1:i),'YData',a.result.vxDrone(1:i));
        set(hA.height,'XData',a.result.time(1:i),'YData',a.height(1:i));
    end
    set(summary,'String',summaryText(records,t));
    drawnow limitrate;
    if isfinite(options.speed)
        while toc(wall) < t/options.speed, pause(0.005); end
    end
end
if isvalid(fig), set(summary,'String',summaryText(records,Inf)); drawnow; end
end

function lines = summaryText(records,t)
lines = {sprintf('%-9s %-24s %6s %6s %6s %6s %6s','method','outcome','land','aim','relV','cmd','recov')};
mix = {};
for k = 1:numel(records)
    r = records(k);
    lines{end+1} = row(shortLabel(r.label),r.metric,r.result.time(end),t); %#ok<AGROW>
    if ~isempty(r.ablation)
        lines{end+1} = row("TOSM off",r.ablation.metric,r.ablation.result.time(end),t); %#ok<AGROW>
    end
    if isfinite(r.mix), mix{end+1} = sprintf('%s %.3f',shortLabel(r.label),r.mix); end %#ok<AGROW>
end
lines{end+1} = '';
lines{end+1} = 'land: landing time [s]; aim/relV: episode RMS of aim error [m] / relative speed [m/s]';
lines{end+1} = 'cmd: RMS command rate [m/s^3]; recov: settle time after the acceleration phase [s]';
lines{end+1} = 'TOSM off: same episode, TOSM correction switched off (sigma(beta)=0), counterfactual';
lines{end+1} = ['sigma(beta): ',strjoin(mix,', ')];
end

function s = row(label,m,endTime,t)
if t < endTime
    s = sprintf('%-9s %-24s',label,'flying...'); return;
end
outcome = char(replace(string(m.FailureClass),'_',' '));
if m.Unsafe, outcome = [outcome,' !']; end
if numel(outcome)>24, outcome = [outcome(1:23),'.']; end
s = sprintf('%-9s %-24s %6.1f %6.2f %6.2f %6.2f %6.1f',label,outcome,m.LandingTime_s, ...
    m.AimErrorRMS_m,m.RelativeSpeedRMS_mps,m.CommandRateRMS_mps3,m.RecoveryTime_s);
end

function s = shortLabel(label)
s = erase(string(label),[" residual PPO"," PPO"]);
if s=="", s = "PPO"; end
s = replace(s,"Residual-MLP","MLP");
end

function shade(ax,t0,t1,color)
yl = [-1e3 1e3];   % spans any data range; excluded from the automatic limits
patch(ax,[t0 t1 t1 t0],[yl(1) yl(1) yl(2) yl(2)],color,'EdgeColor','none','FaceAlpha',0.45, ...
    'HandleVisibility','off','YLimInclude','off');
end

function s = onOff(flag)
if flag, s = 'on'; else, s = 'off'; end
end
