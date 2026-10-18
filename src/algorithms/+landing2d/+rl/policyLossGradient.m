function [grads,encoderGrads,stats] = policyLossGradient(agent,policyInput,preTanhAction,oldLogProbability,advantage,rl)
% POLICYLOSSGRADIENT  Gradient of the common clipped PPO actor loss (head and encoder).
%   [grads,encoderGrads,stats] = landing2d.rl.policyLossGradient(agent,policyInput, ...
%       preTanhAction,oldLogProbability,advantage,rl)
% Batch columns: policyInput (12-D o_t or flattened node features),
% preTanhAction (sampled Gaussian action before tanh), its log probability
% under the behaviour policy and the normalized GAE advantage.
% The same loss for every method (landing2d.rl.ppoTrain): clipped surrogate
% plus entropy bonus on the Gaussian pre-tanh action. GRADS holds the actor
% head (mean MLP, logStd); ENCODERGRADS the actor encoder (empty struct for
% plain PPO), reached through dLoss/d(embedding) of the same backward pass.
% Unclipped values: landing2d.util.clipGradient is applied by the caller.
% STATS (diagnostic, no effect on the update): surrogate loss, entropy, the
% approximate KL E[(r - 1) - log r], clip fraction and the pre-clip gradient
% norms of the head and the encoder (NaN for plain PPO).
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.policy.encoder, ...
    agent.encoderSpec,policyInput,'policy');
[mu,cache] = landing2d.rl.mlpForward(agent.policy.mean,g);
sigma = exp(agent.policy.logStd);
z = (preTanhAction-mu)./sigma;
logProbability = sum(-0.5*z.^2-agent.policy.logStd-0.5*log(2*pi),1);
probabilityRatio = exp(logProbability-oldLogProbability);
clippedRatio = min(max(probabilityRatio,1-rl.clipRatio),1+rl.clipRatio);
unclippedSelected = (probabilityRatio.*advantage) <= (clippedRatio.*advantage);
batch = numel(advantage);
% Clipped samples give no gradient (standard PPO).
dLogProbability = -(advantage.*probabilityRatio.*double(unclippedSelected))/batch;
dMu = dLogProbability.*(z./sigma);
[grads.mean,dG] = landing2d.rl.mlpBackward(agent.policy.mean,cache,dMu);
grads.logStd = sum(dLogProbability.*(z.^2-1),2)-rl.entropyWeight;
encoderGrads = struct();
hasGraphEncoder = ~isempty(fieldnames(agent.policy.encoder));
if hasGraphEncoder
    encoderGrads = landing2d.graphstate.encoderBackward(agent.policy.encoder, ...
        agent.encoderSpec,encoderCache,dG);
end
if nargout > 2
    encoderNorm = NaN;
    if hasGraphEncoder, encoderNorm = landing2d.util.gradientNorm(encoderGrads); end
    stats = struct('loss',-mean(min(probabilityRatio.*advantage,clippedRatio.*advantage)), ...
        'entropy',sum(agent.policy.logStd+0.5*log(2*pi*exp(1))), ...
        'approxKL',mean((probabilityRatio-1)-log(probabilityRatio)), ...
        'clipFraction',mean(abs(probabilityRatio-1)>rl.clipRatio), ...
        'headGradNorm',landing2d.util.gradientNorm(grads),'encoderGradNorm',encoderNorm);
end
end
