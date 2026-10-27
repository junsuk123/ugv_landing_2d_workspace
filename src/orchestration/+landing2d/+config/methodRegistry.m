function registry = methodRegistry(c)
% METHODREGISTRY  The three compared methods of relational_policy_v1 and the seed plan.
% Active minimal_relational_v3: same three IDs, four nodes, 1,419 parameters;
% minimalDev/minimalConfirm seeds and minimalChangedFraction below.
% The version history below documents the archived seven-node studies.
% One definition for training, evaluation, checkpoints, legends and tables.
%   ppo                plain PPO on the 10-D common observation (M1)
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
% seeds 21-30 moved to trainSeeds.depth4 (now v23); trainSeeds.depth4Dev = 6-9 is the
% depth4 learnability gate (docs/RGAT_V2_DESIGN_KO.md section 9).
% Registry v9 (relational-policy-v2.3, 2026-10-20): the observation/feature
% cleanup replaces v2.2 before any v2.2 confirmatory training, so the still
% untrained seeds 21-30 move to trainSeeds.v23; v23Dev = 6-9 is its gate
% (docs/RGAT_V2_DESIGN_KO.md section 10).
% Registry v10 (relational-policy-v2.4, 2026-10-21): relation operators fixed
% by meaning in the four-layer encoder, so the operator-class rule returns
% for the shuffled arm (applyMethod, minOperatorChangedFraction = 0.7 -> 10 of
% 13 edges change class, the maximum with 8:5). trainSeeds.v24 = 51-60 are
% fresh confirmatory seeds fixed before any v2.4 training; no learnability
% gate by user decision (docs/RGAT_V2_DESIGN_KO.md section 11).
% Registry v11 (relational-policy-v2.5, 2026-10-21): operator-shared
% parameters and the LandingCondition sink readout remove the two v2.4
% semantic bypasses. Seeds 61-64 are development-gate seeds only; fresh
% confirmatory seeds 71-80 are fixed before development begins.
% Registry v12 (relational-policy-v2.6, 2026-10-21): only
% qualifiesEstimate uses the reliability-gate operator; the maximum
% operator-class change is therefore 6/13 while relation labels still change
% on at least 10/13 edges. Development seeds 81-84 and untouched
% confirmatory seeds 91-100 are fixed before development begins.
% Registry v13 (relational-policy-v2.7, 2026-10-21): standard two-layer
% R-GAT with a fixed cyclic relation codebook, no gate/operator class.
% Development seeds 101-104 and confirmatory seeds 111-120 are fresh and
% fixed before any v2.7 training.
% Registry v14 (relational-policy-v2.8, 2026-10-21): replace the symmetric
% cyclic labels by a fixed ontology-role descriptor codebook. Development
% seeds 121-124 and confirmatory seeds 131-140 are fresh and fixed before
% any v2.8 training.
% Registry v15 (relational-policy-v2.9, 2026-10-21): semantic codebook plus
% node-shared mean factorized readout. Development seeds 141-144 and
% confirmatory seeds 151-160 are fresh and fixed before any v2.9 training.
% Registry v16 (relational-policy-v2.10, 2026-10-21): variance-preserving
% node-shared readout. Development seeds 161-164 and confirmatory seeds
% 171-180 are fresh and fixed before any v2.10 training.
% Registry v17 (relational-policy-v2.11, 2026-10-22): fixed equal-energy
% node-role codebook readout. Development seeds 181-184 and confirmatory
% seeds 191-200 are fresh and fixed before any v2.11 training.
% Registry v18 (relational-policy-v2.12, 2026-10-22): LandingCondition sink
% readout in the ungated R-GAT. Development seeds 201-204 and confirmatory
% seeds 211-220 are fresh and fixed before any v2.12 training.
% Registry v19 (relational-policy-v2.13, 2026-10-23, user decision): latent
% LandingCondition sink (tosm7_v3) in both graph arms, plain PPO frozen.
% Development uses the default seeds 1-5: both graph arms are trained anew,
% the plain-PPO checkpoints of 1-5 are reused unchanged
% (landing2d.rl.baselineVersion). Confirmatory seeds 221-230 are fresh and
% fixed before any v2.13 training.
% Registry v20 (relational-policy-v2.14, 2026-10-23, user decision after the
% failed v2.13 gate, whose confirmatory seeds 221-230 stay unused): signed
% o_t-scale LandingCondition features (tosm7_v4) in both graph arms, plain PPO
% frozen. Development again on 1-5 (graph arms retrained, plain PPO 1-5
% reused); confirmatory seeds 231-240 are fresh and fixed before any v2.14
% training.
if nargin>0 && isfield(c,'methodProfile') && strcmp(c.methodProfile,'current_semantics_v1')
    registry = landing2d.current_semantics.registry(); return;
end
if nargin>0 && isfield(c,'methodProfile') && strcmp(c.methodProfile,'relational_residual_v5')
    registry = landing2d.residual_context.registry(); return;
end
if nargin>0 && isfield(c,'methodProfile') && strcmp(c.methodProfile,'relational_residual_v4')
    registry = landing2d.residual_base_init.registry(); return;
end
if nargin>0 && isfield(c,'methodProfile') && strcmp(c.methodProfile,'relational_residual_v3')
    registry = landing2d.residual_motion.registry(); return;
end
if nargin>0 && isfield(c,'methodProfile') && strcmp(c.methodProfile,'relational_residual_v2')
    registry = landing2d.residual_logits.registry(); return;
end
if nargin>0 && isfield(c,'methodProfile') && strcmp(c.methodProfile,'relational_residual_v1')
    registry = landing2d.residual.registry(); return;
end
methods = struct( ...
    'id',{'ppo','onto_rgat_ppo','shuffled_rgat_ppo'}, ...
    'label',{'PPO','TOSM-RGAT PPO','Shuffled-RGAT PPO'}, ...
    'representation',{'baseline','context_rgat','context_rgat'}, ...
    'graphPerturbation',{'none','none','edge_relation_shuffle'}, ...
    'color',{[0.10 0.32 0.62],[0.35 0.16 0.60],[0.85 0.33 0.10]}, ...
    'lineStyle',{'-','-','--'}, ...
    'marker',{'o','s','^'});
% v21: v2.15 single-channel sink repair. Reused development seeds 1-5,
% untouched confirmatory seeds 241-250; v2.14 confirmation was not opened.
% v23: minimal v3.1 shared two-hop dynamic attention. All three methods use
% fresh development seeds 271:275; untouched confirmation seeds 281:290.
% v24: v3.2 paired development reuses 271:275 to isolate architecture;
% fresh development 291:295 and untouched first confirmation 301:310.
% v25: v3.3 equal initial semantic transforms; paired development 291:295,
% fresh development 311:315, untouched confirmation 321:330. No v3.2
% confirmation was opened; 301:310 remain unused.
registry = struct('version','comparison_registry_v25','methods',methods, ...
    'trainSeeds',struct('default',1:5,'main',1:5,'confirmatory',11:15,'v2',16:20, ...
    'v21Dev',6:9,'depth4Dev',6:9,'v23Dev',6:9,'v23',21:30,'v24',51:60, ...
    'v25Dev',61:64,'v25',71:80,'v26Dev',81:84,'v26',91:100, ...
    'v27Dev',101:104,'v27',111:120,'v28Dev',121:124,'v28',131:140, ...
    'v29Dev',141:144,'v29',151:160,'v210Dev',161:164,'v210',171:180, ...
    'v211Dev',181:184,'v211',191:200,'v212Dev',201:204,'v212',211:220, ...
    'v213Dev',1:5,'v213',221:230,'v214Dev',1:5,'v214',231:240, ...
    'v215Dev',1:5,'v215',241:250,'minimalDev',251:255,'minimalConfirm',261:270, ...
    'minimalV31Dev',271:275,'minimalV31Confirm',281:290, ...
    'minimalV32PairedDev',271:275,'minimalV32Dev',291:295,'minimalV32Confirm',301:310, ...
    'minimalV33PairedDev',291:295,'minimalV33Dev',311:315,'minimalV33Confirm',321:330), ...
    'relationShuffle',struct('minChangedFraction',0.7, ...
    'minReliabilityOperatorChangedFraction',6/13,'minimalChangedFraction',2/3));
end
