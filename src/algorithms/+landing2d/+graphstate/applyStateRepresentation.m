function cfg = applyStateRepresentation(cfg,mode)
% APPLYSTATEREPRESENTATION  Change only the state representation of a configuration.
%   cfg = landing2d.graphstate.applyStateRepresentation(cfg,'context_rgat')
% Reward, actions, environment, termination, PPO and seeds are untouched, so
% a comparison differs in the representation alone. The default checkpoint
% name follows the representation (landing2d.config.applyMethod then sets the
% run-specific name).
cfg.graphState.stateRepresentation = mode;
landing2d.graphstate.validateGraphStateConfig(cfg.graphState);
cfg.rl.policyFile = sprintf('ppo_%s_planar_visibility_v2.mat',mode);
end
