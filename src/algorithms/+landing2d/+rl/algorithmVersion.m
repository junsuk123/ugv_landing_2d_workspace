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
version = 'relational-policy-v2.0';
end
