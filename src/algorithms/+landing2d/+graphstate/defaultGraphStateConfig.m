function gs = defaultGraphStateConfig()
% DEFAULTGRAPHSTATECONFIG  State-representation settings (the only difference between methods).
% Reward, action, environment, termination, PPO algorithm, hyperparameters,
% budget and seeds are identical for every method; only this struct differs.
%   stateRepresentation
%     'baseline'      plain PPO: the 12-D common observation o_t enters the
%                     policy/value MLP directly (identity encoder)
%     'context_rgat'  TOSM 7-node graph of the same o_t (tosm7_v1) encoded by
%                     one relational graph-attention layer with a local node
%                     path and the grouped factorized readout
%   relationPerturbation (shuffled_rgat_ppo only, landing2d.config.applyMethod)
%                     fixed permutation of the semantic relation types
gs.stateRepresentation = 'baseline';
gs.observationSource = 'commonObservation';
gs.observationFeatures = 'tosm7_v1';
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
gs.layers = 4;
gs.v2HiddenDim = 12;
gs.residualMix = 0.5;
gs.residualRule = 'variance_preserving_v1';
gs.v2InitGain = 5/3;
gs.relationBases = 2;
gs.v2PolicyHiddenSizes = [16,12];
gs.v2ValueHiddenSizes = [15,13];
% Input-dependent attention: alpha_ij^(r)(X_t) follows the current node
% features. 'fixed_relation_v1' (observation-independent relation logits,
% same parameters) remains available for a deliberate comparison.
gs.attentionMode = 'input_dependent_v1';
gs.readout = 'grouped_factorized';
gs.policyFile = 'rl_policy_graphstate.mat';
end
