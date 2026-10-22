function [summary,fig] = plotConfirmatorySummary(studies,outputFile,options)
% PLOTCONFIRMATORYSUMMARY  Primary endpoints of several confirmatory runs side by side.
%   [summary,fig] = landing2d.viz.plotConfirmatorySummary(studies,outputFile)
% STUDIES is a struct array with fields label, seeds (text) and file (a
% <version>_primary_endpoints.csv written by the registered analysis script).
% Each panel is one contrast (TOSM - Shuffled, TOSM - PPO); each row one
% primary endpoint; each study one marker with its 95% interval of the
% training-seed paired difference. The gray band is the registered +-5 %p
% equivalence margin. Nothing is recomputed: the values are the CSV values.
% OUTPUTFILE (optional) receives a PNG (200 dpi) and a PDF of the same name.
% SUMMARY is the long table of the plotted rows (percentage points).
if nargin < 2, outputFile = ''; end
if nargin < 3, options = struct(); end
if ~isfield(options,'visible'), options.visible = false; end
endpoints = ["P2 held-out success","P1 OOD success (motion)","P1 OOD success (dropout)", ...
    "P1 OOD success (noise)","P1 OOD success (combined)"];
endpointLabels = ["Held-out (training range)","OOD UGV motion","OOD marker dropout", ...
    "OOD observation noise","OOD combined"];
contrasts = ["onto_rgat_ppo - shuffled_rgat_ppo","onto_rgat_ppo - ppo"];
contrastTitles = ["TOSM \x2212 Shuffled (relation placement)","TOSM \x2212 PPO (graph vs. plain)"];
margin = 5;                                         % registered equivalence margin [%p]
% Categorical slots 1-3 of the reference palette (validated all-pairs, light
% surface); a distinct marker shape per study keeps identity off color alone.
colors = [0.165 0.471 0.839; 0.922 0.408 0.204; 0.106 0.686 0.478];
markers = {'o','s','d'};
ink = [0.043 0.043 0.043]; inkSecondary = [0.32 0.32 0.31];
assert(numel(studies) <= size(colors,1),'landing2d:SummaryStudies', ...
    'At most three studies share one summary figure.');

rows = {};
for s = 1:numel(studies)
    T = readtable(studies(s).file,'TextType','string');
    for c = 1:numel(contrasts)
        for e = 1:numel(endpoints)
            k = T.Endpoint == endpoints(e) & T.Contrast == contrasts(c);
            assert(nnz(k) == 1,'landing2d:SummaryRow','%s: missing %s / %s.', ...
                studies(s).file,endpoints(e),contrasts(c));
            r = T(k,:);
            rows{end+1} = table(string(studies(s).label),string(studies(s).seeds), ...
                endpointLabels(e),contrasts(c),100*r.Delta,100*r.Lower95,100*r.Upper95, ...
                r.Positive,r.Negative,r.pHolm,r.Verdict,'VariableNames',{'Version','Seeds', ...
                'Endpoint','Contrast','DeltaPercentPoints','Lower95','Upper95','Positive', ...
                'Negative','pHolm','Verdict'}); %#ok<AGROW>
        end
    end
end
summary = vertcat(rows{:});

visible = 'off'; if options.visible, visible = 'on'; end
fig = figure('Color','w','Visible',visible,'Units','pixels','Position',[60 60 1180 470]);
layout = tiledlayout(fig,1,numel(contrasts),'TileSpacing','compact','Padding','compact');
offsets = linspace(-0.24,0.24,numel(studies));
nE = numel(endpoints);
for c = 1:numel(contrasts)
    ax = nexttile(layout); hold(ax,'on');
    patch(ax,[-margin margin margin -margin],[0.45 0.45 nE+0.55 nE+0.55],[0.93 0.93 0.92], ...
        'EdgeColor','none','HandleVisibility','off');
    xline(ax,0,'Color',[0.55 0.55 0.53],'LineWidth',1,'HandleVisibility','off');
    handles = gobjects(1,numel(studies));
    for s = 1:numel(studies)
        S = summary(summary.Version == string(studies(s).label) & summary.Contrast == contrasts(c),:);
        y = (1:nE)+offsets(s);
        for e = 1:nE
            plot(ax,[S.Lower95(e) S.Upper95(e)],[y(e) y(e)],'-','Color',colors(s,:), ...
                'LineWidth',2,'HandleVisibility','off');
        end
        handles(s) = plot(ax,S.DeltaPercentPoints,y,markers{s},'MarkerSize',7, ...
            'MarkerFaceColor',colors(s,:),'MarkerEdgeColor','w','LineWidth',1, ...
            'DisplayName',sprintf('%s (seeds %s)',studies(s).label,studies(s).seeds));
    end
    set(ax,'YDir','reverse','YLim',[0.45 nE+0.55],'YTick',1:nE,'FontSize',10, ...
        'XColor',inkSecondary,'YColor',inkSecondary,'TickLength',[0 0],'Box','off', ...
        'XGrid','on','GridColor',[0.85 0.85 0.84],'GridAlpha',1,'Layer','top');
    if c == 1, ax.YTickLabel = endpointLabels; else, ax.YTickLabel = {}; end
    xlabel(ax,'Paired difference in success rate [%p], 95% CI','Color',inkSecondary);
    title(ax,sprintf(contrastTitles(c)),'Color',ink,'FontWeight','normal','FontSize',11);
    limit = max(abs([summary.Lower95(summary.Contrast == contrasts(c)); ...
        summary.Upper95(summary.Contrast == contrasts(c))]));
    span = max(margin*2,ceil(limit/5)*5+2);
    xlim(ax,[-1 1]*span);
    step = 10; if span > 40, step = 25; end
    xticks(ax,-floor(span/step)*step:step:floor(span/step)*step);
    if c == numel(contrasts)
        lg = legend(ax,handles,'Orientation','horizontal','Box','off', ...
            'TextColor',ink,'FontSize',10);
        lg.Layout.Tile = 'south';
    end
end
title(layout,sprintf(['Confirmatory primary endpoints, paired by training seed (n = 10 per version); ' ...
    'gray band = \x00B1%d %%p equivalence margin'],margin),'FontSize',10,'Color',inkSecondary);
if ~isempty(outputFile)
    [folder,name] = fileparts(outputFile);
    if ~isempty(folder) && ~exist(folder,'dir'), mkdir(folder); end
    exportgraphics(fig,fullfile(folder,[name '.png']),'Resolution',200);
    exportgraphics(fig,fullfile(folder,[name '.pdf']),'ContentType','vector');
end
end
