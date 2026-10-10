function [fig,summary] = plotParameterMatchedLearningCurve(options)
% PLOTPARAMETERMATCHEDLEARNINGCURVE  Large-font standalone curve for slides.
if nargin < 1, options=struct(); end
root=landing2d.orchestration.projectRoot();
defaults=struct( ...
    'resultFile',fullfile(root,'results','planar_visibility_full.mat'), ...
    'outputFile',fullfile(root,'docs','assets','paper', ...
        'parameter_matched_learning_curve.png'), ...
    'pdfOutputFile',fullfile(root,'docs','assets','paper', ...
        'parameter_matched_learning_curve.pdf'), ...
    'summaryFile',fullfile(root,'docs','assets','paper', ...
        'parameter_matched_learning_curve.csv'), ...
    'visible',true,'resolution',240);
defaults=mergeOptions(defaults,options);
R=load(defaults.resultFile,'comparison');
ids=["ppo","onto_rgat_ppo"];
labels={'Plain PPO','Ontology--R-GAT PPO (6,101 parameters)'};
colors=[0.10,0.32,0.62;0.35,0.16,0.60];
state='on'; if ~defaults.visible, state='off'; end
fig=figure('Name','Parameter-matched learning curve','NumberTitle','off', ...
    'Color','w','Units','pixels','Position',[40,40,1600,900],'Visible',state);
ax=axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
summary=table();
for i=1:2
    index=find(cellfun(@(x)string(x.MethodId)==ids(i),R.comparison.runs),1);
    assert(~isempty(index),'landing2d:LearningCurveRun','Missing run %s.',ids(i));
    h=R.comparison.training{index}.history;
    iteration=[h.iteration]'; landing=100*[h.landingRate]';
    plot(ax,iteration,landing,'-o','Color',colors(i,:), ...
        'LineWidth',3.2,'MarkerSize',7,'MarkerFaceColor',colors(i,:), ...
        'DisplayName',labels{i});
    summary=[summary;table(repmat(ids(i),numel(iteration),1),iteration,landing, ...
        'VariableNames',{'MethodId','Iteration','ValidationLandingPct'})]; %#ok<AGROW>
end
xlim(ax,[0,750]); ylim(ax,[0,105]);
xticks(ax,0:100:750); yticks(ax,0:10:100);
xlabel(ax,'PPO iteration','FontSize',20,'FontWeight','bold');
ylabel(ax,'Validation landing rate [%]','FontSize',20,'FontWeight','bold');
title(ax,{'Validation learning curve under the same 4,500-episode budget'; ...
    'Checkpoint selection uses validation only; held-out test seeds are never used'}, ...
    'FontSize',23,'FontWeight','bold');
legend(ax,'Location','southeast','FontSize',17,'Box','off');
set(ax,'FontSize',17,'LineWidth',1.2);
text(ax,390,22,'Best R-GAT validation: 98% at iteration 525', ...
    'HorizontalAlignment','left','VerticalAlignment','top', ...
    'FontSize',16,'FontWeight','bold','Color',colors(2,:));
ensureParent(defaults.outputFile); ensureParent(defaults.pdfOutputFile);
ensureParent(defaults.summaryFile); writetable(summary,defaults.summaryFile);
exportFigure(fig,defaults.outputFile,defaults.resolution,'png');
exportFigure(fig,defaults.pdfOutputFile,defaults.resolution,'pdf');
end

function out=mergeOptions(out,in)
names=fieldnames(in);
for i=1:numel(names)
    assert(isfield(out,names{i}),'landing2d:LearningCurvePlotOption', ...
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
