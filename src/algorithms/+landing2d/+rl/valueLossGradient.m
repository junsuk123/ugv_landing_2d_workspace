function [grads,encoderGrads,stats] = valueLossGradient(agent,policyInput,valueTarget)
% VALUELOSSGRADIENT  Gradient of the common value MSE loss (head and encoder).
%   [grads,encoderGrads,stats] = landing2d.rl.valueLossGradient(agent,policyInput,valueTarget)
% valueTarget is the GAE value target (advantage + V, landing2d.rl.computeAdvantage).
% GRADS.net is the critic MLP; ENCODERGRADS the critic encoder (empty struct
% for plain PPO). Unclipped values: the caller clips. STATS (diagnostic):
% the MSE and the pre-clip gradient norms of head and encoder (NaN for plain PPO).
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.value.encoder, ...
    agent.encoderSpec,policyInput,'value');
[prediction,cache] = landing2d.rl.mlpForward(agent.value.net,g);
dValue = 2*(prediction-valueTarget)/numel(valueTarget);
[grads.net,dG] = landing2d.rl.mlpBackward(agent.value.net,cache,dValue);
encoderGrads = struct();
hasGraphEncoder = ~isempty(fieldnames(agent.value.encoder));
if hasGraphEncoder
    encoderGrads = landing2d.graphstate.encoderBackward(agent.value.encoder, ...
        agent.encoderSpec,encoderCache,dG);
end
if nargout > 2
    encoderNorm = NaN;
    if hasGraphEncoder, encoderNorm = landing2d.util.gradientNorm(encoderGrads); end
    stats = struct('loss',mean((prediction-valueTarget).^2), ...
        'headGradNorm',landing2d.util.gradientNorm(grads),'encoderGradNorm',encoderNorm);
end
end
