function [fig,tabs,layouts] = replayPlanarVisibilityComparison(runs,c,options)
% REPLAYPLANARVISIBILITYCOMPARISON  V2 paired trajectories of the compared methods and R-GAT state.
% Supports unequal terminal times, body-fixed-camera FOV footprints, fixed
% world bounds, a Monte Carlo mean/covariance summary, and optional replay.
% 3D option: x-z panels show the side view, and an extra last tab shows the
% pad-relative 3D trajectories of every paired evaluation episode.
if nargin < 3, options=struct(); end
if ~isfield(options,'animate'), options.animate=true; end
if ~isfield(options,'playbackSpeed'), options.playbackSpeed=c.playbackSpeed; end
if ~isfield(options,'includeEpisodes'), options.includeEpisodes=false; end
runs=landing2d.viz.normalizeRuns(runs);
nRuns=numel(runs);
assert(nRuns>=2,'landing2d:V2ComparisonCount', ...
    'The comparison view requires at least two methods.');
nCases=numel(runs(1).results);
assert(nCases>0,'landing2d:V2ComparisonEmpty','No evaluation trajectories supplied.');
for i=2:numel(runs)
    assert(numel(runs(i).results)==nCases,'landing2d:V2ComparisonShape', ...
        'All methods must use the same paired evaluation seeds.');
end
visible='on'; if ~c.figureVisible, visible='off'; end
figureName='Planar visibility PPO v2 - paired comparison';
if landing2d.environment.isSpatial(c)
    figureName='3D visibility PPO - paired comparison (x-z side view + 3D tab)';
end
fig=figure('Name',figureName, ...
    'Tag','landing2dFinalTest','NumberTitle','off','Color','w', ...
    'Position',[35,45,1580,860],'Visible',visible);
group=uitabgroup(fig,'Units','normalized','Position',[0,0,1,1]);
caseIndices=[];
if options.includeEpisodes, caseIndices=1:nCases; end
tabs=gobjects(1,numel(caseIndices)+1);
layouts=gobjects(1,numel(caseIndices)+1);
views=cell(1,numel(caseIndices));
for viewIndex=1:numel(caseIndices)
    j=caseIndices(viewIndex);
    tabs(viewIndex)=uitab(group,'Title',sprintf('Evaluation %d',j), ...
        'BackgroundColor','w');
    layouts(viewIndex)=tiledlayout(tabs(viewIndex),2,3, ...
        'TileSpacing','compact','Padding','compact');
    ax=nexttile(layouts(viewIndex),1,[2,2]); ax.Tag='landing2dV2TrajectoryAxes';
    hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    [xLimits,zLimits]=fixedBounds(runs,j,c);
    xlim(ax,xLimits); ylim(ax,zLimits); set(ax,'XLimMode','manual','YLimMode','manual');
    phaseBackground(ax,runs(1).results(j).scenario,zLimits,c);
    xlabel(ax,'World horizontal position x [m]'); ylabel(ax,'Altitude z [m]');
    title(ax,sprintf('Paired seed %d: full trajectory and body-fixed-camera FOV', ...
        runs(1).results(j).seed));
    scenario=runs(1).results(j).scenario;
    tq=linspace(0,scenario.deadline,300);
    xp=arrayfun(@(t)landing2d.scenario.evaluateTrajectory(scenario,t),tq);
    plot(ax,xp,scenario.padHeight+zeros(size(xp)),'-','Color',[0.25,0.25,0.25], ...
        'LineWidth',1.0,'DisplayName','Moving pad path');
    hPad=plot(ax,nan,nan,'-','Color',[0.08,0.08,0.08], ...
        'LineWidth',5,'HandleVisibility','off');
    hTrail=gobjects(1,nRuns); hDrone=gobjects(1,nRuns); hFov=gobjects(1,nRuns);
    for i=1:nRuns
        hFov(i)=patch(ax,nan,nan,runs(i).color,'FaceAlpha',0.06, ...
            'EdgeColor',runs(i).color,'LineStyle',':','HandleVisibility','off');
        hTrail(i)=plot(ax,nan,nan,runs(i).lineStyle,'Color',runs(i).color, ...
            'LineWidth',2,'DisplayName',runs(i).label);
        hDrone(i)=plot(ax,nan,nan,'o','Color',runs(i).color, ...
            'MarkerFaceColor',runs(i).color,'MarkerSize',6,'HandleVisibility','off');
    end
    legend(ax,'Location','southoutside','Orientation','horizontal', ...
        'Interpreter','none','AutoUpdate','off','Box','off');
    graphAx=nexttile(layouts(viewIndex),3);
    plotRgat(graphAx,runs,sprintf('R-GAT aggregate / evaluation %d',j));
    infoAx=nexttile(layouts(viewIndex),6); axis(infoAx,'off');
    infoText=text(infoAx,0,1,'','Units','normalized','VerticalAlignment','top', ...
        'FontName','Consolas','FontSize',9,'Interpreter','none');
    views{viewIndex}=struct('ax',ax,'pad',hPad,'trail',hTrail,'drone',hDrone, ...
        'fov',hFov,'info',infoText,'xLimits',xLimits,'zLimits',zLimits);
end

tabs(end)=uitab(group,'Title','Monte Carlo summary','BackgroundColor','w');
layouts(end)=tiledlayout(tabs(end),2,3,'TileSpacing','compact','Padding','compact');
plotMonteCarloMean(nexttile(layouts(end),1,[1,2]),runs,c);
plotRates(nexttile(layouts(end),3),runs);
plotTraining(nexttile(layouts(end),4),runs);
plotProfiles(nexttile(layouts(end),5),runs);
plotRgat(nexttile(layouts(end),6),runs,'R-GAT mean relation attention');
group.SelectedTab=tabs(end);
if isfield(runs(1).results(1),'yDrone')
    tabs(end+1)=uitab(group,'Title','3D trajectories','BackgroundColor','w');
    layouts(end+1)=tiledlayout(tabs(end),1,numel(runs), ...
        'TileSpacing','compact','Padding','compact');
    plotSpatialTrajectories(layouts(end),runs,c);
    group.SelectedTab=tabs(end-1);
end

if options.animate
    animateViews(fig,views,runs,c,options.playbackSpeed);
else
    updateViews(views,runs,c,Inf);
    drawnow;
end
end

function animateViews(fig,views,runs,c,speed)
if isinf(speed)
    updateViews(views,runs,c,Inf);
    if isgraphics(fig), drawnow; end
    return;
end
tMax=0;
for i=1:numel(runs)
    for j=1:numel(runs(i).results)
        tMax=max(tMax,runs(i).results(j).time(end));
    end
end
frameDt=1/max(c.animationHz,1);
timeline=unique([0:frameDt:tMax,tMax]);
clock=tic;
for k=1:numel(timeline)
    if ~isgraphics(fig), return; end
    if isfinite(speed)
        wait=timeline(k)/speed-toc(clock);
        if wait>0, pause(wait); end
    end
    updateViews(views,runs,c,timeline(k));
    drawnow limitrate;
end
if isgraphics(fig), drawnow; end
end

function updateViews(views,runs,c,tNow)
for j=1:numel(views)
    view=views{j}; scenario=runs(1).results(j).scenario;
    if isinf(tNow)
        padTime=0;
        for q=1:numel(runs), padTime=max(padTime,runs(q).results(j).time(end)); end
    else
        padTime=min(tNow,scenario.deadline);
    end
    [xp,~,~,~]=landing2d.scenario.evaluateTrajectory(scenario,padTime);
    set(view.pad,'XData',xp+[-c.padHalfLength,c.padHalfLength], ...
        'YData',[scenario.padHeight,scenario.padHeight]);
    lines=cell(1,numel(runs)+1);
    lines{1}=sprintf('display time: %.2f s',padTime);
    for i=1:numel(runs)
        r=runs(i).results(j);
        if isinf(tNow), idx=numel(r.time); else, idx=find(r.time<=tNow+1e-12,1,'last'); end
        if isempty(idx), idx=1; end
        set(view.trail(i),'XData',r.xDrone(1:idx),'YData',r.zDrone(1:idx));
        set(view.drone(i),'XData',r.xDrone(idx),'YData',r.zDrone(idx));
        [left,right]=fovGround(r,idx,c);
        set(view.fov(i),'XData',[r.xDrone(idx),left,right], ...
            'YData',[r.zDrone(idx),scenario.padHeight,scenario.padHeight]);
        ex=r.xPad(idx)-r.xDrone(idx);
        lines{i+1}=sprintf(['%s\n  t %6.2f | h %5.2f | ex %+6.2f\n' ...
            '  visible %-3s | %-24s'],runs(i).label,r.time(idx), ...
            r.zDrone(idx)-scenario.padHeight,ex,yesNo(r.visible(idx)),r.terminalReason);
    end
    set(view.info,'String',strjoin(lines,newline));
    xlim(view.ax,view.xLimits); ylim(view.ax,view.zLimits);
end
end

function [left,right]=fovGround(r,k,c)
h=r.zDrone(k)-r.scenario.padHeight;
theta=r.theta(k)+c.experiment.sensor.cameraPitchOffset;
beta=[-c.experiment.sensor.fov/2,c.experiment.sensor.fov/2];
x=nan(1,2);
for q=1:2
    direction=[-sin(theta);-cos(theta)]*cos(beta(q)) + ...
        [cos(theta);-sin(theta)]*sin(beta(q));
    if direction(2)<-1e-8
        x(q)=r.xDrone(k)+h*direction(1)/(-direction(2));
    end
end
valid=x(isfinite(x));
if numel(valid)==2, left=min(valid); right=max(valid); else, left=nan; right=nan; end
end

function [xLimits,zLimits]=fixedBounds(runs,j,c)
x=[]; z=[];
for i=1:numel(runs)
    r=runs(i).results(j); x=[x;r.xDrone(:);r.xPad(:)]; z=[z;r.zDrone(:)]; %#ok<AGROW>
    for k=unique(round(linspace(1,numel(r.time),min(60,numel(r.time)))))
        [a,b]=fovGround(r,k,c); x=[x;a;b]; %#ok<AGROW>
    end
end
x=x(isfinite(x)); z=z(isfinite(z));
if isempty(x), x=[0,1]; end; if isempty(z), z=[c.padHeight,c.padHeight+1]; end
xPad=max(0.5,0.04*(max(x)-min(x)+eps));
xLimits=[min(x)-xPad,max(x)+xPad];
zLimits=[max(0,c.padHeight-0.15),min(c.padHeight+c.ceilingHeight,max(z)+0.8)];
if diff(zLimits)<1, zLimits(2)=zLimits(1)+1; end
end

function phaseBackground(ax,s,zLimits,c)
t=[0,s.T1,s.T1+s.T2,s.deadline];
x=arrayfun(@(q)landing2d.scenario.evaluateTrajectory(s,q),t);
names={'CV_1','CA','CV_2'};
for k=1:3
    patch(ax,[x(k),x(k+1),x(k+1),x(k)], ...
        [zLimits(1),zLimits(1),zLimits(2),zLimits(2)],c.segmentColors(k,:), ...
        'FaceAlpha',c.segmentAlpha,'EdgeColor','none', ...
        'HandleVisibility','off','Tag','Landing2dV2PhaseBackground');
    if c.showSegmentLabels
        text(ax,mean(x(k:k+1)),zLimits(2)-0.04*diff(zLimits), ...
            names{k},'HorizontalAlignment','center', ...
            'Color',0.65*c.segmentColors(k,:),'FontWeight','bold', ...
            'HandleVisibility','off');
    end
end
end

function plotMonteCarloMean(ax,runs,c)
hold(ax,'on'); grid(ax,'on'); box(ax,'on');
q=linspace(0,1,100); theta=linspace(0,2*pi,40);
commonSuccess=true(1,numel(runs(1).results));
for i=1:numel(runs)
    commonSuccess=commonSuccess & strcmp({runs(i).results.terminalReason},'SUCCESS');
end
selected=find(commonSuccess);
if numel(selected)<2
    text(ax,0.5,0.5,sprintf('Only %d paired common-success episode(s)',numel(selected)), ...
        'Units','normalized','HorizontalAlignment','center');
    xlabel(ax,'Drone - pad horizontal position [m]');
    ylabel(ax,'Height above pad [m]');
    title(ax,'Common-success pad-relative trajectories');
    return;
end
for i=1:numel(runs)
    X=nan(numel(q),numel(selected)); Z=X;
    for column=1:numel(selected)
        j=selected(column);
        r=runs(i).results(j); u=(r.time-r.time(1))/max(r.time(end)-r.time(1),eps);
        [u,keep]=unique(u,'stable');
        X(:,column)=interp1(u,r.xDrone(keep)-r.xPad(keep),q,'linear','extrap');
        Z(:,column)=interp1(u,r.zDrone(keep)-r.scenario.padHeight,q,'linear','extrap');
    end
    mx=mean(X,2,'omitnan'); mz=mean(Z,2,'omitnan');
    plot(ax,mx,mz,runs(i).lineStyle,'Color',runs(i).color, ...
        'LineWidth',2,'DisplayName',sprintf('%s mean',runs(i).label));
    for k=unique(round(linspace(8,numel(q)-5,7)))
        values=[X(k,:);Z(k,:)]; values=values(:,all(isfinite(values),1));
        if size(values,2)<2, continue; end
        C=cov(values'); [V,D]=eig(0.5*(C+C'));
        p=V*diag(sqrt(max(diag(D),0)))*[cos(theta);sin(theta)];
        plot(ax,mx(k)+p(1,:),mz(k)+p(2,:),'Color',runs(i).color, ...
            'LineWidth',0.6,'HandleVisibility','off');
    end
end
yline(ax,0,':','HandleVisibility','off');
xline(ax,0,':','HandleVisibility','off');
xlabel(ax,'Drone - pad horizontal position [m]'); ylabel(ax,'Height above pad [m]');
title(ax,sprintf(['Common-success pad-relative mean and 1\\sigma covariance ' ...
    '(%d/%d paired seeds; normalized episode progress)'], ...
    numel(selected),numel(commonSuccess)));
legend(ax,'Location','best','Interpreter','none','Box','off');
end

function plotSpatialTrajectories(layout,runs,c)
title(layout,'Pad-relative 3D trajectories (circle: start, triangle: end)');
pad=[c.padHalfLength,c.experiment.spatial.padHalfWidth];
for i=1:numel(runs)
    ax=nexttile(layout,i); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    patch(ax,pad(1)*[-1 1 1 -1],pad(2)*[-1 -1 1 1],zeros(1,4), ...
        [0.95 0.75 0.10],'FaceAlpha',0.5,'EdgeColor','k');
    for j=1:numel(runs(i).results)
        r=runs(i).results(j);
        x=r.xDrone-r.xPad; y=r.yDrone-r.yPad; z=r.zDrone-r.scenario.padHeight;
        plot3(ax,x,y,z,runs(i).lineStyle,'Color',[runs(i).color,0.55],'LineWidth',1.0);
        plot3(ax,x(1),y(1),z(1),'o','Color',runs(i).color,'MarkerSize',4);
        if strcmp(r.terminalReason,'SUCCESS'), face=runs(i).color; else, face='w'; end
        plot3(ax,x(end),y(end),z(end),'v','Color',runs(i).color, ...
            'MarkerFaceColor',face,'MarkerSize',5);
    end
    view(ax,-35,22);
    xlabel(ax,'x - x_{pad} [m]'); ylabel(ax,'y - y_{pad} [m]'); zlabel(ax,'h [m]');
    title(ax,runs(i).label,'Interpreter','none');
end
end

function plotRates(ax,runs)
values=zeros(numel(runs),4);
for i=1:numel(runs)
    info=getField(runs(i),'info',struct());
    values(i,:)=[fieldOr(info,'landingRate',0),fieldOr(info,'unsafeRate',0), ...
        fieldOr(info,'safeAbortRate',0),fieldOr(info,'meanCaptureRate',0)];
end
bar(ax,100*values); grid(ax,'on'); ylim(ax,[0,100]);
set(ax,'XTick',1:numel(runs),'XTickLabel',{runs.label},'XTickLabelRotation',18);
ylabel(ax,'Rate [%]'); title(ax,'Paired evaluation outcomes');
legend(ax,{'Success','Unsafe','Safe abort','Capture'},'Location','best','Box','off');
end

function plotTraining(ax,runs)
hold(ax,'on'); grid(ax,'on'); box(ax,'on'); found=false;
for i=1:numel(runs)
    training=getField(runs(i),'training',struct());
    if isfield(training,'history'), h=training.history; else, h=[]; end
    if isempty(h), continue; end
    plot(ax,[h.iteration],[h.score],runs(i).lineStyle,'Color',runs(i).color, ...
        'LineWidth',1.6,'DisplayName',runs(i).label); found=true;
end
xlabel(ax,'PPO iteration'); ylabel(ax,'Mean validation return');
title(ax,'Learning trajectory');
if found
    legend(ax,'Location','best','Interpreter','none','Box','off');
else
    text(ax,0.5,0.5,'No training history','Units','normalized', ...
        'HorizontalAlignment','center');
end
end

function plotProfiles(ax,runs)
ms=zeros(1,numel(runs)); params=zeros(1,numel(runs));
for i=1:numel(runs)
    p=getField(runs(i),'profile',struct());
    ms(i)=fieldOr(p,'deployedInferenceMs',fieldOr(p,'policyInferenceMs',NaN));
    params(i)=fieldOr(p,'parameterCount',NaN);
end
bar(ax,ms,'FaceColor','flat'); grid(ax,'on');
set(ax,'XTick',1:numel(runs),'XTickLabel',{runs.label},'XTickLabelRotation',18);
ylabel(ax,'Inference time [ms]'); title(ax,'Deployed policy cost (state + Actor; Critic excluded)');
for i=1:numel(runs)
    if isfinite(params(i)), text(ax,i,ms(i),sprintf('%.0f params',params(i)), ...
            'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8); end
end
end

function plotRgat(ax,runs,label)
info=getField(runs(end),'info',struct());
if isfield(info,'graphSchema') && isstruct(info.graphSchema) ...
        && isfield(info.graphSchema,'nNodes') && ~isempty(info.nodeMean)
    landing2d.viz.plotRgatField(ax,info.graphSchema,info.nodeMean, ...
        info.nodeVariance,info.edgeAttentionMean,'attention',label);
else
    axis(ax,'off'); text(ax,0.5,0.5,'R-GAT diagnostics unavailable', ...
        'Units','normalized','HorizontalAlignment','center'); title(ax,label);
end
end

function value=getField(s,name,fallback)
if isfield(s,name) && ~isempty(s.(name)), value=s.(name); else, value=fallback; end
end

function value=fieldOr(s,name,fallback)
if isstruct(s) && isfield(s,name) && ~isempty(s.(name)), value=s.(name); else, value=fallback; end
end

function textValue=yesNo(value)
if value, textValue='yes'; else, textValue='no'; end
end
