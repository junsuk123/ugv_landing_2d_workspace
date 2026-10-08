function out = probeActions(agent,bank,c,run)
% PROBEACTIONS  고정 probe 은행에서 정책 하나의 결정론적 명령 (폐루프 되먹임 없음).
% 입력 상태는 은행의 정책 입력만 씁니다. 일반 PPO는 12차원 관측 벡터, 그래프 비교군은
% 같은 o_t에서 만든 그래프 노드 특징을 받습니다(노드 특징은 관계 배치와 무관하며,
% 교란군은 자기 체크포인트에 저장된 그래프 위상으로 순전파). 세 비교군은 o_t만 받는
% 비재귀 정책이고 H_t는 공통 관측 기억이 정책과 무관하게 재생하므로 probe마다
% 독립으로 평가합니다. 내부 상태가 있는 정책은 같은 prefix를 정책별로 재생해야 하므로
% 거부합니다. 예측 행동을 은행의 이후 관측에 넣지 않습니다.
%   actorMean              tanh 이전 actor 평균 (A x P x nScale, 진단용)
%   requestedAcceleration  tanh(actorMean) x 축별 한계, 감독기 적용 전 (A x P x nScale)
% RUN (선택): landing2d.rl.runIdentity 결과, 출력에 그대로 기록합니다.
if nargin < 4, run = struct(); end
assert(strcmp(bank.schemaVersion,'fixed_probe_bank_v1'),'landing2d:ProbeBank', ...
    'Unknown probe bank version.');
assert(~(isfield(agent.encoderSpec,'recurrent') && agent.encoderSpec.recurrent), ...
    'landing2d:RecurrentProbe', ...
    'Recurrent policies need a per-policy replay of the shared probe prefix.');
limits = landing2d.environment.actionLimits(c);
assert(isequal(limits(:)',bank.meta.actionLimits(:)'),'landing2d:ProbeBank', ...
    'The probe bank was built with different action limits.');
assert(strcmp(c.experiment.observationSchema.version,bank.meta.observationVersion), ...
    'landing2d:ProbeBank','The probe bank was built for another observation schema.');
mode = agent.encoderSpec.mode;
if strcmp(mode,'baseline')
    states = bank.policyInput.vector;
else
    % The relation-shuffled schema keeps the node features and appends a
    % '_relation_shuffle' suffix to the canonical variant.
    schema = agent.encoderSpec.schema;
    assert(isequal(schema.nodeNames,bank.meta.graphNodeNames) ...
        && isequal(schema.featureNames,bank.meta.graphFeatureNames) ...
        && startsWith(schema.variant,bank.meta.graphVariant), ...
        'landing2d:ProbeBank','The probe bank graph features do not match the agent schema.');
    states = bank.policyInput.graph;
end
assert(size(states,1) == agent.encoderSpec.stateDim,'landing2d:ProbeBank', ...
    'Probe state dimension %d differs from the agent state dimension %d.', ...
    size(states,1),agent.encoderSpec.stateDim);
[~,P,nS] = size(states);
actorMean = zeros(numel(limits),P,nS);
timer = tic;
for s = 1:nS
    [~,~,actorMean(:,:,s)] = landing2d.rl.policyAction(agent,states(:,:,s),[],true);
end
seconds = toc(timer);
requested = limits(:).*tanh(actorMean);
out = struct('schemaVersion','probe_actions_v1','run',run, ...
    'stateRepresentation',mode,'scales',bank.meta.scales, ...
    'actorMean',actorMean,'requestedAcceleration',requested, ...
    'probeCount',P,'batchInferenceSeconds',seconds, ...
    'bankConfigHash',bank.meta.configHash);
end
