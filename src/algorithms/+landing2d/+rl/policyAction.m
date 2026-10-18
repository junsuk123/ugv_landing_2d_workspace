function [u,logProbability,mu] = policyAction(agent,S,rs,deterministic)
% POLICYACTION  Gaussian policy action for state(s) S and its log probability.
%   [u,logp,mu] = landing2d.rl.policyAction(agent,S,rs,deterministic)
% S is the 12-D o_t (plain PPO) or the flattened TOSM node features of the
% same o_t (R-GAT arms); after the encoder both share the same MLP head. mu is
% the pre-tanh actor mean; the environment applies limits .* tanh(u).
g = landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,S,'policy');
mu = landing2d.rl.mlpForward(agent.policy.mean,g);
sigma = exp(agent.policy.logStd);
if deterministic
    u = mu;
else
    u = mu+sigma.*randn(rs,size(mu));
end
logProbability = sum(-0.5*((u-mu)./sigma).^2-agent.policy.logStd-0.5*log(2*pi));
end
