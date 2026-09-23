function agent = agentInit(rl,rs,gs)
% AGENTINIT  가우시안 정책(평균망 + log 표준편차)과 가치망 생성.
% 정책의 출력은 제한 이전 명령이며, 환경에서 tanh로 가속도 한계에 맞춥니다.
%
% gs(선택)는 상태 표현 설정입니다. 주지 않거나 stateRepresentation이 'baseline'이면
% 부호기가 항등이고 정책/가치망이 관측 벡터를 그대로 받습니다.
%
% 부호기는 정책과 가치가 따로 갖습니다(각각 agent.policy.encoder, agent.value.encoder).
% 두 망은 이미 학습률과 Adam 상태가 분리되어 있어, 부호기를 각 구조체 안에 두면
% 기존 최적화기 구성을 그대로 재사용할 수 있습니다. 공유 부호기로 만들면 서로 다른
% 학습률의 기울기를 한 파라미터에 합쳐야 해서 변경 폭이 더 커집니다.
% 두 부호기는 같은 그래프 G_t를 받고 같은 구조를 쓰므로 표현의 의미는 같습니다.
if nargin < 3 || isempty(gs)
    gs = landing2d.graphstate.defaultGraphStateConfig();
end
[policyEncoder,spec] = landing2d.graphstate.encoderInit(gs,rl.observationDim,rs);
valueEncoder = landing2d.graphstate.encoderInit(gs,rl.observationDim,rs);
inputDim = spec.graphDim;
sizes = [inputDim,rl.hiddenSize,rl.hiddenSize,rl.actionDim];
agent.policy.mean = landing2d.rl.mlpInit(sizes,0.1,rs);
agent.policy.logStd = rl.initialLogStd*ones(rl.actionDim,1);
agent.policy.encoder = policyEncoder;
agent.value.net = landing2d.rl.mlpInit([inputDim,rl.hiddenSize, ...
    rl.hiddenSize,1],0.1,rs);
agent.value.encoder = valueEncoder;
agent.encoderSpec = spec;
agent.rl = rl;
end
