function [value,cache] = valueForward(agent,S)
% VALUEFORWARD  가치망 V(G_t). R-GAT의 ValueNode 임베딩을 직접 읽습니다.
% 가치망 전용 특권 정보는 없습니다. 기준 모델과 제안 모델 모두 마찬가지입니다.
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.value.encoder, ...
    agent.encoderSpec,S,'value');
[value,netCache] = relationValue(agent,g);
if nargout > 1
    cache = struct('encoder',encoderCache,'net',netCache,'g',g);
end
end

function [value,cache]=relationValue(agent,g)
if isfield(agent.value,'relation')
    raw=g(1:agent.encoderSpec.stateDim,:);
    context=g(agent.encoderSpec.stateDim+1:end,:);
    [value,cache]=landing2d.rl.mlpForward(agent.value.net,raw);
    value=value+agent.value.relation.W*context;
else
    [value,cache]=landing2d.rl.mlpForward(agent.value.net,g);
end
end
