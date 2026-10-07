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
% 두 부호기는 같은 그래프 G_t와 구조를 쓰되, 정책 부호기는 PolicyNode를,
% 가치 부호기는 ValueNode를 읽습니다.
if nargin < 3 || isempty(gs)
    gs = landing2d.graphstate.defaultGraphStateConfig();
end
[policyEncoder,spec] = landing2d.graphstate.encoderInit(gs,rl.observationDim,rs);
valueEncoder = landing2d.graphstate.encoderInit(gs,rl.observationDim,rs);
if gs.freezeStaticBackbone && ismember(gs.stateRepresentation, ...
        {'context_gat','context_rgat'})
    % Actor and critic use the same causal representation at initialization.
    % PPO may adapt their small attention/readout heads independently, while
    % the shared static transforms remain frozen.
    valueEncoder = policyEncoder;
end
inputDim = spec.graphDim;
% Component streams make the shared raw-semantic part of context_flat and
% raw_plus_groups start from exactly the same MLP. Encoder size no longer
% changes the random policy initialization, removing a major A/B confound.
policyRs = RandStream('threefry','Seed',rl.seed+31001);
valueRs = RandStream('threefry','Seed',rl.seed+31002);
policyExtraRs = RandStream('threefry','Seed',rl.seed+31003);
valueExtraRs = RandStream('threefry','Seed',rl.seed+31004);
if strcmp(spec.readout,'raw_plus_groups')
    agent.policy.mean = landing2d.rl.mlpInit([spec.stateDim,rl.hiddenSize, ...
        rl.hiddenSize,rl.actionDim],0.1,policyRs);
    agent.value.net = landing2d.rl.mlpInit([spec.stateDim,rl.hiddenSize, ...
        rl.hiddenSize,1],0.1,valueRs);
    % Separate zero-output relational residual heads preserve the exact flat
    % policy computation. Their nonzero W lets gradients reach the graph
    % readout when staged adaptation begins, while zero graph context keeps
    % the initial action/value identical to semantic-flat PPO.
    agent.policy.relation.W = 0.05*randn(policyExtraRs, ...
        rl.actionDim,inputDim-spec.stateDim);
    agent.value.relation.W = 0.05*randn(valueExtraRs, ...
        1,inputDim-spec.stateDim);
else
    agent.policy.mean = landing2d.rl.mlpInit([inputDim,rl.hiddenSize, ...
        rl.hiddenSize,rl.actionDim],0.1,policyRs);
    agent.value.net = landing2d.rl.mlpInit([inputDim,rl.hiddenSize, ...
        rl.hiddenSize,1],0.1,valueRs);
end
agent.policy.logStd = rl.initialLogStd*ones(rl.actionDim,1);
if rl.actionDim == 3 && isfield(rl,'lateralInitialLogStd')
    % 3D option only: separate initial exploration noise for a_y.
    agent.policy.logStd(2) = rl.lateralInitialLogStd;
end
agent.policy.encoder = policyEncoder;
agent.value.encoder = valueEncoder;
agent.encoderSpec = spec;
agent.rl = rl;
end
