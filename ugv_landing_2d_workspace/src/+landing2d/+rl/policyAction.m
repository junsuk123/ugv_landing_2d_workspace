function [u,logProbability,mu] = policyAction(agent,S,rs,deterministic)
% POLICYACTION  상태 하나에 대한 행동 표본과 log 확률.
%
% S는 정책이 받는 상태입니다. 기준 모델에서는 landing2d.rl.observation의 관측
% 벡터이고, 제안 모델에서는 펴 놓은 온톨로지 그래프 X_t입니다. 어느 쪽이든
% 부호기를 지나 g_t가 되고, 그 다음은 두 모델이 완전히 같습니다.
% 행동의 정의와 한계는 바뀌지 않습니다(landing2d.rl.actionFromCommand).
g = landing2d.graphstate.encoderForward(agent.policy.encoder, ...
    agent.encoderSpec,S);
mu = landing2d.rl.mlpForward(agent.policy.mean,g);
sigma = exp(agent.policy.logStd);
if deterministic
    u = mu;
else
    u = mu+sigma.*randn(rs,size(mu));
end
logProbability = sum(-0.5*((u-mu)./sigma).^2-agent.policy.logStd ...
    -0.5*log(2*pi));
end
