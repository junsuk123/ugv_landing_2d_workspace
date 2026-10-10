function [fig,summary] = plotParameterMatchedEvidence(options)
% PLOTPARAMETERMATCHEDEVIDENCE  PPT-ready evidence for the final matched model.
% Uses only the current held-out mission results and training histories. The
% consistency artifacts from the former 16,565-parameter model are excluded.
if nargin < 1, options = struct(); end
root = landing2d.orchestration.projectRoot();
defaults = struct( ...
    'resultFile',fullfile(root,'results','planar_visibility_full.mat'), ...
    'outputFile',fullfile(root,'results','presentation', ...
        'parameter_matched_ontology_evidence.png'), ...
    'paperOutputFile',fullfile(root,'docs','assets','paper','latest_parameter_matched', ...
        'parameter_matched_ontology_evidence.png'), ...
    'pdfOutputFile',fullfile(root,'docs','assets','paper','latest_parameter_matched', ...
        'parameter_matched_ontology_evidence.pdf'), ...
    'summaryFile',fullfile(root,'docs','assets','paper','latest_parameter_matched', ...
        'parameter_matched_ontology_summary.csv'), ...
    'visible',true,'resolution',240);
names = fieldnames(options);
for i = 1:numel(names)
    assert(isfield(defaults,names{i}),'landing2d:ParameterMatchedPlotOption', ...
        'Unknown option %s.',names{i});
    defaults.(names{i}) = options.(names{i});
end

R = load(defaults.resultFile,'comparison','summaryTable');
ids = ["ppo","onto_rgat_ppo"];
labels = {'Plain PPO','Ontology--R-GAT PPO'};
colors = [0.10,0.32,0.62;0.35,0.16,0.60];
rows = zeros(1,2);
for i = 1:2
    rows(i) = find(string(R.summaryTable.MethodId)==ids(i),1);
    assert(~isempty(rows(i)),'landing2d:ParameterMatchedResult', ...
        'Missing final result for %s.',ids(i));
end
T = R.summaryTable(rows,:);
landing = 100*T.SuccessRate;
unsafe = 100*T.UnsafeRate;
timeout = 100*T.TimeoutRate;
meanReturn = T.MeanReturn;
parameters = T.ParameterCount;
inference = T.InferenceMs;
assert(isequal(parameters(:)',[6101,6101]), ...
    'landing2d:ParameterMatchedResult', ...
    'Expected final parameter counts [6101 6101], got [%g %g].',parameters);

state = 'on'; if ~defaults.visible, state = 'off'; end
fig = figure('Name','Parameter-matched ontology R-GAT evidence', ...
    'NumberTitle','off','Color','w','Units','pixels', ...
    'Position',[30,30,1600,900],'Visible',state);
layout = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
title(layout,{ ...
    'Parameter-matched Ontology--R-GAT PPO'; ...
    'Same 12-D observation, reward, environment and 4,500-episode PPO budget | held-out n = 100 | one training seed'}, ...
    'FontWeight','bold','FontSize',18);

% A. Mission outcomes: disclose both completion and the unsafe tail.
ax = nexttile(layout,1); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
mission = [landing,unsafe,timeout];
b = bar(ax,mission,'grouped');
b(1).FaceColor=[0.20,0.62,0.42];
b(2).FaceColor=[0.82,0.29,0.25];
b(3).FaceColor=[0.92,0.62,0.18];
ylim(ax,[0,108]); ylabel(ax,'Episodes [%]');
set(ax,'XTick',1:2,'XTickLabel',labels,'FontSize',11);
title(ax,'A  Held-out mission outcomes','FontWeight','bold');
legend(ax,{'Landing','Unsafe','Timeout'},'Location','southoutside', ...
    'Orientation','horizontal','Box','off');
for k = 1:numel(b)
    text(ax,b(k).XEndPoints,b(k).YEndPoints+2,compose('%.0f%%',b(k).YEndPoints), ...
        'HorizontalAlignment','center','FontWeight','bold','FontSize',10);
end
text(ax,1.5,52,'+1 pp landing; timeout -2 pp; 1% unsafe remains', ...
    'HorizontalAlignment','center','FontSize',10,'Color',[0.25,0.25,0.25]);

% B. Capacity matching: plot from zero so the equality is visually honest.
ax = nexttile(layout,2); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
b = barh(ax,1:2,parameters,0.55,'FaceColor','flat'); b.CData=colors;
xlim(ax,[0,7000]); xlabel(ax,'Trainable parameters');
set(ax,'YTick',1:2,'YTickLabel',labels,'YDir','reverse','FontSize',11);
title(ax,'B  Model capacity matched exactly','FontWeight','bold');
for i = 1:2
    text(ax,parameters(i)-120,i,sprintf('%.0f',parameters(i)), ...
        'HorizontalAlignment','right','Color','w','FontWeight','bold','FontSize',12);
end
text(ax,3500,2.48,sprintf('Difference: %d parameters (%.3f%%)', ...
    parameters(2)-parameters(1),100*(parameters(2)/parameters(1)-1)), ...
    'HorizontalAlignment','center','FontWeight','bold','Color',colors(2,:));

% C. Return: use an absolute zero baseline and report the small difference.
ax = nexttile(layout,3); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
b = bar(ax,1:2,meanReturn,0.55,'FaceColor','flat'); b.CData=colors;
ylim(ax,[0,36]); ylabel(ax,'Mean episodic return');
set(ax,'XTick',1:2,'XTickLabel',labels,'FontSize',11);
title(ax,'C  Held-out return','FontWeight','bold');
for i = 1:2
    text(ax,i,meanReturn(i)+0.7,sprintf('%.2f',meanReturn(i)), ...
        'HorizontalAlignment','center','FontWeight','bold','FontSize',12);
end
text(ax,1.5,3,sprintf('Delta = %+.2f',meanReturn(2)-meanReturn(1)), ...
    'HorizontalAlignment','center','FontWeight','bold','Color',colors(2,:));

% D. Learning curves: validation only; held-out test never selects a checkpoint.
ax = nexttile(layout,4); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for i = 1:2
    h = R.comparison.training{rows(i)}.history;
    plot(ax,[h.iteration],100*[h.landingRate],'-o','Color',colors(i,:), ...
        'LineWidth',1.8,'MarkerSize',3,'DisplayName',labels{i});
end
xlabel(ax,'PPO iteration'); ylabel(ax,'Validation landing [%]');
xlim(ax,[0,750]); ylim(ax,[0,105]);
title(ax,'D  Validation learning curve','FontWeight','bold');
legend(ax,'Location','southeast','Box','off');
text(ax,20,98,sprintf('Actor inference: %.4f vs %.4f ms (100-ms policy period)', ...
    inference(1),inference(2)),'FontSize',9,'Color',[0.25,0.25,0.25]);

summary = table(ids',landing,unsafe,timeout,meanReturn,parameters,inference, ...
    'VariableNames',{'MethodId','LandingPct','UnsafePct','TimeoutPct', ...
    'MeanReturn','ParameterCount','InferenceMs'});
ensureParent(defaults.outputFile); ensureParent(defaults.paperOutputFile);
ensureParent(defaults.pdfOutputFile); ensureParent(defaults.summaryFile);
writetable(summary,defaults.summaryFile);
exportFigure(fig,defaults.outputFile,defaults.resolution,'png');
exportFigure(fig,defaults.paperOutputFile,defaults.resolution,'png');
exportFigure(fig,defaults.pdfOutputFile,defaults.resolution,'pdf');
end

function ensureParent(file)
folder=fileparts(file);
if ~exist(folder,'dir'), mkdir(folder); end
end

function exportFigure(fig,file,resolution,kind)
try
    if strcmp(kind,'pdf')
        exportgraphics(fig,file,'ContentType','vector','BackgroundColor','white');
    else
        exportgraphics(fig,file,'Resolution',resolution,'BackgroundColor','white');
    end
catch errorInfo
    warning('landing2d:FigureExportFallback', ...
        'exportgraphics failed (%s); using print for %s.',errorInfo.message,file);
    if strcmp(kind,'pdf')
        print(fig,file,'-dpdf','-painters','-bestfit');
    else
        print(fig,file,'-dpng',sprintf('-r%d',resolution));
    end
end
end
