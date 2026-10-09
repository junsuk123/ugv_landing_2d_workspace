function fig = plotConsistencyAdvantage(reviewFile,outputFile,visible)
% PLOTCONSISTENCYADVANTAGE  Plot fixed-probe evidence for ontology-RGAT.
% The figure deliberately pairs consistency metrics with mission outcomes:
% C_valid must not be presented as a standalone performance claim.
if nargin<1 || isempty(reviewFile)
    root=landing2d.orchestration.projectRoot();
    reviewFile=fullfile(root,'results','consistency','priority_review_test.mat');
end
if nargin<2 || isempty(outputFile)
    outputFile=fullfile(fileparts(reviewFile),'ontology_rgat_advantage.png');
end
if nargin<3, visible=true; end
d=load(reviewFile,'fixed','jerk');
T=d.fixed.perRun; J=d.jerk.perRun;
ids=["ppo","onto_rgat_ppo"];
labels={'Plain PPO','Ontology-RGAT PPO'};
colors=[0.10,0.32,0.62;0.85,0.33,0.10];
assert(all(ismember(ids,string(T.MethodId))) && all(ismember(ids,string(J.MethodId))), ...
    'landing2d:ConsistencyPlot','The review file does not contain both methods.');

state='on'; if ~visible, state='off'; end
fig=figure('Name','Ontology-RGAT consistency advantage','NumberTitle','off', ...
    'Color','w','Position',[80,80,1380,820],'Visible',state);
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
title(layout,['Ontology-RGAT advantage on fixed test probes ' ...
    '(train seed 1; mission outcomes shown as a required control)'], ...
    'FontWeight','bold');

ax=nexttile(layout,1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for i=1:2
    rows=T(string(T.MethodId)==ids(i),:);
    plot(ax,rows.NoiseScale,rows.C_valid,'-o','Color',colors(i,:), ...
        'MarkerFaceColor',colors(i,:),'LineWidth',2,'DisplayName',labels{i});
end
xlabel(ax,'Sensor-noise scale'); ylabel(ax,'C_{valid} [%]');
title(ax,'Admissible-action consistency (higher is better)');
legend(ax,'Location','southwest','Box','off'); ylim(ax,[65,100]);

ax=nexttile(layout,2); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for i=1:2
    rows=T(string(T.MethodId)==ids(i) & T.NoiseScale>0,:);
    plot(ax,rows.NoiseScale,rows.D_obs_mean,'-o','Color',colors(i,:), ...
        'MarkerFaceColor',colors(i,:),'LineWidth',2, ...
        'DisplayName',[labels{i},' mean']);
    plot(ax,rows.NoiseScale,rows.D_obs_P95,'--','Color',colors(i,:), ...
        'LineWidth',1.5,'DisplayName',[labels{i},' P95']);
end
xlabel(ax,'Sensor-noise scale'); ylabel(ax,'Normalized action change');
title(ax,'Observation sensitivity D_{obs} (lower is better)');
legend(ax,'Location','northwest','Box','off');

ax=nexttile(layout,3); grid(ax,'on'); box(ax,'on');
pooled=zeros(2,1); episodeMean=zeros(2,1);
for i=1:2
    row=J(string(J.MethodId)==ids(i),:);
    pooled(i)=row.J_policy; episodeMean(i)=row.J_policy_episodeMean;
end
b=bar(ax,[pooled,episodeMean]);
b(1).FaceColor=[0.25,0.55,0.75]; b(2).FaceColor=[0.65,0.75,0.85];
set(ax,'XTick',1:2,'XTickLabel',labels,'XTickLabelRotation',12);
ylabel(ax,'J_{policy}'); title(ax,'Closed-loop policy jerk (lower is better)');
legend(ax,{'Time-pooled','Episode mean'},'Location','best','Box','off');

ax=nexttile(layout,4); grid(ax,'on'); box(ax,'on');
outcomes=zeros(2,3);
for i=1:2
    row=J(string(J.MethodId)==ids(i),:);
    outcomes(i,:)=[row.LandingPct,row.UnsafePct,row.TimeoutPct];
end
bar(ax,outcomes); set(ax,'XTick',1:2,'XTickLabel',labels, ...
    'XTickLabelRotation',12); ylim(ax,[0,100]); ylabel(ax,'Rate [%]');
title(ax,'Held-out mission outcomes (performance control)');
legend(ax,{'Landing','Unsafe','Timeout'},'Location','best','Box','off');
text(ax,1.5,84,'Landing: 95% vs 95% — no mission-success gain', ...
    'HorizontalAlignment','center','FontWeight','bold');

exportgraphics(layout,outputFile,'Resolution',220,'BackgroundColor','white');
end
