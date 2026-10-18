function version = algorithmVersion()
% ALGORITHMVERSION  Behaviour-changing implementation version of trained policies.
% Bump when a code change makes a saved policy incompatible although the
% numeric configuration is unchanged. relational-policy-v1.0 (2026-10-17):
% identical PPO loss for every method (no R-GAT-only smoothing term),
% input-dependent attention, reserved training-episode seed range, 2 x 2
% scenario family with initial relative-motion offsets.
version = 'relational-policy-v1.0';
end
