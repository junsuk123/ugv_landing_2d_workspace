function registry = methodRegistry()
% METHODREGISTRY  The three compared methods of relational_policy_v1 and the seed plan.
% One definition for training, evaluation, checkpoints, legends and tables.
%   ppo                plain PPO on the 12-D common observation (M1)
%   onto_rgat_ppo      PPO on the TOSM 7-node R-GAT embedding of the same o_t (M2)
%   shuffled_rgat_ppo  the same R-GAT with a fixed permutation of the semantic
%                      relation types (self edges kept), trained from scratch (M3)
% All three share environment, reward, action, termination, PPO budget and
% parameter count (6,101); they differ only in the Actor/Critic state
% representation. M3 tests whether the *correct* relation semantics matter.
% Training seed s sets rl.seed = base + s - 1 (applyMethod). M3 uses graph
% seed g = s by default, so its runs also average over relation permutations.
% relationShuffle.minChangedFraction: an M3 permutation is accepted only if
% at least this fraction of the 13 semantic edges changes its relation type
% (0.7 -> at least 10 of 13), so the control does not keep most of the TOSM
% assignment by chance (a free permutation keeps 47/13 = 3.6 edges on average).
% trainSeeds.default (1-5) is used by run; trainSeeds.main (1-10) is the
% larger plan. Method differences are reported over training seeds.
methods = struct( ...
    'id',{'ppo','onto_rgat_ppo','shuffled_rgat_ppo'}, ...
    'label',{'PPO','TOSM-RGAT PPO','Shuffled-RGAT PPO'}, ...
    'representation',{'baseline','context_rgat','context_rgat'}, ...
    'graphPerturbation',{'none','none','edge_relation_shuffle'}, ...
    'color',{[0.10 0.32 0.62],[0.35 0.16 0.60],[0.85 0.33 0.10]}, ...
    'lineStyle',{'-','-','--'}, ...
    'marker',{'o','s','^'});
registry = struct('version','comparison_registry_v4','methods',methods, ...
    'trainSeeds',struct('default',1:5,'main',1:10), ...
    'relationShuffle',struct('minChangedFraction',0.7));
end
