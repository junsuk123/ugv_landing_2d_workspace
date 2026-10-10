function [fig,summary] = plotParameterMatchedConsistency(options)
% PLOTPARAMETERMATCHEDCONSISTENCY  C_valid, D_obs P95 and J_policy for slides.
if nargin < 1, options=struct(); end
root=landing2d.orchestration.projectRoot();
defaults=struct( ...
    'resultFile',fullfile(root,'results','consistency', ...
        'parameter_matched_consistency.mat'), ...
    'outputFile',fullfile(root,'docs','assets','paper','latest_parameter_matched', ...
        'parameter_matched_consistency.png'), ...
    'pdfOutputFile',fullfile(root,'docs','assets','paper','latest_parameter_matched', ...
        'parameter_matched_consistency.pdf'), ...
    'figOutputFile',fullfile(root,'docs','assets','paper','latest_parameter_matched', ...
        'parameter_matched_consistency.fig'), ...
    'summaryFile',fullfile(root,'docs','assets','paper','latest_parameter_matched', ...
        'parameter_matched_consistency.csv'), ...
    'visible',true,'resolution',240);
defaults=mergeOptions(defaults,options);
C=load(defaults.resultFile,'fixed','jerk');
ids=["ppo","onto_rgat_ppo"];
labels={'Plain PPO','Ontology--R-GAT PPO (6,101 parameters)'};
colors=[0.10,0.32,0.62;0.35,0.16,0.60];
T=C.fixed.perRun; J=C.jerk.perRun;
assert(all(ismember(ids,string(T.MethodId))) && all(ismember(ids,string(J.MethodId))), ...
    'landing2d:ConsistencyResult','Both final comparison runs are required.');

state='on'; if ~defaults.visible, state='off'; end
fig=figure('Name','Parameter-matched consistency evidence','NumberTitle','off', ...
    'Color','w','Units','pixels','Position',[30,30,1800,820],'Visible',state);
layout=tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
title(layout,{ ...
    'Consistency re-evaluation of the parameter-matched Ontology--R-GAT PPO'; ...
    'Held-out mission outcomes (n=100): PPO 95% landing / 0% unsafe / 5% timeout | R-GAT 96% / 1% / 3%'}, ...
    'FontSize',18,'FontWeight','bold');

ax=nexttile(layout,1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for i=1:2
    q=T(string(T.MethodId)==ids(i),:);
    plot(ax,q.NoiseScale,q.C_valid,'-o','Color',colors(i,:), ...
        'MarkerFaceColor',colors(i,:),'LineWidth',3,'MarkerSize',9, ...
        'DisplayName',labels{i});
end
xlabel(ax,'Sensor-noise scale','FontWeight','bold');
ylabel(ax,'C_{valid} [%]','FontWeight','bold');
title(ax,'A  Admissible-action consistency','FontWeight','bold');
legend(ax,'Location','southwest','Box','off','FontSize',13);
set(ax,'FontSize',15,'LineWidth',1.1);
nominalA=T(string(T.MethodId)==ids(1) & T.NoiseScale==1,:);
nominalB=T(string(T.MethodId)==ids(2) & T.NoiseScale==1,:);
text(ax,0.97,0.96,sprintf('Nominal: %+.2f pp',nominalB.C_valid-nominalA.C_valid), ...
    'Units','normalized','HorizontalAlignment','right','VerticalAlignment','top', ...
    'FontSize',14,'FontWeight','bold','Color',colors(2,:));

ax=nexttile(layout,2); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for i=1:2
    q=T(string(T.MethodId)==ids(i) & T.NoiseScale>0,:);
    plot(ax,q.NoiseScale,q.D_obs_P95,'-o','Color',colors(i,:), ...
        'MarkerFaceColor',colors(i,:),'LineWidth',3,'MarkerSize',9, ...
        'DisplayName',labels{i});
end
xlabel(ax,'Sensor-noise scale','FontWeight','bold');
ylabel(ax,'D_{obs}, P95','FontWeight','bold');
title(ax,'B  Tail action sensitivity','FontWeight','bold');
legend(ax,'Location','northwest','Box','off','FontSize',13);
set(ax,'FontSize',15,'LineWidth',1.1);
text(ax,0.97,0.08,sprintf('Nominal: %+.1f%%', ...
    100*(nominalB.D_obs_P95/nominalA.D_obs_P95-1)), ...
    'Units','normalized','HorizontalAlignment','right','VerticalAlignment','bottom', ...
    'FontSize',14,'FontWeight','bold','Color',colors(2,:));

jerk=zeros(2,2);
for i=1:2
    q=J(string(J.MethodId)==ids(i),:);
    jerk(i,:)=[q.J_policy,q.J_policy_episodeMean];
end
ax=nexttile(layout,3); grid(ax,'on'); box(ax,'on');
b=bar(ax,jerk,'grouped'); b(1).FaceColor=[0.20,0.52,0.74];
b(2).FaceColor=[0.55,0.28,0.70];
set(ax,'XTick',1:2,'XTickLabel',{'Plain PPO','Matched R-GAT'}, ...
    'FontSize',15,'LineWidth',1.1);
ylabel(ax,'J_{policy} [m/s^3]','FontWeight','bold');
title(ax,'C  Closed-loop command jerk','FontWeight','bold');
legend(ax,{'Time-pooled','Episode mean'},'Location','northwest', ...
    'Orientation','vertical','Box','off','FontSize',13);
for k=1:numel(b)
    text(ax,b(k).XEndPoints,b(k).YEndPoints,compose('  %.2f',b(k).YEndPoints), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontWeight','bold','FontSize',12);
end
text(ax,0.50,0.82,sprintf('Pooled jerk: %+.1f%%',100*(jerk(2,1)/jerk(1,1)-1)), ...
    'Units','normalized','HorizontalAlignment','center','VerticalAlignment','top', ...
    'FontSize',14,'FontWeight','bold','Color',colors(2,:));

summary=T(:,{'MethodId','NoiseScale','C_valid','D_obs_mean','D_obs_P95'});
summary.J_policy=NaN(height(summary),1);
summary.J_policy_episodeMean=NaN(height(summary),1);
for i=1:2
    mask=string(summary.MethodId)==ids(i) & summary.NoiseScale==1;
    q=J(string(J.MethodId)==ids(i),:);
    summary.J_policy(mask)=q.J_policy;
    summary.J_policy_episodeMean(mask)=q.J_policy_episodeMean;
end
ensureParent(defaults.outputFile); ensureParent(defaults.pdfOutputFile);
ensureParent(defaults.figOutputFile);
ensureParent(defaults.summaryFile); writetable(summary,defaults.summaryFile);
exportFigure(fig,defaults.outputFile,defaults.resolution,'png');
exportFigure(fig,defaults.pdfOutputFile,defaults.resolution,'pdf');
savefig(fig,defaults.figOutputFile);
end

function out=mergeOptions(out,in)
names=fieldnames(in);
for i=1:numel(names)
    assert(isfield(out,names{i}),'landing2d:ConsistencyPlotOption', ...
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
