function figures = plotStudy(study,options)
% PLOTSTUDY  Create reproducible manuscript figures from paper validation.
if nargin < 2, options=struct(); end
options = localDefaults(options,struct('figureVisible',true, ...
    'outputDir',fullfile(study.config.outputDir,'paper'), ...
    'saveFigures',true,'exportPdf',false,'resolution',300, ...
    'figureSet',{{'trajectories','stability','feasibility','ontology'}}));
visibility = 'off'; if options.figureVisible, visibility='on'; end
colors = [0.10 0.32 0.62; 0.85 0.33 0.10; 0.35 0.16 0.60];
requested=cellstr(options.figureSet);
allowed={'trajectories','stability','feasibility','ontology'};
assert(all(ismember(requested,allowed)),'landing2d:PaperFigureSet', ...
    'figureSet contains an unsupported figure name.');

figures = struct();
if ismember('trajectories',requested)
    if landing2d.environment.isSpatial(study.config)
        figures.trajectories = trajectoryFigure3d(study,visibility,colors);
    else
        figures.trajectories = trajectoryFigure(study,visibility,colors);
    end
end
if ismember('stability',requested)
    figures.stability = stabilityFigure(study,visibility,colors);
end
if ismember('feasibility',requested)
    figures.feasibility = feasibilityFigure(study,visibility,colors);
end
if ismember('ontology',requested)
    figures.ontology = ontologyFigure(study,visibility,colors(3,:));
end
if options.saveFigures
    outputDir = char(options.outputDir);
    if ~exist(outputDir,'dir'), mkdir(outputDir); end
    names = fieldnames(figures);
    for i = 1:numel(names)
        saveOne(figures.(names{i}),fullfile(outputDir, ...
            ['paper_' names{i}]),options);
    end
end
end
function fig = trajectoryFigure(study,visibility,colors)
fig = figure('Name','Paper: representative landing trajectories', ...
    'Color','w','Visible',visibility,'Position',[50 40 1500 1050]);
layout = tiledlayout(fig,numel(study.scenarios),2, ...
    'TileSpacing','compact','Padding','compact');
title(layout,['Final-policy comparison on fixed ontology-aligned scenarios' newline ...
    'Left: pad-relative flight path; right: signed tracking error and CV-CA-CV phases']);
[globalX,globalH] = trajectoryLimits(study);
for s = 1:numel(study.scenarios)
    spec = study.scenarios(s);
    feasibility = study.scenarioTable(s,:);
    ax = nexttile(layout,2*s-1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    hReference = linspace(0,globalH(2),100);
    % Level-attitude FOV edges in pad-relative coordinates, including the
    % camera's optical-axis tilt (x_drone - x_pad = h*tan(offset -/+ fov/2)).
    sensor = study.config.experiment.sensor;
    for edge = [-1,1]
        plot(ax,hReference*tan(sensor.cameraPitchOffset+edge*sensor.fov/2), ...
            hReference,':','Color',[.55 .55 .55],'HandleVisibility','off');
    end
    for m = 1:numel(study.modes)
        r = study.results{s,m};
        xRelative = r.xDrone-r.xPad;
        height = r.zDrone-spec.scenario.padHeight;
        metric = metricRow(study,s,m);
        label = sprintf('%s | %s | inhibit: %s',study.labels{m}, ...
            char(metric.TerminalReason),char(metric.DominantInhibitCause));
        plot(ax,xRelative,height,'LineWidth',1.65,'Color',colors(m,:), ...
            'DisplayName',label);
        plot(ax,xRelative(1),height(1),'o','Color',colors(m,:), ...
            'MarkerFaceColor','w','HandleVisibility','off');
        plot(ax,xRelative(end),height(end),'v','Color',colors(m,:), ...
            'MarkerFaceColor',colors(m,:),'HandleVisibility','off');
    end
    yline(ax,study.config.experiment.safety.touchdownHeight,'--', ...
        'Touchdown height','Color',[.25 .25 .25],'HandleVisibility','off');
    xlim(ax,globalX); ylim(ax,globalH);
    xlabel(ax,'Drone position relative to pad [m]'); ylabel(ax,'Height above pad [m]');
    title(ax,sprintf('%s | physical: %s | v margin %.2f m/s', ...
        spec.name,char(feasibility.PhysicalCause),feasibility.SpeedMargin_mps));
    if s==1, legend(ax,'Location','northeast','FontSize',8); end

    ax = nexttile(layout,2*s); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    xMax = 0;
    for m = 1:numel(study.modes)
        r = study.results{s,m};
        plot(ax,r.time,r.xPad-r.xDrone,'LineWidth',1.45, ...
            'Color',colors(m,:),'DisplayName',study.labels{m});
        xMax=max(xMax,r.time(end));
    end
    yLimits = paddedLimits(cellfun(@(r)r.xPad-r.xDrone, ...
        study.results(s,:),'UniformOutput',false));
    ylim(ax,yLimits); xlim(ax,[0,max(xMax,eps)]);
    addPhaseBackground(ax,spec.scenario,yLimits,xMax);
    yline(ax,0,'-','Color',[.25 .25 .25],'HandleVisibility','off');
    xlabel(ax,'Time [s]'); ylabel(ax,'Pad - drone horizontal error [m]');
    title(ax,sprintf('%s: %s',spec.id,spec.challenge));
    if s==1, legend(ax,'Location','best','FontSize',8); end
end
end

function fig = trajectoryFigure3d(study,visibility,colors)
% 3D option: pad-relative 3D flight path and signed x/y tracking errors.
fig = figure('Name','Paper: representative 3D landing trajectories', ...
    'Color','w','Visible',visibility,'Position',[50 40 1500 1050]);
layout = tiledlayout(fig,numel(study.scenarios),2, ...
    'TileSpacing','compact','Padding','compact');
title(layout,['Final-policy comparison on fixed ontology-aligned 3D scenarios' newline ...
    'Left: pad-relative 3D flight path; right: signed x (solid) / y (dashed) tracking error']);
pad = [study.config.padHalfLength,study.config.experiment.spatial.padHalfWidth];
for s = 1:numel(study.scenarios)
    spec = study.scenarios(s);
    feasibility = study.scenarioTable(s,:);
    ax = nexttile(layout,2*s-1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    patch(ax,pad(1)*[-1 1 1 -1],pad(2)*[-1 -1 1 1],zeros(1,4), ...
        [0.95 0.75 0.10],'FaceAlpha',0.5,'EdgeColor','k','HandleVisibility','off');
    for m = 1:numel(study.modes)
        r = study.results{s,m};
        xRelative = r.xDrone-r.xPad;
        yRelative = r.yDrone-r.yPad;
        height = r.zDrone-spec.scenario.padHeight;
        metric = metricRow(study,s,m);
        label = sprintf('%s | %s',study.labels{m},char(metric.TerminalReason));
        plot3(ax,xRelative,yRelative,height,'LineWidth',1.65, ...
            'Color',colors(m,:),'DisplayName',label);
        plot3(ax,xRelative(1),yRelative(1),height(1),'o','Color',colors(m,:), ...
            'MarkerFaceColor','w','HandleVisibility','off');
        plot3(ax,xRelative(end),yRelative(end),height(end),'v', ...
            'Color',colors(m,:),'MarkerFaceColor',colors(m,:),'HandleVisibility','off');
    end
    view(ax,-35,22); zlim(ax,[0,max(8.5,ax.ZLim(2))]);
    xlabel(ax,'x - x_{pad} [m]'); ylabel(ax,'y - y_{pad} [m]');
    zlabel(ax,'Height above pad [m]');
    title(ax,sprintf('%s | physical: %s | v margin %.2f m/s', ...
        spec.name,char(feasibility.PhysicalCause),feasibility.SpeedMargin_mps));
    if s==1, legend(ax,'Location','northeast','FontSize',8,'Interpreter','none'); end

    ax = nexttile(layout,2*s); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    xMax = 0; series = {};
    for m = 1:numel(study.modes)
        r = study.results{s,m};
        plot(ax,r.time,r.xPad-r.xDrone,'-','LineWidth',1.45, ...
            'Color',colors(m,:),'DisplayName',[study.labels{m} ' (x)']);
        plot(ax,r.time,r.yPad-r.yDrone,'--','LineWidth',1.2, ...
            'Color',colors(m,:),'DisplayName',[study.labels{m} ' (y)']);
        series = [series,{r.xPad-r.xDrone,r.yPad-r.yDrone}]; %#ok<AGROW>
        xMax=max(xMax,r.time(end));
    end
    yLimits = paddedLimits(series);
    ylim(ax,yLimits); xlim(ax,[0,max(xMax,eps)]);
    addPhaseBackground(ax,spec.scenario,yLimits,xMax);
    yline(ax,0,'-','Color',[.25 .25 .25],'HandleVisibility','off');
    xlabel(ax,'Time [s]'); ylabel(ax,'Pad - drone error [m]');
    title(ax,sprintf('%s: %s | v_{y1}=%.2f, a_{y2}=%.2f',spec.id,spec.challenge, ...
        spec.scenario.vy1,spec.scenario.ay2));
    if s==1, legend(ax,'Location','northeast','FontSize',7,'NumColumns',2); end
end
end

function fig = stabilityFigure(study,visibility,colors)
fig = figure('Name','Paper: stability metrics','Color','w', ...
    'Visible',visibility,'Position',[80 60 1450 900]);
layout = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
title(layout,['Landing stability metrics (fixed scenarios; arrows show direction)' newline ...
    'Stability index excludes return and terminal outcome']);
variables = {'StabilityIndex','TrackingRMSE_m','RelativeSpeedRMSE_mps', ...
    'MeasuredFOVLoss_pct','SupervisorIntervention_pct','ControlJerkRMS_mps3'};
titles = {'Stability index [0-100] \uparrow','Tracking RMSE [m] \downarrow', ...
    'Relative-speed RMSE [m/s] \downarrow','Measured FOV loss [%] \downarrow', ...
    'Supervisor intervention [%] \downarrow','Control jerk RMS [m/s^3] \downarrow'};
for k = 1:numel(variables)
    ax=nexttile(layout); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    values=metricMatrix(study,variables{k});
    bars=bar(ax,values,'grouped');
    for m=1:numel(bars), bars(m).FaceColor=colors(m,:); end
    xticks(ax,1:numel(study.scenarios)); xticklabels(ax,{study.scenarios.id});
    ylabel(ax,titles{k}); title(ax,titles{k});
    if k==1, legend(ax,study.labels,'Location','best','FontSize',8); end
end
end

function fig = feasibilityFigure(study,visibility,colors)
fig = figure('Name','Paper: feasibility and landing inhibit audit', ...
    'Color','w','Visible',visibility,'Position',[100 80 1450 850]);
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
title(layout,['Physical feasibility is policy-independent; LandingInhibit is a temporary ontology decision' newline ...
    'Positive authority margin = physically feasible under the declared scenario contract']);
labels={study.scenarios.id};
ax=nexttile(layout); bar(ax,study.scenarioTable.SpeedMargin_mps, ...
    'FaceColor',[.20 .55 .35]); grid(ax,'on'); yline(ax,0,'r--');
xticks(ax,1:numel(labels)); xticklabels(ax,labels);
ylabel(ax,'Speed authority margin [m/s]'); title(ax,'Peak-speed feasibility');
ax=nexttile(layout); bar(ax,study.scenarioTable.AccelerationMargin_mps2, ...
    'FaceColor',[.20 .55 .35]); grid(ax,'on'); yline(ax,0,'r--');
xticks(ax,1:numel(labels)); xticklabels(ax,labels);
ylabel(ax,'Acceleration authority margin [m/s^2]'); title(ax,'Acceleration feasibility');
ax=nexttile(layout); hold(ax,'on'); grid(ax,'on');
bars=bar(ax,metricMatrix(study,'LandingInhibit_pct'),'grouped');
for m=1:numel(bars), bars(m).FaceColor=colors(m,:); end
xticks(ax,1:numel(labels)); xticklabels(ax,labels);
ylabel(ax,'LandingInhibit duration [%]'); title(ax,'Operational landing inhibition');
legend(ax,study.labels,'Location','best','FontSize',8);
ax=nexttile(layout); hold(ax,'on'); grid(ax,'on');
rgatRows = study.metricTable(study.metricTable.StateRepresentation=="context_rgat",:);
causes=[rgatRows.InhibitDropout_s,rgatRows.InhibitTrajectoryFOV_s, ...
    rgatRows.InhibitRelativeSpeed_s,rgatRows.InhibitUncertainty_s];
bar(ax,causes,'stacked'); xticks(ax,1:numel(labels)); xticklabels(ax,labels);
ylabel(ax,'Inhibited time [s]'); title(ax,'R-GAT inhibit cause audit');
legend(ax,{'Sensor dropout','Trajectory/FOV','Relative speed','Uncertainty/gate'}, ...
    'Location','best','FontSize',8);
for s=1:height(rgatRows)
    text(ax,s,sum(causes(s,:))+0.02,char(rgatRows.DominantInhibitCause(s)), ...
        'HorizontalAlignment','center','FontSize',8);
end
end

function fig = ontologyFigure(study,visibility,color)
fig=figure('Name','Paper: ontology R-GAT decision traces','Color','w', ...
    'Visible',visibility,'Position',[120 100 1450 850]);
layout=tiledlayout(fig,numel(study.scenarios),1, ...
    'TileSpacing','compact','Padding','compact');
title(layout,['Ontology R-GAT policy trace: causal graph signals and relation-residual audit' newline ...
    relationAuditText(study)]);
m=find(strcmp(study.modes,'context_rgat'),1);
for s=1:numel(study.scenarios)
    ax=nexttile(layout); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    tr=study.trajectories{s,m}; r=study.results{s,m}; n=tr.count; t=r.time(1:n);
    inhibit=landing2d.paper.inhibitedRecord(tr,study.config);
    visible=double(r.visible(1:n));
    yyaxis(ax,'left');
    stairs(ax,t,tr.descentEligibility,'LineWidth',1.4,'Color',[.15 .55 .25], ...
        'DisplayName','Descent eligibility');
    stairs(ax,t,double(inhibit),'LineWidth',1.2,'Color',[.85 .20 .15], ...
        'DisplayName','Landing inhibit');
    stairs(ax,t,visible,'--','LineWidth',1.1,'Color',[.10 .35 .70], ...
        'DisplayName','Pad detected');
    stairs(ax,t,double(tr.verticalGateActive),':','LineWidth',1.3, ...
        'Color',[.20 .20 .20],'DisplayName','Vertical gate active');
    ylim(ax,[-.05 1.05]); ylabel(ax,'Graph / gate signal');
    yyaxis(ax,'right');
    plot(ax,t,tr.relationResidual(end,:),'LineWidth',1.4,'Color',color, ...
        'DisplayName','R-GAT vertical residual');
    ylabel(ax,'Vertical action residual');
    events=study.scenarios(s).sensorEvents;
    if isfinite(events.dropoutStart)
        xline(ax,events.dropoutStart,'k--','Dropout start','HandleVisibility','off');
        xline(ax,events.dropoutEnd,'k--','Dropout end','HandleVisibility','off');
    end
    xlabel(ax,'Time [s]');
    title(ax,sprintf('%s | %s | terminal: %s',study.scenarios(s).name, ...
        study.scenarios(s).ontologyPath,r.terminalReason));
    if s==1, legend(ax,'Location','eastoutside','FontSize',8); end
end

function textValue=relationAuditText(study)
row=study.architectureAudit( ...
    study.architectureAudit.StateRepresentation=="context_rgat",:);
if isempty(row) || row.RelationalPathActive
    state='ACTIVE';
else
    state='INACTIVE (selected checkpoint uses the raw semantic bypass)';
end
textValue=sprintf(['Relational path: %s | Wg policy %.3g / value %.3g | ' ...
    'dashed lines mark prescribed detector dropout'],state, ...
    row.PolicyGraphReadoutNorm,row.ValueGraphReadoutNorm);
end
end

function row=metricRow(study,s,m)
row=study.metricTable(study.metricTable.Scenario==string(study.scenarios(s).id) & ...
    study.metricTable.StateRepresentation==string(study.modes{m}),:);
end

function values=metricMatrix(study,variable)
values=nan(numel(study.scenarios),numel(study.modes));
for s=1:numel(study.scenarios)
    for m=1:numel(study.modes)
        row=metricRow(study,s,m); values(s,m)=row.(variable);
    end
end
end

function [xLimits,hLimits]=trajectoryLimits(study)
allX=[]; allH=[];
for i=1:numel(study.results)
    r=study.results{i}; s=r.scenario;
    allX=[allX,r.xDrone-r.xPad]; %#ok<AGROW>
    allH=[allH,r.zDrone-s.padHeight]; %#ok<AGROW>
end
padX=max(0.5,0.05*max(max(allX)-min(allX),1));
xLimits=[min(allX)-padX,max(allX)+padX];
hLimits=[0,max(8.5,max(allH)+0.5)];
end

function limits=paddedLimits(series)
values=[series{:}]; lo=min(values); hi=max(values);
padding=max(0.5,0.08*max(hi-lo,1)); limits=[lo-padding,hi+padding];
end

function addPhaseBackground(ax,scenario,yLimits,xMax)
edges=[0,scenario.T1,scenario.T1+scenario.T2,xMax];
colors=[.82 .90 1.00; 1.00 .90 .76; .84 .96 .88];
for k=1:3
    if edges(k+1)<=edges(k), continue; end
    p=patch(ax,[edges(k) edges(k+1) edges(k+1) edges(k)], ...
        [yLimits(1) yLimits(1) yLimits(2) yLimits(2)],colors(k,:), ...
        'FaceAlpha',0.18,'EdgeColor','none','HandleVisibility','off');
    uistack(p,'bottom');
end
xline(ax,scenario.T1,':','CA start','HandleVisibility','off');
xline(ax,scenario.T1+scenario.T2,':','CV3 start','HandleVisibility','off');
end

function saveOne(fig,base,options)
exportgraphics(fig,[base '.png'],'Resolution',options.resolution);
if options.exportPdf
    try
        exportgraphics(fig,[base '.pdf'],'ContentType','vector');
    catch
        exportgraphics(fig,[base '.pdf'],'ContentType','image', ...
            'Resolution',options.resolution);
    end
end
end

function options=localDefaults(options,defaults)
keys=fieldnames(defaults);
for i=1:numel(keys)
    if ~isfield(options,keys{i}), options.(keys{i})=defaults.(keys{i}); end
end
end
