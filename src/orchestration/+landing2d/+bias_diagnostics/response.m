function out = response(run,O,options)
% RESPONSE Deterministic actor response to observation columns O (10 x B).
%   options.correction = 'off'  sigma(beta) = 0 exactly (residual actors only)
%   options.spec                another encoderSpec with the same parameters
%                               (relation-typing swap; graph residual actors only)
% mu is the pre-tanh Gaussian mean, action = tanh(mu) in [-1,1], requested =
% limits .* action [m/s^2] before the supervisor. Residual actors also return
% their base mean and the mixed correction sigma(beta)*tanh(.) separately.
if nargin<3, options = struct(); end
agent = run.agent;
if isfield(options,'spec') && ~isempty(options.spec)
    assert(strcmp(agent.encoderSpec.correctionType,'graph') ...
        && isequal(options.spec.T.src,agent.encoderSpec.T.src) ...
        && isequal(options.spec.T.dst,agent.encoderSpec.T.dst));
    agent.encoderSpec = options.spec;
end
residual = strcmp(agent.encoderSpec.mode,'residual_actor');
if isfield(options,'correction') && strcmp(options.correction,'off')
    assert(residual); agent.policy.encoder.beta = -1000; % 1/(1+exp(1000)) == 0
end
[~,~,mu] = landing2d.rl.policyAction(agent,O,[],true);
limits = landing2d.environment.actionLimits(run.config);
out = struct('mu',mu,'action',tanh(mu),'requested',limits(:).*tanh(mu), ...
    'sigma',exp(agent.policy.logStd(:)));
if residual
    [~,cache] = landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,O,'policy');
    out.base = cache.baseMean; out.correction = cache.mix*cache.correction;
end
end
