function [fig,summary] = plotUnsafeFailureCases(options)
% PLOTUNSAFEFAILURECASES  Held-out unsafe trajectories and terminal margins.
if nargin < 1, options=struct(); end
root=landing2d.orchestration.projectRoot();
defaults=struct( ...
    'resultFile',fullfile(root,'results','planar_visibility_full.mat'), ...
    'outputFile',fullfile(root,'docs','assets','paper','latest_parameter_matched', ...
        'parameter_matched_unsafe_failures.png'), ...
    'pdfOutputFile',fullfile(root,'docs','assets','paper','latest_parameter_matched', ...
        'parameter_matched_unsafe_failures.pdf'), ...
    'summaryFile',fullfile(root,'docs','assets','paper','latest_parameter_matched', ...
        'parameter_matched_unsafe_failures.csv'), ...
    'rawOutputFile',fullfile(root,'results','failure_analysis', ...
        'parameter_matched_unsafe_failures.mat'), ...
    'visible',true,'resolution',240);
defaults=mergeOptions(defaults,options);
R=load(defaults.resultFile,'comparison');
c=landing2d.config.primaryConfig(root);
index=find(cellfun(@(x)string(x.MethodId)=="onto_rgat_ppo",R.comparison.runs),1);
assert(~isempty(index),'landing2d:UnsafeFailureRun','Missing ontology-R-GAT run.');
allResults=R.comparison.testResults{index};
unsafe=find(ismember(string({allResults.terminalReason}), ...
    ["UNSAFE_CONTACT","MISSED_PAD_CONTACT","UNAUTHORIZED_CONTACT", ...
    "SAFETY_ENVELOPE_VIOLATION"]));
assert(~isempty(unsafe),'landing2d:UnsafeFailureCount', ...
    'Expected at least one held-out unsafe failure.');
cases=allResults(unsafe);
nCase=numel(cases);

state='on'; if ~defaults.visible, state='off'; end
fig=figure('Name','Held-out unsafe terminal cases','NumberTitle','off', ...
    'Color','w','Units','pixels','Position',[40,40,1600,900],'Visible',state);
layout=tiledlayout(fig,nCase,2,'TileSpacing','compact','Padding','compact');
title(layout,{ ...
    'Held-out unsafe terminal cases of the parameter-matched Ontology--R-GAT PPO'; ...
    sprintf('%d case among 100 test episodes | terminal quantities normalized by mechanical touchdown limits',nCase)}, ...
    'FontSize',19,'FontWeight','bold');
metricNames={'Position','Horizontal speed','Vertical speed','Pitch','Pitch rate'};
summary=table();
for j=1:nCase
    r=cases(j); ex=r.xPad-r.xDrone; h=r.zDrone-c.padHeight;
    relVx=r.vxPad-r.vxDrone;
    ratios=[abs(ex(end))/c.padHalfLength, ...
        abs(relVx(end))/c.experiment.safety.touchdownSpeedX, ...
        abs(r.vzDrone(end))/c.experiment.safety.touchdownSpeedZ, ...
        abs(r.theta(end))/c.experiment.safety.touchdownPitchTolerance, ...
        abs(r.pitchRate(end))/c.experiment.safety.touchdownPitchRateTolerance];
    [peakRatio,dominant]=max(ratios);
    cause=string(metricNames{dominant});
    summary=[summary;table(r.seed,string(r.terminalReason),r.time(end), ...
        ex(end),relVx(end),r.vzDrone(end),rad2deg(r.theta(end)), ...
        rad2deg(r.pitchRate(end)),cause,peakRatio, ...
        'VariableNames',{'Seed','TerminalReason','TerminalTime_s','PositionError_m', ...
        'RelativeVx_mps','Vz_mps','Pitch_deg','PitchRate_degps', ...
        'DominantViolation','PeakNormalizedViolation'})]; %#ok<AGROW>

    ax=nexttile(layout,2*j-1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    plot(ax,ex,h,'Color',[0.35,0.16,0.60],'LineWidth',3);
    plot(ax,ex(1),h(1),'o','MarkerFaceColor',[0.20,0.62,0.42], ...
        'MarkerEdgeColor','none','MarkerSize',9);
    plot(ax,ex(end),h(end),'x','Color',[0.82,0.20,0.18], ...
        'LineWidth',3,'MarkerSize',13);
    xline(ax,-c.padHalfLength,'--','Color',[0.45,0.45,0.45]);
    xline(ax,c.padHalfLength,'--','Color',[0.45,0.45,0.45]);
    yline(ax,c.experiment.safety.touchdownHeight,':','Contact height', ...
        'Color',[0.82,0.20,0.18],'LabelHorizontalAlignment','left');
    xlabel(ax,'Pad minus drone x [m]','FontSize',15,'FontWeight','bold');
    ylabel(ax,'Height above pad [m]','FontSize',15,'FontWeight','bold');
    title(ax,sprintf('Case %d trajectory | seed %d | %s',j,r.seed, ...
        strrep(r.terminalReason,'_',' ')),'FontSize',17,'FontWeight','bold');
    set(ax,'FontSize',13,'LineWidth',1.1);
    text(ax,0.02,0.96,sprintf('t = %.2f s | return = %.2f',r.time(end),r.return), ...
        'Units','normalized','VerticalAlignment','top','FontSize',13);

    ax=nexttile(layout,2*j); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    b=bar(ax,1:5,ratios,0.62,'FaceColor','flat');
    b.CData=repmat([0.20,0.62,0.42],5,1);
    b.CData(ratios>1,:)=repmat([0.82,0.20,0.18],sum(ratios>1),1);
    yline(ax,1,'--k','Mechanical limit','LineWidth',1.8, ...
        'LabelHorizontalAlignment','left');
    set(ax,'XTick',1:5,'XTickLabel',metricNames,'XTickLabelRotation',18, ...
        'FontSize',12,'LineWidth',1.1);
    ylabel(ax,'Terminal magnitude / allowed limit','FontSize',14,'FontWeight','bold');
    title(ax,sprintf('Dominant violation: %s (%.2fx limit)',cause,peakRatio), ...
        'FontSize',16,'FontWeight','bold');
    ylim(ax,[0,max(1.25,max(ratios)*1.22)]);
    for k=1:5
        text(ax,k,ratios(k)+0.035*ylim(ax)*[0;1],sprintf('%.2f',ratios(k)), ...
            'HorizontalAlignment','center','FontWeight','bold','FontSize',11);
    end
end
ensureParent(defaults.outputFile); ensureParent(defaults.pdfOutputFile);
ensureParent(defaults.summaryFile); ensureParent(defaults.rawOutputFile);
writetable(summary,defaults.summaryFile);
save(defaults.rawOutputFile,'cases','summary','-v7.3');
exportFigure(fig,defaults.outputFile,defaults.resolution,'png');
exportFigure(fig,defaults.pdfOutputFile,defaults.resolution,'pdf');
end

function out=mergeOptions(out,in)
names=fieldnames(in);
for i=1:numel(names)
    assert(isfield(out,names{i}),'landing2d:UnsafeFailurePlotOption', ...
        'Unknown option %s.',names{i});
    out.(names{i})=in.(names{i});
end
end

function ensureParent(file)
folder=fileparts(file); if ~exist(folder,'dir'), mkdir(folder); end
end

function exportFigure(fig,file,resolution,kind)
try
    if strcmp(kind,'pdf')
        exportgraphics(fig,file,'ContentType','vector','BackgroundColor','white');
    else
        exportgraphics(fig,file,'Resolution',resolution,'BackgroundColor','white');
    end
catch
    if strcmp(kind,'pdf'), print(fig,file,'-dpdf','-painters','-bestfit');
    else, print(fig,file,'-dpng',sprintf('-r%d',resolution)); end
end
end
