function output = play(mode,options,root)
% PLAY run_live('ranking') and run_live('showcase'): stored results first, then replays.
%   run_live('ranking')    every evaluated four-method OOD cell (dataset x
%                          training seed x factor) ranked by the TOSM advantage
%                          (landing2d.showcase.rankCells), table and bar chart
%   run_live('showcase')   the best replayable cell: an overview of its stored
%                          episodes (landing2d.showcase.overviewFigure), then an
%                          animated lockstep replay of selected episodes of all
%                          four methods (landing2d.showcase.replayFigure), each
%                          replay checked against the stored study row
% options (showcase)
%   rank         rank among the replayable cells (default 1 = best)
%   dataset, trainSeed, factor   choose a cell directly (e.g. 'v5_p2', 423, 'motion')
%   episodes     'tosm_alone' (default: TOSM lands, the other three fail),
%                'tosm_over_ps' (TOSM lands, PPO and Shuffled fail),
%                'graph_decisive' (TOSM lands, PPO and Shuffled fail, and TOSM
%                with its correction switched off fails), 'all',
%                or a vector of episode seeds
%   maxEpisodes  episodes replayed (default 3; hardest UGV acceleration first)
%   speed        simulated seconds per wall-clock second (default 3; Inf = at once)
%   cellAblation fly every episode of the cell once more with the TOSM
%                correction switched off (sigma(beta) = 0) and report that
%                landing rate (default true; counterfactual, not a trained policy)
%   visible      show the windows (default true); verify (default true)
% Everything shown is a post-hoc selection for viewing. The study results are
% the registered development gates (docs/GENERALIZATION_GOAL_CLOSURE_KO.md).
defaults = struct('rank',1,'dataset','','trainSeed',[],'factor','','episodes','tosm_alone', ...
    'maxEpisodes',3,'speed',3,'visible',true,'verify',true,'top',15,'cellAblation',true);
unknown = setdiff(fieldnames(options),fieldnames(defaults));
assert(isempty(unknown),'landing2d:UnknownOption','Unknown run_live option: %s',strjoin(unknown,', '));
for name = fieldnames(defaults)'
    if ~isfield(options,name{1}), options.(name{1}) = defaults.(name{1}); end
end
ranking = landing2d.showcase.rankCells(root);
sets = landing2d.showcase.datasets(root);
if strcmp(mode,'ranking')
    top = ranking(1:min(options.top,height(ranking)),:);
    disp(top(:,{'Rank','Dataset','TrainSeed','Factor','AllLearned','AdvantagePS_pp','AdvantageAll_pp', ...
        'Rate_PPO','Rate_MLP','Rate_TOSM','Rate_Shuffled','TosmOverPS','TosmAlone','TosmBehind','Replay'}));
    fig = figure('Name','Showcase ranking','Color','w','NumberTitle','off','Visible',onOff(options.visible), ...
        'Position',[80 80 1200 560]);
    ax = axes(fig); b = barh(ax,top{:,{'Rate_PPO','Rate_MLP','Rate_TOSM','Rate_Shuffled'}});
    colors = [0.12 0.35 0.75;0.15 0.55 0.35;0.45 0.2 0.65;0.85 0.4 0.1];
    for k = 1:4, b(k).FaceColor = colors(k,:); end
    set(ax,'YDir','reverse','YTick',1:height(top),'YTickLabel', ...
        compose('#%d %s s%d %s',top.Rank,top.Dataset,top.TrainSeed,top.Factor),'TickLabelInterpreter','none');
    xlabel(ax,'OOD landing rate [%]'); xlim(ax,[0 105]); grid(ax,'on');
    legend(ax,{'PPO','Residual-MLP','TOSM','Shuffled'},'Location','eastoutside');
    title(ax,'Cells ranked by TOSM - best other method (post-hoc, not a study result)');
    output = struct('ranking',ranking,'figure',fig);
    return;
end

if ~isempty(options.dataset)
    selected = ranking(ranking.Dataset==string(options.dataset) & ranking.TrainSeed==options.trainSeed ...
        & ranking.Factor==string(options.factor),:);
    assert(height(selected)==1,'landing2d:ShowcaseCell','No cell %s seed %d %s.',options.dataset,options.trainSeed,options.factor);
else
    replayable = ranking(ranking.Replay,:);
    selected = replayable(options.rank,:);
end
dataset = sets(strcmp({sets.id},selected.Dataset));
assert(selected.Replay && ~isempty(dataset.config),'landing2d:ShowcaseReplay','Dataset %s is ranked only.',selected.Dataset);
c = dataset.config(root);
E = readtable(dataset.episodes,'TextType','string');
C = E(E.TrainSeed==selected.TrainSeed & E.Factor==selected.Factor & E.Shift=="OOD",:);
order = ["ppo","residual_mlp_ppo","onto_rgat_ppo","shuffled_rgat_ppo"];
runs = landing2d.orchestration.loadRuns(c,struct('trainSeeds',selected.TrainSeed,'methods',{cellstr(order)}));
[~,i] = ismember(order,string({runs.id})); runs = runs(i);
manifest = fullfile(fileparts(dataset.episodes),'runManifest.csv');
if isfile(manifest)
    M = readtable(manifest,'TextType','string');
    for k = 1:numel(runs)
        row = M(M.MethodId==string(runs(k).id) & M.TrainSeed==runs(k).trainSeed,:);
        assert(height(row)==1 && row.CheckpointHash==string(runs(k).identity.CheckpointHash), ...
            'landing2d:ShowcaseCheckpoint','%s seed %d is not the evaluated checkpoint.',runs(k).id,runs(k).trainSeed);
    end
end
fprintf(['\nshowcase | rank %d | %s | training seed %d | %s OOD\n  landing PPO %.0f%%, Residual-MLP %.0f%%, ' ...
    'TOSM %.0f%%, Shuffled %.0f%% | TOSM alone %d, over PPO+Shuffled %d, behind %d of %d episodes\n' ...
    '  post-hoc selected cell for viewing; not a study result\n'],selected.Rank,dataset.label,selected.TrainSeed, ...
    selected.Factor,selected.Rate_PPO,selected.Rate_MLP,selected.Rate_TOSM,selected.Rate_Shuffled,selected.TosmAlone, ...
    selected.TosmOverPS,selected.TosmBehind,selected.Episodes);
ablation = table();
if options.cellAblation || strcmp(options.episodes,'graph_decisive')
    ablation = correctionOff(runs(3),selected.Factor,C.EpisodeSeed(C.MethodId=="onto_rgat_ppo"));
    fprintf(['  TOSM with its correction switched off (counterfactual): landing %.0f%% (TOSM %.0f%%); ' ...
        'the correction decides %d episodes\n'],100*mean(ablation.Success),selected.Rate_TOSM, ...
        sum(ablation.Success==0 & ismember(ablation.EpisodeSeed,C.EpisodeSeed(C.MethodId=="onto_rgat_ppo" & C.Success==1))));
end
overview = landing2d.showcase.overviewFigure(E,selected,runs,dataset.label,options.visible,ablation);

[episodes,selection] = selectEpisodes(C,options,ablation);
fprintf('  replaying %d episode(s) (%s): %s\n',numel(episodes),selection,mat2str(episodes(:)'));
replays = {}; figures = gobjects(0);
for j = 1:numel(episodes)
    records = landing2d.showcase.replayEpisode(runs,selected.Factor,episodes(j),C,options.verify);
    info = struct('config',c,'setLabel',dataset.label,'trainSeed',selected.TrainSeed,'factor',selected.Factor, ...
        'episodeSeed',episodes(j),'index',j,'count',numel(episodes),'selection',selection);
    [fig,stopped] = landing2d.showcase.replayFigure(records,info,options);
    figures(end+1) = fig; %#ok<AGROW>
    replays{end+1} = summarize(records,episodes(j)); %#ok<AGROW>
    if stopped, fprintf('  replay window closed: stopped.\n'); break; end
end
episodeTable = vertcat(replays{:});
disp(episodeTable);
if options.verify, fprintf('  every replay reproduced the stored evaluation row.\n'); end
output = struct('ranking',ranking,'cell',selected,'episodes',episodeTable,'overview',overview, ...
    'replays',figures,'correctionOff',ablation);
end

function T = correctionOff(run,factor,episodeSeeds)
% The TOSM episodes of the cell with sigma(beta) = 0 (correction switched off).
off = run.agent; off.policy.encoder.beta = -1000;   % 1/(1+exp(1000)) == 0
[envConfig,scale] = landing2d.minimal.generalizationCondition(run.config,char(factor),'OOD');
success = zeros(numel(episodeSeeds),1); unsafe = success;
parfor j = 1:numel(episodeSeeds)
    [result,traj] = landing2d.rl.rolloutEpisodeV2(off,envConfig,episodeSeeds(j), ...
        struct('deterministic',true,'sensorNoiseScale',scale));
    m = landing2d.evaluation.episodeMetrics(result,traj,envConfig,struct('EpisodeSeed',episodeSeeds(j)),[]);
    success(j) = m.Success; unsafe(j) = m.Unsafe;
end
T = table(episodeSeeds(:),success,unsafe,'VariableNames',{'EpisodeSeed','Success','Unsafe'});
end

function [episodes,selection] = selectEpisodes(C,options,ablation)
methods = ["ppo","residual_mlp_ppo","onto_rgat_ppo","shuffled_rgat_ppo"];
X = C(C.MethodId==methods(3),:);
success = zeros(height(X),4);
for k = 1:4
    Y = C(C.MethodId==methods(k),:); [~,where] = ismember(X.EpisodeSeed,Y.EpisodeSeed);
    success(:,k) = Y.Success(where);
end
if isnumeric(options.episodes)
    episodes = options.episodes(:); selection = 'chosen'; return;
end
selection = char(options.episodes);
switch selection
    case 'tosm_alone', keep = success(:,3)==1 & all(success(:,[1 2 4])==0,2);
    case 'tosm_over_ps', keep = success(:,3)==1 & success(:,1)==0 & success(:,4)==0;
    case 'graph_decisive'
        [~,where] = ismember(X.EpisodeSeed,ablation.EpisodeSeed);
        keep = success(:,3)==1 & success(:,1)==0 & success(:,4)==0 & ablation.Success(where)==0;
    case 'all', keep = true(height(X),1);
    otherwise, error('landing2d:ShowcaseEpisodes','Unknown episode selection %s.',selection);
end
if ~any(keep) && strcmp(selection,'tosm_alone')
    keep = success(:,3)==1 & success(:,1)==0 & success(:,4)==0; selection = 'tosm_over_ps';
end
Y = X(keep,:);
if all(ismember('UgvAcceleration',Y.Properties.VariableNames)), Y = sortrows(Y,'UgvAcceleration','descend'); end
episodes = Y.EpisodeSeed(1:min(options.maxEpisodes,height(Y)));
end

function T = summarize(records,episodeSeed)
rows = cell(numel(records),1);
for k = 1:numel(records)
    m = records(k).metric;
    rows{k} = table(episodeSeed,records(k).methodId,string(m.FailureClass),m.Success,m.Unsafe,m.LandingTime_s, ...
        m.AimErrorRMS_m,m.RelativeSpeedRMS_mps,m.CommandRateRMS_mps3,m.RecoveryTime_s,records(k).mix, ...
        'VariableNames',{'EpisodeSeed','MethodId','Outcome','Success','Unsafe','LandingTime_s','AimErrorRMS_m', ...
        'RelativeSpeedRMS_mps','CommandRateRMS_mps3','RecoveryTime_s','Mix'});
end
for k = 1:numel(records)
    if isempty(records(k).ablation), continue; end
    m = records(k).ablation.metric;
    rows{end+1} = table(episodeSeed,"onto_rgat_ppo (correction off)",string(m.FailureClass),m.Success,m.Unsafe, ...
        m.LandingTime_s,m.AimErrorRMS_m,m.RelativeSpeedRMS_mps,m.CommandRateRMS_mps3,m.RecoveryTime_s,0, ...
        'VariableNames',rows{1}.Properties.VariableNames); %#ok<AGROW>
end
T = vertcat(rows{:});
end

function s = onOff(flag)
if flag, s = 'on'; else, s = 'off'; end
end
