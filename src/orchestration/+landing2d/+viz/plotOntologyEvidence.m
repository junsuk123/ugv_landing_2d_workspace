function [fig,summary] = plotOntologyEvidence(options)
% PLOTONTOLOGYEVIDENCE  Plain-PPO versus ontology-R-GAT evidence only.
% Relation-shuffle is an optional ablation and is intentionally excluded.
if nargin<1, options=struct(); end
root=landing2d.orchestration.projectRoot();
defaults=struct( ...
    'resultFile',fullfile(root,'results','planar_visibility_full.mat'), ...
    'consistencyFile',fullfile(root,'results','consistency','priority_review_test.mat'), ...
    'outputFile',fullfile(root,'results','consistency','ontology_vs_ppo_evidence.png'), ...
    'summaryFile',fullfile(root,'results','consistency','ontology_vs_ppo_summary.csv'), ...
    'visible',true);
names=fieldnames(options);
for i=1:numel(names)
    assert(isfield(defaults,names{i}),'landing2d:OntologyPlotOption', ...
        'Unknown option %s.',names{i});
    defaults.(names{i})=options.(names{i});
end
R=load(defaults.resultFile,'comparison','summaryTable');
C=load(defaults.consistencyFile,'fixed','jerk');
ids=["ppo","onto_rgat_ppo"];
labels={'Plain PPO','Ontology--R-GAT PPO'};
colors=[0.10,0.32,0.62;0.35,0.16,0.60];
mission=zeros(2,4); cost=zeros(2,2);
for i=1:2
    row=R.summaryTable(string(R.summaryTable.MethodId)==ids(i),:);
    mission(i,:)=[100*row.SuccessRate,100*row.UnsafeRate, ...
        100*row.TimeoutRate,row.MeanReturn];
    cost(i,:)=[row.ParameterCount,row.InferenceMs];
end
T=C.fixed.perRun; J=C.jerk.perRun;
state='on'; if ~defaults.visible, state='off'; end
fig=figure('Name','Ontology vs plain PPO evidence','NumberTitle','off', ...
    'Color','w','Position',[40,40,1450,850],'Visible',state);
layout=tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
title(layout,{['Plain PPO vs ontology--R-GAT PPO: equal held-out landing, ' ...
    'higher decision consistency']; ...
    ['Same 12-D observation/reward/PPO budget; graph-only proposal; ' ...
    'one training seed']},'FontWeight','bold');

ax=nexttile(layout,1); grid(ax,'on'); box(ax,'on');
bMission=bar(ax,mission(:,1:3)); ylim(ax,[0,108]); ylabel(ax,'Rate [%]');
set(ax,'XTick',1:2,'XTickLabel',labels);
title(ax,'Held-out mission outcomes (100 episodes)');
legend(ax,{'Landing','Unsafe','Timeout'},'Location','southoutside', ...
    'Orientation','horizontal','Box','off');
for k=1:numel(bMission)
    x=bMission(k).XEndPoints; y=bMission(k).YEndPoints;
    text(ax,x,y+2,compose('%.0f%%',y),'HorizontalAlignment','center', ...
        'FontSize',8,'Color',[0.15 0.15 0.15]);
end
text(ax,1.5,103,sprintf('Mean return: %.2f vs %.2f',mission(1,4),mission(2,4)), ...
    'HorizontalAlignment','center','FontSize',8,'Color',[0.25 0.25 0.25]);

ax=nexttile(layout,2); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for i=1:2
    rows=T(string(T.MethodId)==ids(i),:);
    plot(ax,rows.NoiseScale,rows.C_valid,'-o','Color',colors(i,:), ...
        'MarkerFaceColor',colors(i,:),'LineWidth',2,'DisplayName',labels{i});
end
xlabel(ax,'Sensor-noise scale'); ylabel(ax,'C_{valid} [%]'); ylim(ax,[70,100]);
title(ax,'Admissible-action consistency'); legend(ax,'Location','southwest','Box','off');
text(ax,0.92,93.5,sprintf('+%.2f pp at nominal noise', ...
    nominalDifference(T,ids,'C_valid')),'FontWeight','bold', ...
    'Color',colors(2,:),'HorizontalAlignment','left');

ax=nexttile(layout,3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for i=1:2
    rows=T(string(T.MethodId)==ids(i) & T.NoiseScale>0,:);
    plot(ax,rows.NoiseScale,rows.D_obs_P95,'-o','Color',colors(i,:), ...
        'MarkerFaceColor',colors(i,:),'LineWidth',2,'DisplayName',labels{i});
end
xlabel(ax,'Sensor-noise scale'); ylabel(ax,'D_{obs}, P95');
title(ax,'Tail action sensitivity'); legend(ax,'Location','northwest','Box','off');
text(ax,0.72,0.084,sprintf('%.2f%% lower P95 at nominal noise', ...
    relativeReduction(T,ids,'D_obs_P95',1)),'FontWeight','bold', ...
    'Color',colors(2,:),'HorizontalAlignment','left');

ax=nexttile(layout,4); grid(ax,'on'); box(ax,'on');
jerk=zeros(2,2);
for i=1:2
    row=J(string(J.MethodId)==ids(i),:);
    jerk(i,:)=[row.J_policy,row.J_policy_episodeMean];
end
bar(ax,jerk); ylabel(ax,'J_{policy}');
set(ax,'XTick',1:2,'XTickLabel',labels);
title(ax,'Closed-loop command jerk');
legend(ax,{'Time-pooled','Episode mean'},'Location','southoutside', ...
    'Orientation','horizontal','Box','off');
text(ax,1.5,max(jerk(:))*1.04,sprintf('Time-pooled: %.2f%% lower', ...
    100*(1-jerk(2,1)/jerk(1,1))),'HorizontalAlignment','center', ...
    'FontWeight','bold','Color',colors(2,:));
ylim(ax,[0,max(jerk(:))*1.14]);

ax=nexttile(layout,5); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for i=1:2
    h=R.comparison.training{i}.history;
    plot(ax,[h.iteration],100*[h.landingRate],'-o','Color',colors(i,:), ...
        'LineWidth',1.8,'MarkerSize',3,'DisplayName',labels{i});
end
xlabel(ax,'PPO iteration'); ylabel(ax,'Validation landing [%]'); ylim(ax,[0,100]);
title(ax,'Learning curve'); legend(ax,'Location','southeast','Box','off');

ax=nexttile(layout,6); yyaxis(ax,'left');
b=bar(ax,1:2,cost(:,1)/1000,0.55); b.FaceColor='flat'; b.CData=colors;
ylabel(ax,'Parameters [thousand]'); yyaxis(ax,'right');
plot(ax,1:2,cost(:,2),'-kd','LineWidth',1.8,'MarkerFaceColor','k');
ylabel(ax,'Inference [ms]'); grid(ax,'on'); box(ax,'on');
set(ax,'XTick',1:2,'XTickLabel',labels); title(ax,'Representation cost');
text(ax,1.08,max(cost(:,2))*0.94,sprintf('R-GAT actor: %.3f ms / 100-ms decision', ...
    cost(2,2)),'HorizontalAlignment','center','FontSize',8, ...
    'Color',[0.20 0.20 0.20]);

nominal=zeros(2,2); noise2=zeros(2,2);
for i=1:2
    n=T(string(T.MethodId)==ids(i) & T.NoiseScale==1,:);
    q=T(string(T.MethodId)==ids(i) & T.NoiseScale==2,:);
    nominal(i,:)=[n.C_valid,n.D_obs_P95];
    noise2(i,:)=[q.C_valid,q.D_obs_P95];
end
summary=table(ids',mission(:,1),mission(:,2),mission(:,3),mission(:,4), ...
    nominal(:,1),nominal(:,2),noise2(:,1),noise2(:,2),jerk(:,1), ...
    cost(:,1),cost(:,2),'VariableNames',{'MethodId','LandingPct','UnsafePct', ...
    'TimeoutPct','MeanReturn','C_valid_nominal','D_obs_P95_nominal', ...
    'C_valid_noise2','D_obs_P95_noise2','J_policy','ParameterCount','InferenceMs'});
writetable(summary,defaults.summaryFile);
exportgraphics(layout,defaults.outputFile,'Resolution',220,'BackgroundColor','white');
end

function value=nominalDifference(T,ids,field)
a=T(string(T.MethodId)==ids(1) & T.NoiseScale==1,:);
b=T(string(T.MethodId)==ids(2) & T.NoiseScale==1,:);
value=b.(field)-a.(field);
end

function value=relativeReduction(T,ids,field,scale)
a=T(string(T.MethodId)==ids(1) & T.NoiseScale==scale,:);
b=T(string(T.MethodId)==ids(2) & T.NoiseScale==scale,:);
value=100*(1-b.(field)/a.(field));
end
