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
% at least this fraction of the 13 semantic edges changes its relation type.
% minOperatorChangedFraction applies the same rule to the computation that
% matters under typed_v1: whether an edge is a modulating or propagating
% edge. With 8 modulation and 5 propagation labels, 10 of 13 is the largest
% possible operator-class change while preserving relation counts.
% trainSeeds.default (1-5) is used by run; trainSeeds.main (1-10) is the
% completed v4 extension; trainSeeds.confirmatory (11-15) was the v5
% (relational-policy-v1.1) confirmation. Registry v6 (relational-policy-v2.0,
% rgat_v2, 2026-10-20): the encoder has no operator classes, so the operator
% rule is gone; trainSeeds.v2 = 16-20 are fresh seeds fixed before any v2
% training (docs/RGAT_V2_DESIGN_KO.md). Registry v7 (relational-policy-v2.1,
% 2026-10-20): trainSeeds.v21Dev = 6-9 for the learnability gate of the
% common exploration change, trainSeeds.v21 = 21-30 fresh confirmatory seeds
% fixed before any v2.1 training (docs/RGAT_V2_DESIGN_KO.md section 8).
% Registry v8 (relational-policy-v2.2, depth4_v1, 2026-10-20): the four-layer
% encoder replaces v2.1 before any v2.1 confirmatory training, so the untrained
% seeds 21-30 move to trainSeeds.depth4; trainSeeds.depth4Dev = 6-9 is the
% depth4 learnability gate (docs/RGAT_V2_DESIGN_KO.md section 9).
methods = struct( ...
    'id',{'ppo','onto_rgat_ppo','shuffled_rgat_ppo'}, ...
    'label',{'PPO','TOSM-RGAT PPO','Shuffled-RGAT PPO'}, ...
    'representation',{'baseline','context_rgat','context_rgat'}, ...
    'graphPerturbation',{'none','none','edge_relation_shuffle'}, ...
    'color',{[0.10 0.32 0.62],[0.35 0.16 0.60],[0.85 0.33 0.10]}, ...
    'lineStyle',{'-','-','--'}, ...
    'marker',{'o','s','^'});
registry = struct('version','comparison_registry_v8','methods',methods, ...
    'trainSeeds',struct('default',1:5,'main',1:10,'confirmatory',11:15,'v2',16:20, ...
    'v21Dev',6:9,'depth4Dev',6:9,'depth4',21:30), ...
    'relationShuffle',struct('minChangedFraction',0.7));
end
