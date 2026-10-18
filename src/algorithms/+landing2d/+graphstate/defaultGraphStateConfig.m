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
% Actor 35-38 and Critic 35-30 hidden units make the R-GAT arms exactly
% 6,101 trainable parameters, equal to plain PPO (rl.hiddenSize).
gs.hiddenDim = 16;
gs.relationDim = 4;
gs.graphDim = 16;
gs.policyHiddenSizes = [35,38];
gs.valueHiddenSizes = [35,30];
gs.initScale = 0.12;
gs.encoderLearnRate = 1e-4;
% Input-dependent attention: alpha_ij^(r)(X_t) follows the current node
% features. 'fixed_relation_v1' (observation-independent relation logits,
% same parameters) remains available for a deliberate comparison.
gs.attentionMode = 'input_dependent_v1';
gs.readout = 'grouped_factorized';
gs.policyFile = 'rl_policy_graphstate.mat';
end
