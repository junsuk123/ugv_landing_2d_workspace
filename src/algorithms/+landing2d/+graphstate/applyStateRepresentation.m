function cfg = applyStateRepresentation(cfg,mode)
% APPLYSTATEREPRESENTATION  Change only the state representation of a configuration.
%   cfg = landing2d.graphstate.applyStateRepresentation(cfg,'context_rgat')
% Reward, actions, environment, termination, PPO and seeds are untouched, so
% a comparison differs in the representation alone. The default checkpoint
% name follows the representation (landing2d.config.applyMethod then sets the
% run-specific name).
cfg.graphState.stateRepresentation = mode;
% R-GAT arms: relation types act through their operator class (typed_v1,
% landing2d.graphstate.contextSchema relationOperators). 'additive_v1' (every
% relation an additive message, the comparison_registry_v3/v4 encoder) can be
% set explicitly afterwards. Plain PPO has no relations and no such field.
if strcmp(mode,'context_rgat') && ~isfield(cfg.graphState,'relationOperators')
    cfg.graphState.relationOperators = 'typed_v1';
elseif ~strcmp(mode,'context_rgat') && isfield(cfg.graphState,'relationOperators')
    cfg.graphState = rmfield(cfg.graphState,'relationOperators');
end
landing2d.graphstate.validateGraphStateConfig(cfg.graphState);
cfg.rl.policyFile = sprintf('ppo_%s_planar_visibility_v2.mat',mode);
end
