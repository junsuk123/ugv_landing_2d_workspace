function [preTanhAction,logProbability,mu] = policyAction(agent,policyInput,rs,deterministic)
% POLICYACTION  Gaussian policy action for policy input(s) and its log probability.
%   [preTanhAction,logp,mu] = landing2d.rl.policyAction(agent,policyInput,rs,deterministic)
% policyInput is the 12-D o_t (plain PPO) or the flattened TOSM node features
% of the same o_t (R-GAT arms); after the encoder both share the same MLP head.
% preTanhAction is the unbounded Gaussian sample (mu when deterministic) and
% mu the pre-tanh actor mean; tanh(preTanhAction) is the normalized action in
% [-1,1] and the environment applies limits .* tanh(preTanhAction) as the
% requested acceleration [m/s^2].
g = landing2d.graphstate.encoderForward(agent.policy.encoder,agent.encoderSpec,policyInput,'policy');
mu = landing2d.rl.mlpForward(agent.policy.mean,g);
sigma = exp(agent.policy.logStd);
if deterministic
    preTanhAction = mu;
else
    preTanhAction = mu+sigma.*randn(rs,size(mu));
end
logProbability = sum(-0.5*((preTanhAction-mu)./sigma).^2-agent.policy.logStd-0.5*log(2*pi));
end
