function T = rankCells(root)
% RANKCELLS Every evaluated four-method OOD cell (dataset x training seed x factor), ranked for the showcase.
% Read only from the stored episodes (no rollout). Per cell, on the same 100
% paired episode seeds:
%   Rate_*            OOD landing rate [%] of PPO, Residual-MLP, TOSM, Shuffled
%   Unsafe_*          OOD unsafe-contact rate [%]
%   AdvantagePS_pp    TOSM - max(PPO, Shuffled) [%p]
%   AdvantageAll_pp   TOSM - max(PPO, Residual-MLP, Shuffled) [%p]
%   TosmOverPS        episodes TOSM lands while PPO and Shuffled both fail
%   TosmAlone         episodes TOSM lands while all three others fail
%   TosmBehind        episodes TOSM fails while PPO or Shuffled lands
%   AllLearned        every method's ID landing rate of that seed >= 90%
% Order: AllLearned, then AdvantageAll_pp, then AdvantagePS_pp (descending).
% A post-hoc selection for viewing: the best cell is not a study result.
if nargin<1, root = landing2d.orchestration.projectRoot(); end
methods = ["ppo","residual_mlp_ppo","onto_rgat_ppo","shuffled_rgat_ppo"];
sets = landing2d.showcase.datasets(root);
rows = {};
for s = 1:numel(sets)
    E = readtable(sets(s).episodes,'TextType','string');
    for seed = unique(E.TrainSeed)'
        learned = true;
        for m = methods
            learned = learned && mean(E.Success(E.TrainSeed==seed & E.MethodId==m & E.Shift=="ID"))>=.9;
        end
        for factor = ["motion","dropout","noise"]
            C = E(E.TrainSeed==seed & E.Factor==factor & E.Shift=="OOD",:);
            reference = sort(C.EpisodeSeed(C.MethodId==methods(1)));
            success = zeros(numel(reference),4); rate = zeros(1,4); unsafe = rate;
            for k = 1:4
                X = sortrows(C(C.MethodId==methods(k),:),'EpisodeSeed');
                assert(isequal(X.EpisodeSeed,reference),'landing2d:ShowcasePairing','Episodes are not paired.');
                success(:,k) = X.Success; rate(k) = 100*mean(X.Success); unsafe(k) = 100*mean(X.Unsafe);
            end
            rows{end+1,1} = table(string(sets(s).id),seed,factor,learned, ...
                rate(3)-max(rate([1 4])),rate(3)-max(rate([1 2 4])),rate(1),rate(2),rate(3),rate(4), ...
                unsafe(1),unsafe(2),unsafe(3),unsafe(4), ...
                sum(success(:,3)==1 & success(:,1)==0 & success(:,4)==0), ...
                sum(success(:,3)==1 & all(success(:,[1 2 4])==0,2)), ...
                sum(success(:,3)==0 & (success(:,1)==1 | success(:,4)==1)), ...
                ~isempty(sets(s).config),numel(reference), ...
                'VariableNames',{'Dataset','TrainSeed','Factor','AllLearned','AdvantagePS_pp','AdvantageAll_pp', ...
                'Rate_PPO','Rate_MLP','Rate_TOSM','Rate_Shuffled','Unsafe_PPO','Unsafe_MLP','Unsafe_TOSM', ...
                'Unsafe_Shuffled','TosmOverPS','TosmAlone','TosmBehind','Replay','Episodes'}); %#ok<AGROW>
        end
    end
end
T = sortrows(vertcat(rows{:}),{'AllLearned','AdvantageAll_pp','AdvantagePS_pp'},{'descend','descend','descend'});
T = [table((1:height(T))','VariableNames',{'Rank'}),T];
end
