function [value,cache] = valueForward(agent,policyInput)
% VALUEFORWARD  Critic V(policyInput) through the critic's own encoder (no privileged input).
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.value.encoder, ...
    agent.encoderSpec,policyInput,'value');
[value,netCache] = landing2d.rl.mlpForward(agent.value.net,g);
if nargout > 1
    cache = struct('encoder',encoderCache,'net',netCache,'g',g);
end
end
