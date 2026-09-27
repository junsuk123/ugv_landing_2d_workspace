function [value,cache] = valueForward(agent,S)
% VALUEFORWARD  가치망 V(G_t). R-GAT의 ValueNode 임베딩을 직접 읽습니다.
% 가치망 전용 특권 정보는 없습니다. 기준 모델과 제안 모델 모두 마찬가지입니다.
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.value.encoder, ...
    agent.encoderSpec,S,'value');
[value,netCache] = landing2d.rl.mlpForward(agent.value.net,g);
if nargout > 1
    cache = struct('encoder',encoderCache,'net',netCache,'g',g);
end
end
