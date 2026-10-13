function [fig,summary] = plotParameterMatchedConsistency(options)
% PLOTPARAMETERMATCHEDCONSISTENCY  Final v3.19 trajectory robustness plot.
% The current evidence is the validation 20-seed x 20-noise-repeat study.
if nargin < 1, options=struct(); end
root=landing2d.orchestration.projectRoot();
defaults=struct( ...
    'resultFile',fullfile(root,'results','checkpoints','experiments', ...
        'moderate_reliability_v319','validation_trajectory_robustness.csv'), ...
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
summary=readtable(defaults.resultFile,'TextType','string');
assert(height(summary)==2,'landing2d:TrajectoryRobustnessResult', ...
    'Expected PPO and final ontology-R-GAT rows.');
reference=find(contains(summary.Candidate,"PPO",'IgnoreCase',true) & ...
    ~contains(summary.Candidate,"R-GAT",'IgnoreCase',true),1);
proposal=find(contains(summary.Candidate,"R-GAT",'IgnoreCase',true),1);
assert(~isempty(reference) && ~isempty(proposal), ...
    'landing2d:TrajectoryRobustnessResult', ...
    'The final validation summary must contain PPO and ontology-R-GAT.');
order=[reference,proposal]; summary=summary(order,:);
labels={'Plain PPO','Ontology--R-GAT PPO v3.19'};
colors=[0.10,0.32,0.62;0.35,0.16,0.60];

state='on'; if ~defaults.visible, state='off'; end
fig=figure('Name','Final v3.19 trajectory robustness','NumberTitle','off', ...
    'Color','w','Units','pixels','Position',[30,30,1800,820],'Visible',state);
layout=tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
title(layout,{ ...
    'Final v3.19 Validation Trajectory Robustness'; ...
    '20 physical seeds × 20 paired sensor-noise repeats per seed | 400 runs per method | train seed 1'}, ...
    'FontSize',18,'FontWeight','bold');

ax=nexttile(layout,1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
landing=100*summary.SuccessRate;
b=bar(ax,1:2,landing,0.55,'FaceColor','flat'); b.CData=colors;
ylim(ax,[0,105]); ylabel(ax,'Successful landings [%]','FontWeight','bold');
set(ax,'XTick',1:2,'XTickLabel',{'Plain PPO','v3.19'}, ...
    'FontSize',14,'LineWidth',1.1);
title(ax,'A  Validation mission outcome','FontWeight','bold');
for i=1:2
    text(ax,i,landing(i)+1.8,sprintf('%.2f%%',landing(i)), ...
        'HorizontalAlignment','center','FontWeight','bold','FontSize',14);
end
text(ax,1.5,15,sprintf(['Unsafe: %.0f%% / %.0f%%\n' ...
    'Mean return: %.2f / %.2f'],100*summary.UnsafeRate(1), ...
    100*summary.UnsafeRate(2),summary.MeanReturn(1),summary.MeanReturn(2)), ...
    'HorizontalAlignment','center','FontSize',13,'BackgroundColor','white','Margin',4);

ax=nexttile(layout,2); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
variance=[summary.MeanPositionVariance_m2,summary.MeanNormalVariance_m2, ...
    summary.MeanFinalRelativeXVariance_m2]';
b=bar(ax,variance,'grouped');
b(1).FaceColor=colors(1,:); b(2).FaceColor=colors(2,:);
set(ax,'YScale','log','XTick',1:3, ...
    'XTickLabel',{'Mean position','Path normal','Final relative x'}, ...
    'FontSize',14,'LineWidth',1.1);
ylabel(ax,'Variance [m^2], log scale','FontWeight','bold');
title(ax,'B  Paired-noise spatial dispersion','FontWeight','bold');
legend(ax,labels,'Location','northwest','Box','off','FontSize',12);

ax=nexttile(layout,3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
reduction=[summary.TotalVarianceReductionVsReference_pct(2), ...
    summary.NormalVarianceReductionVsReference_pct(2), ...
    summary.FinalXVarianceReductionVsReference_pct(2)];
bar(ax,1:3,reduction,0.58,'FaceColor',colors(2,:));
ylim(ax,[0,105]); yline(ax,0,'-','Color',[0.4,0.4,0.4]);
set(ax,'XTick',1:3,'XTickLabel',{'Mean position','Path normal','Final relative x'}, ...
    'XTickLabelRotation',12,'FontSize',14,'LineWidth',1.1);
ylabel(ax,'Variance reduction vs PPO [%]','FontWeight','bold');
title(ax,'C  v3.19 reduction relative to PPO','FontWeight','bold');
for i=1:3
    text(ax,i,reduction(i)+2,sprintf('%.2f%%',reduction(i)), ...
        'HorizontalAlignment','center','FontWeight','bold','FontSize',14);
end
ensureParent(defaults.outputFile); ensureParent(defaults.pdfOutputFile);
ensureParent(defaults.figOutputFile); ensureParent(defaults.summaryFile);
writetable(summary,defaults.summaryFile);
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
    if strcmp(kind,'pdf'), print(fig,file,'-dpdf','-vector','-bestfit');
    else, print(fig,file,'-dpng',sprintf('-r%d',resolution)); end
end
end
