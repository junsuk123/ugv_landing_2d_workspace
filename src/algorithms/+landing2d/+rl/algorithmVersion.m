function version = algorithmVersion()
% ALGORITHMVERSION  Behaviour-changing implementation version of trained policies.
% Bump when a code change makes a saved policy incompatible although the
% numeric configuration is unchanged. relational-policy-v1.0 (2026-10-17):
% identical PPO loss for every method (no R-GAT-only smoothing term),
% input-dependent attention, reserved training-episode seed range, 2 x 2
% scenario family with initial relative-motion offsets.
% relational-policy-v1.1 (2026-10-19): typed_v1 shares relation-layer
% parameters by operator class so shuffled labels cannot be relearned as
% arbitrary relation-specific capacity buckets. Total parameters stay 6,101.
% relational-policy-v2.0 (2026-10-20): rgat_v2 encoder (two standard
% relational graph-attention layers, cross-relation attention, basis
% decomposition, no gate / operator class / bypass / hand-set readout) and
% the common validation-plateau early stop of ppoTrain. Total parameters 6,101.
% relational-policy-v2.1 (2026-10-20): common exploration scale
% rl.initialLogStd -1.0 -> -2.0 (the v2.0 hover trap) and the common
% validation screen of ppoTrain. Encoder, loss and parameters are unchanged.
% relational-policy-v2.2 (2026-10-20, depth4_v1): rgat_v2 with four layers
% (12-D nodes, independent parameters per layer, fixed residual mix 0.5 in
% layers 2-4), heads 16-12 / 15-13; still 6,101 parameters and no gate.
% relational-policy-v2.3 (2026-10-20): 10-D common observation (constant
% navigation validity/age removed), tosm7_v2 node features (no normalized
% cross-track / geometryQuadratic / navigation features), plain-PPO widths
% 48-51 / 47-50 to keep 6,101 parameters. Encoder as v2.2.
% relational-policy-v2.4 (2026-10-21, user decision): the v2.3 four-layer
% encoder with relation operators fixed by the ontology meaning
% (graphState.v2Operators = semantic_fixed_v1: modulate relations gate,
% propagate relations add). Same parameters (6,101), observation and PPO.
% relational-policy-v2.5 (2026-10-21): semantic_bottleneck_v1 shares one
% trainable parameter bank per fixed operator class and reads the graph only
% at the LandingCondition ontology sink. Graph-arm heads 24-24 / 24-20 move
% the removed encoder capacity while keeping 6,101 parameters.
% relational-policy-v2.6 (2026-10-21): only qualifiesEstimate gates estimate
% nodes; conditionsLanding and all signed state/context relations propagate
% additively through the v2.5 shared-parameter ontology-sink bottleneck.
% relational-policy-v2.7 (2026-10-21): return to a standard two-layer R-GAT
% with one cross-relation softmax, no gate/operator class and all-node
% grouped readout. Fixed cyclic basis coefficients and fixed simplex relation
% embeddings prevent shuffled labels from becoming independent trainable
% capacity buckets; trainable capacity is shared across relation labels.
% relational-policy-v2.8 (2026-10-21): replace the label-symmetric cyclic
% codebook by fixed ontology-role descriptors for message coefficients and
% attention embeddings. Architecture, trainable parameter count, PPO and
% the common task contract are unchanged.
% relational-policy-v2.10 (2026-10-21): retain the node-shared readout but
% replace the arithmetic mean by the variance-preserving 1/sqrt(7) sum.
% This restores the v2.8 initialization/backward scale without restoring
% node-specific shortcut parameters; total capacity remains 6,101.
% relational-policy-v2.11 (2026-10-22): replace permutation-invariant node
% pooling by a fixed equal-energy real-Fourier node code. Node identity is
% retained without trainable node-specific weights or a selected sink;
% encoder and total parameter counts remain 1,800 and 6,101.
% relational-policy-v2.12 (2026-10-22): after the v2.11 confirmatory result
% (no registered relation effect), read only the ontology sink
% LandingCondition in the same ungated two-layer R-GAT, so the other nodes
% reach the policy only through typed edges. Totals remain 1,800 and 6,101.
% relational-policy-v2.13 (2026-10-23): graph features tosm7_v3, the readout
% sink LandingCondition latent (typeId only). Its unsigned touchdown ratios
% gave the readout a copy of the relative-velocity / descent evidence that
% bypassed every typed edge with 5-29x the o_t gain. Encoder, readout,
% parameters (1,800 / 6,101), PPO and the plain-PPO path are unchanged
% (landing2d.rl.baselineVersion).
% relational-policy-v2.14 (2026-10-23, user decision after the failed v2.13
% gate): tosm7_v4, LandingCondition holds the signed o_t entries of the same
% five touchdown quantities (o_t gain and sign) instead of nothing. Encoder,
% readout, parameters, PPO and the plain-PPO path are unchanged.
version = 'relational-policy-v2.14';
end
