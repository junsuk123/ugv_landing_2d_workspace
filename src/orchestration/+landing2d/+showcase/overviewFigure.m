function fig = overviewFigure(E,selected,runs,setLabel,visible,ablation)
% OVERVIEWFIGURE Stored study metrics of one OOD cell, all four methods (no rollout).
%   1 outcome composition (landing and every failure class) of the cell's episodes
%   2 paired episode map: landed / failed per method, episodes ordered by the factor
%   3 landing rate against the UGV acceleration of the episode (motion) or episode order
%   4 aim-error RMS per episode, 5 unsafe contact and timeout rates,
%   6 the same factor's OOD landing rate of every training seed (selected seed marked)
% ABLATION (optional table EpisodeSeed/Success/Unsafe): TOSM with its correction
% switched off on the same episodes, shown as an extra 'TOSM off' group in 5.
% Episodes and seeds are the stored evaluation; the cell itself is a post-hoc
% selection (landing2d.showcase.rankCells), not a study result.
methods = string({runs.id}); colors = vertcat(runs.color);
labels = replace(erase(string({runs.label}),[" residual PPO"," PPO"]),"Residual-MLP","MLP"); labels(labels=="") = "PPO";
C = E(E.TrainSeed==selected.TrainSeed & E.Factor==selected.Factor & E.Shift=="OOD",:);
fig = figure('Name',sprintf('Showcase cell | %s | seed %d | %s OOD',selected.Dataset,selected.TrainSeed,selected.Factor), ...
    'Color','w','NumberTitle','off','Visible',onOff(visible),'Position',[60 60 1500 860]);
layout = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
title(layout,sprintf(['%s  |  training seed %d  |  %s OOD  |  post-hoc selected cell (rank %d), ' ...
    'not a study result'],setLabel,selected.TrainSeed,selected.Factor,selected.Rank),'Interpreter','none');

ax = nexttile(layout); classes = unique(string(C.FailureClass));
classes = ["SUCCESS";classes(classes~="SUCCESS")];
counts = zeros(numel(methods),numel(classes));
for k = 1:numel(methods)
    X = C(C.MethodId==methods(k),:);
    for j = 1:numel(classes), counts(k,j) = sum(string(X.FailureClass)==classes(j)); end
end
b = bar(ax,counts,'stacked'); palette = [0.2 0.65 0.3;lines(max(numel(classes)-1,1))];
for j = 1:numel(b), b(j).FaceColor = palette(j,:); end
set(ax,'XTickLabel',labels); ylabel(ax,'episodes');
legend(ax,replace(classes,'_',' '),'Location','eastoutside','FontSize',7); title(ax,'Outcome composition');

ax = nexttile(layout);
[order,key,keyName] = episodeOrder(C,methods(1),selected.Factor);
map = zeros(numel(methods),numel(order));
for k = 1:numel(methods)
    X = C(C.MethodId==methods(k),:);
    [~,where] = ismember(order,X.EpisodeSeed);
    map(k,:) = X.Success(where)'+2*X.Unsafe(where)';
end
imagesc(ax,map); colormap(ax,[0.85 0.3 0.3;0.25 0.65 0.35;0.55 0.1 0.6]); clim(ax,[0 2]);
set(ax,'YTick',1:numel(methods),'YTickLabel',labels); xlabel(ax,sprintf('episodes ordered by %s',keyName));
title(ax,'Paired episodes: green landed, red failed, purple unsafe contact');

ax = nexttile(layout); hold(ax,'on');
if selected.Factor=="motion"
    edges = linspace(min(key),max(key),6); centers = (edges(1:end-1)+edges(2:end))/2;
    for k = 1:numel(methods)
        X = C(C.MethodId==methods(k),:); rate = nan(1,numel(centers));
        for j = 1:numel(centers)
            inBin = X.UgvAcceleration>=edges(j) & X.UgvAcceleration<=edges(j+1);
            rate(j) = 100*mean(X.Success(inBin));
        end
        plot(ax,centers,rate,'-o','Color',colors(k,:),'LineWidth',1.6,'DisplayName',labels(k));
    end
    xlabel(ax,'UGV acceleration a_2 [m/s^2]');
else
    for k = 1:numel(methods)
        X = C(C.MethodId==methods(k),:); [~,where] = ismember(order,X.EpisodeSeed);
        plot(ax,100*cumsum(X.Success(where))'./(1:numel(order)),'Color',colors(k,:),'LineWidth',1.6,'DisplayName',labels(k));
    end
    xlabel(ax,'episodes (cumulative)');
end
ylabel(ax,'landing rate [%]'); ylim(ax,[0 105]); grid(ax,'on'); legend(ax,'Location','southwest','FontSize',7);
title(ax,'Landing rate against the OOD factor');

ax = nexttile(layout); values = []; groups = [];
for k = 1:numel(methods)
    X = C(C.MethodId==methods(k),:); values = [values;X.AimErrorRMS_m]; groups = [groups;k*ones(height(X),1)]; %#ok<AGROW>
end
boxchart(ax,groups,values,'MarkerStyle','.'); set(ax,'XTick',1:numel(methods),'XTickLabel',labels);
ylabel(ax,'aim-error RMS per episode [m]'); grid(ax,'on'); title(ax,'Tracking error');

ax = nexttile(layout);
rates = zeros(numel(methods),3);
for k = 1:numel(methods)
    X = C(C.MethodId==methods(k),:);
    rates(k,:) = 100*[mean(X.Success),mean(X.Unsafe),mean(X.Timeout)];
end
groupLabels = labels;
if nargin>=6 && ~isempty(ablation)
    rates(end+1,:) = 100*[mean(ablation.Success),mean(ablation.Unsafe),NaN]; groupLabels(end+1) = "TOSM off";
end
b = bar(ax,rates); b(1).FaceColor = [0.25 0.65 0.35]; b(2).FaceColor = [0.55 0.1 0.6]; b(3).FaceColor = [0.6 0.6 0.6];
set(ax,'XTick',1:numel(groupLabels),'XTickLabel',groupLabels); ylabel(ax,'[%]'); ylim(ax,[0 105]); grid(ax,'on');
legend(ax,{'landed','unsafe contact','timeout'},'Location','northeast','FontSize',7); title(ax,'Cell rates');
for k = 1:size(rates,1), text(ax,k-0.27,rates(k,1)+3,sprintf('%.0f',rates(k,1)),'FontSize',8); end
if numel(groupLabels)>numel(methods), title(ax,'Cell rates (TOSM off = correction switched off, counterfactual)'); end

ax = nexttile(layout); hold(ax,'on');
seeds = unique(E.TrainSeed)';
for k = 1:numel(methods)
    rate = arrayfun(@(s)100*mean(E.Success(E.TrainSeed==s & E.MethodId==methods(k) ...
        & E.Factor==selected.Factor & E.Shift=="OOD")),seeds);
    plot(ax,seeds,rate,'-o','Color',colors(k,:),'LineWidth',1.4,'DisplayName',labels(k));
end
xline(ax,selected.TrainSeed,'--k','selected','HandleVisibility','off');
xlabel(ax,'training seed'); ylabel(ax,'OOD landing rate [%]'); ylim(ax,[0 105]); grid(ax,'on');
legend(ax,'Location','southwest','FontSize',7); title(ax,sprintf('All seeds, %s OOD (context)',selected.Factor));
end

function [order,key,keyName] = episodeOrder(C,firstMethod,factor)
X = C(C.MethodId==firstMethod,:);
if factor=="motion"
    [key,i] = sort(X.UgvAcceleration); keyName = 'UGV acceleration';
else
    [key,i] = sort(X.EpisodeSeed); keyName = 'episode seed';
end
order = X.EpisodeSeed(i);
end

function s = onOff(flag)
if flag, s = 'on'; else, s = 'off'; end
end
