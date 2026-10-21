function gs = defaultGraphStateConfig()
% DEFAULTGRAPHSTATECONFIG  State-representation settings (the only difference between methods).
% Reward, action, environment, termination, PPO algorithm, hyperparameters,
% budget and seeds are identical for every method; only this struct differs.
%   stateRepresentation
%     'baseline'      plain PPO: the 10-D common observation o_t enters the
%                     policy/value MLP directly (identity encoder)
%     'context_rgat'  TOSM 7-node graph of the same o_t (tosm7_v2) encoded by
%                     one relational graph-attention layer with a local node
%                     path and the grouped factorized readout
%   relationPerturbation (shuffled_rgat_ppo only, landing2d.config.applyMethod)
%                     fixed permutation of the semantic relation types
gs.stateRepresentation = 'baseline';
gs.observationSource = 'commonObservation';
gs.observationFeatures = 'tosm7_v2';
% Encoder: 16-D node state, 4-D relation embedding, 16-D graph embedding.
% Legacy relation-specific heads are 35-38 / 35-30. The default
% operator-shared encoder uses 38-42 / 40-36 below; both allocations total
% 6,101 trainable parameters, equal to plain PPO (rl.hiddenSize).
gs.hiddenDim = 16;
gs.relationDim = 4;
gs.graphDim = 16;
gs.policyHiddenSizes = [35,38];
gs.valueHiddenSizes = [35,30];
% typed_v1 shares one trainable message/attention transform per operator
% class (propagate, modulate). The saved relation parameters are moved to
% the heads so the graph arms remain exactly parameter-matched to PPO.
gs.operatorSharedPolicyHiddenSizes = [38,42];
gs.operatorSharedValueHiddenSizes = [40,36];
gs.initScale = 0.12;
gs.encoderLearnRate = 1e-4;
% Encoder version (relational-policy-v2.0, 2026-10-20). 'rgat_v2' is a
% standard relational graph-attention network: L = 2 layers, every edge a
% message W_r h_j with relation-specific weights W_r = sum_b C_rb V_b
% (basis decomposition, Schlichtkrull et al. 2018), input-dependent attention
% normalized over ALL incoming edges of a node across relation types
% (ARGAT-style, Busbridge et al. 2019; self edges included), tanh node
% update, variance-preserving (LeCun normal) initialization and the
% grouped_factorized readout. No multiplicative gate, operator class, local
% bypass path or hand-picked readout start: what reaches the policy is
% decided only by the ontology graph, the R-GAT and the readout. Two layers
% let relations compose (e.g. qualifiesEstimate then conditionsLanding).
% Each layer also has the R-GCN root (self-connection) weight Wroot_l of the
% canonical layer. Without it, the attention average and two tanh layers
% shrink the input signal at initialization: the untrained policy mean was
% 3-7x less sensitive to relative position/height than plain PPO; with it the
% sensitivity matches plain PPO (init-only analysis, 2026-10-20, no episode
% outcome used; docs/RGAT_V2_DESIGN_KO.md).
% v2.0/v2.1 (L = 2, 16-D nodes): 1,892 per encoder, heads 27-26 / 25-24.
% Depth 4 (relational-policy-v2.2, depth4_v1, 2026-10-20): four sequential
% layers with independent parameters, 12-D node states (v2HiddenDim) and a
% fixed residual interpolation for layers 2-4 (residualMix eta = 0.5),
%   H^1 = F_1,  H^l = sqrt(1-eta) H^(l-1) + sqrt(eta) F_l   (variance_preserving_v1),
% F_l = tanh(Wroot_l h_i + sum alpha_ij W_r h_j + b_l). The mix has no
% trainable parameter; it keeps the stacked states bounded and retains the
% shorter-hop states. The specified convex mix (1-eta) H + eta F averages two
% nearly uncorrelated states, so the node-state RMS fell by about 1/sqrt(2) per
% layer (0.42 -> 0.18 at layer 4) and the untrained policy mean was half as
% sensitive to the observation as plain PPO (|d mu/d o| 0.013 vs 0.025). The
% outcome-independent v2.0 rule (initial signal not below plain PPO) was met
% only by the variance-preserving mix together with the tanh gain 5/3 on the
% LeCun weights entering a tanh (v2InitGain: V, Wroot): 0.033 (init-only
% analysis, dev seeds 6-9, docs/RGAT_V2_DESIGN_KO.md section 9). Four layers
% let a source reach LandingCondition along the ontology's four-relation
% chain PadVelocity -> RelativeVelocity -> RelativePosition -> ViewMargin ->
% LandingCondition before the readout.
% Parameters: 398 + 3 x 614 (layers) + 320 (readout) = 2,560 per encoder;
% heads 16-12 / 15-13 keep the 6,101 total. Every layer uses the same typed
% graph (the shuffled arm: one permutation for all layers).
% 'rgat_v1' selects the archived single-layer encoders (relationOperators
% typed_v1 / additive_v1) of relational-policy-v1.x; it keeps hiddenDim.
gs.encoderVersion = 'rgat_v2';
gs.layers = 2;
gs.v2HiddenDim = 16;
gs.residualMix = 0;
gs.residualRule = 'convex_v1';
gs.v2InitGain = 1;
gs.relationBases = 3;
% v2.5 semantic bottleneck: sharing the two semantic operator banks and
% reading only the ontology sink reduces each encoder to 2,056 parameters.
% The saved capacity is assigned to the graph-arm heads, symmetrically for
% TOSM and Shuffled, so every comparison arm still has exactly 6,101.
gs.v2PolicyHiddenSizes = [27,23];
gs.v2ValueHiddenSizes = [27,24];
% Semantic fixed operators (relational-policy-v2.4, 2026-10-21, user decision
% after the Python 4-layer development study, where the 4-layer TOSM with the
% relation operators fixed by meaning was the best variant). In every layer
% the edges whose relation is a 'modulate' relation (qualifiesEstimate,
% conditionsLanding) form a second attention graph whose aggregate gates the
% destination state, and the 'propagate' relations (informsMotion,
% affectsVisibility) with the self edges form the additive one:
%   F_l = (1 + tanh(Z_mod,l)) .* tanh(Z_prop,l + Wroot_l h + b_l),
% each graph with its own softmax per destination. Both graphs use the same
% basis weights W_r, attention a and embeddings E of the layer, so the
% parameter count is that of v2.3 (6,101). The shuffled arm moves relation
% types and therefore operator classes (landing2d.config.applyMethod).
% 'none' = v2.0-v2.3: one attention over all edges, no gate.
% semantic_bottleneck_v1 (relational-policy-v2.5): retain the v2.4 fixed
% propagate/modulate computation, but share one trainable transform within
% each operator class and form the grouped-factorized readout from the
% ontology sink LandingCondition only. This removes relation-label-specific
% capacity and the all-node readout bypass that let a shuffled graph relearn
% or ignore the supplied semantics. Both graph arms use the same rule.
% semantic_reliability_bottleneck_v1 (relational-policy-v2.6): only
% qualifiesEstimate is a reliability gate. informsMotion,
% affectsVisibility, conditionsLanding and self are additive, so signed
% motion/control evidence reaches LandingCondition without being forced
% through a multiplicative gate. The shared banks and sink remain v2.5.
% 'semantic_fixed_v1' is v2.4; 'semantic_bottleneck_v1' is v2.5;
% 'none' is v2.0-v2.3.
gs.v2Operators = 'none';
% relational-policy-v2.7: standard two-layer R-GAT without gates or operator
% classes. Every relation transform is a fixed, equal-norm cyclic combination
% of three trainable common bases; attention uses one shared trainable vector
% and fixed regular-simplex relation embeddings. Thus a shuffled label cannot
% acquire an independent parameter bank and silently relearn the permutation.
% The codebook is fixed before training and treats all five relation labels
% symmetrically. All seven nodes remain in the grouped-factorized readout.
gs.v2RelationParameterization = 'fixed_cyclic_codebook_v1';
% Input-dependent attention: alpha_ij^(r)(X_t) follows the current node
% features. 'fixed_relation_v1' (observation-independent relation logits,
% same parameters) remains available for a deliberate comparison.
gs.attentionMode = 'input_dependent_v1';
gs.readout = 'grouped_factorized';
gs.policyFile = 'rl_policy_graphstate.mat';
end
