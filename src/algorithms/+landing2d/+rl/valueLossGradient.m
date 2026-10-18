function [grads,encoderGrads,stats] = valueLossGradient(agent,X,R)
% VALUELOSSGRADIENT  Gradient of the common value MSE loss (head and encoder).
%   [grads,encoderGrads,stats] = landing2d.rl.valueLossGradient(agent,X,R)
% GRADS.net is the critic MLP; ENCODERGRADS the critic encoder (empty struct
% for plain PPO). Unclipped values: the caller clips. STATS (diagnostic):
% the MSE and the pre-clip gradient norms of head and encoder (NaN for plain PPO).
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.value.encoder, ...
    agent.encoderSpec,X,'value');
[prediction,cache] = landing2d.rl.mlpForward(agent.value.net,g);
dValue = 2*(prediction-R)/numel(R);
[grads.net,dG] = landing2d.rl.mlpBackward(agent.value.net,cache,dValue);
encoderGrads = struct();
graph = ~isempty(fieldnames(agent.value.encoder));
if graph
    encoderGrads = landing2d.graphstate.encoderBackward(agent.value.encoder, ...
        agent.encoderSpec,encoderCache,dG);
end
if nargout > 2
    encoderNorm = NaN;
    if graph, encoderNorm = landing2d.util.gradientNorm(encoderGrads); end
    stats = struct('loss',mean((prediction-R).^2), ...
        'headGradNorm',landing2d.util.gradientNorm(grads),'encoderGradNorm',encoderNorm);
end
end
