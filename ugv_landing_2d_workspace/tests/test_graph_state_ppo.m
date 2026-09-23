function test_graph_state_ppo()
% TEST_GRAPH_STATE_PPO  제안 모델이 기준 모델과 같은 문제를 푸는지 확인.
%
% 요구사항 20번의 Test 1(기준 회귀), Test 2(보상 동일), Test 3(행동 공간 동일),
% Test 9(시간 부호기 없음), Test 10(온톨로지가 보상에 개입하지 않음)에 해당합니다.
c = landing2d.config.defaultConfig();
c = landing2d.config.applyOptions(c,struct('tEnd',6,'segmentTimes',[2,4], ...
    'scenarioSpeeds',[1,3,1.5],'animate',false,'figureVisible',false, ...
    'saveResults',false));
c.rl.bcEpisodes = 2;
c.rl.bcEpochs = 3;
c.rl.ppoIterations = 2;
c.rl.episodesPerIteration = 2;
c.rl.ppoEpochs = 2;
c.rl.evaluateEvery = 1;
c.rl.valueWarmup = 0;
c.rl.parallelEpisodes = false;
c.rl.verbose = false;
c.graphState.hiddenDim = 6;
c.graphState.graphDim = 5;
% 이 테스트는 배선을 검사하는 것이라 학습을 짧게 유지해야 합니다.
% 교사 없는 학습 설정(기본값)은 반복 수를 2500으로 덮어쓰므로 여기서는 끕니다.
% 그 설정 자체는 아래 '학습 조건 차이' 항목에서 따로 검사합니다.
c.graphState.useScratchSettings = false;

baselineCfg = landing2d.graphstate.applyStateRepresentation(c,'baseline');
proposedCfg = landing2d.graphstate.applyStateRepresentation(c,'ontology_rgat');
landing2d.config.validateConfig(baselineCfg);
landing2d.config.validateConfig(proposedCfg);

%% Test 10 - 상태 표현을 바꾼다고 보상 설정이 달라지면 안 됩니다.
% assertSameProblem은 보상/행동/환경/종료 조건을 대조하고, 학습 조건 차이는
% 멈추지 않고 목록으로 돌려줍니다.
differences = landing2d.graphstate.assertSameProblem(baselineCfg,proposedCfg);
assert(isempty(differences), ...
    'With useScratchSettings=false the training regime must be identical.');
assert(~isfield(proposedCfg,'ontologyRewardApplied'), ...
    'The proposed path must not run through landing2d.ontology.applyDesign.');
assert(baselineCfg.useLegacyOntologyReward == false, ...
    'The legacy ontology reward path must be off by default.');
% 옛 경로를 지나면 표식이 남고, assertSameProblem이 이를 거부해야 합니다.
legacy = proposedCfg;
legacy.ontologyRewardApplied = true;
assertThrows(@()landing2d.graphstate.assertSameProblem(baselineCfg,legacy), ...
    'landing2d:LegacyRewardInProposedPath');
% 보상 계수를 건드리면 역시 거부해야 합니다.
tampered = proposedCfg;
tampered.rl.captureWeight = tampered.rl.captureWeight+0.1;
assertThrows(@()landing2d.graphstate.assertSameProblem(baselineCfg,tampered), ...
    'landing2d:ProblemMismatch');

%% 학습 조건 차이 - 교사 없는 학습은 막지 말고 목록으로 보고해야 합니다.
% 제안 모델은 기준 유도 법칙을 모방하지 않고 처음부터 학습합니다. 모방 학습으로
% 초기화하면 비가시 구간 거동까지 유도 법칙을 물려받아, 상태 표현의 효과를
% 볼 수 없기 때문입니다.
scratchCfg = c;
scratchCfg.graphState.useScratchSettings = true;
scratchCfg = landing2d.graphstate.applyStateRepresentation(scratchCfg,'ontology_rgat');
assert(~scratchCfg.rl.useBehaviorClone, ...
    'The proposed arm must train without behaviour cloning by default.');
assert(baselineCfg.rl.useBehaviorClone, ...
    'The baseline arm keeps its behaviour cloning.');
scratchDiff = landing2d.graphstate.assertSameProblem(baselineCfg,scratchCfg);
assert(~isempty(scratchDiff), ...
    'A different training regime must be reported, not silently accepted.');
assert(any(contains(scratchDiff,'useBehaviorClone')), ...
    'The report must name useBehaviorClone.');
% 보상과 행동은 학습 조건이 달라도 여전히 같아야 합니다.
assert(scratchCfg.rl.captureWeight == baselineCfg.rl.captureWeight);
assert(scratchCfg.rl.distanceWeight == baselineCfg.rl.distanceWeight);
assert(scratchCfg.rl.actionDim == baselineCfg.rl.actionDim);

%% Test 3 - 행동 공간이 완전히 같아야 합니다.
rs = RandStream('threefry','Seed',5);
baselineAgent = landing2d.rl.agentInit(baselineCfg.rl,rs,baselineCfg.graphState);
rs = RandStream('threefry','Seed',5);
proposedAgent = landing2d.rl.agentInit(proposedCfg.rl,rs,proposedCfg.graphState);
assert(baselineCfg.rl.actionDim == proposedCfg.rl.actionDim);
assert(size(baselineAgent.policy.mean.W{end},1) == baselineCfg.rl.actionDim);
assert(size(proposedAgent.policy.mean.W{end},1) == proposedCfg.rl.actionDim, ...
    'The proposed actor must produce the same action dimension.');
assert(numel(baselineAgent.policy.logStd) == numel(proposedAgent.policy.logStd));
% 한계와 해석은 landing2d.rl.actionFromCommand 하나에서 나옵니다.
for u = {[0;0],[3;-3],[-10;10]}
    [ax,az] = landing2d.rl.actionFromCommand(u{1},baselineCfg);
    [bx,bz] = landing2d.rl.actionFromCommand(u{1},proposedCfg);
    assert(ax == bx && az == bz,'The action mapping must be identical.');
    assert(abs(ax) <= baselineCfg.axMax && abs(az) <= baselineCfg.azMax);
end

%% Test 1 - 기준 모델의 부호기는 항등이고, 정책 경로가 예전과 같아야 합니다.
o = randn(baselineCfg.rl.observationDim,1);
[~,~,mu] = landing2d.rl.policyAction(baselineAgent,o,[],true);
direct = landing2d.rl.mlpForward(baselineAgent.policy.mean,o);
assert(norm(mu-direct) < 1e-15, ...
    'With the baseline state the actor path must be the plain MLP forward.');
assert(landing2d.rl.valueForward(baselineAgent,o) ...
    == landing2d.rl.mlpForward(baselineAgent.value.net,o));
% 같은 설정이면 학습 결과가 재현되어야 합니다.
first = landing2d.rl.trainAgent(baselineCfg);
second = landing2d.rl.trainAgent(baselineCfg);
assert(isequal(first.policy.logStd,second.policy.logStd));
assert(norm(first.policy.mean.W{1}(:)-second.policy.mean.W{1}(:)) < 1e-12, ...
    'Baseline training must stay reproducible for a fixed seed.');

%% Test 2 - 같은 전이에 대해 보상이 완전히 같아야 합니다.
% 행동을 0으로 고정한 에이전트를 쓰면 상태 표현과 무관하게 궤적이 같아집니다.
% 그러면 두 경로의 보상열을 직접 비교할 수 있습니다.
baselineReward = constantActionReward(baselineCfg,baselineAgent);
proposedReward = constantActionReward(proposedCfg,proposedAgent);
assert(numel(baselineReward) == numel(proposedReward), ...
    'Identical transitions must produce the same number of rewards.');
assert(max(abs(baselineReward-proposedReward)) < 1e-12, ...
    sprintf(['r_proposed must equal r_baseline for identical transitions ' ...
    '(max difference %.3e).'],max(abs(baselineReward-proposedReward))));

%% Test 9 - 제안 모델에 순환 기억이 추가되지 않았는지.
forbidden = {'lstm','gru','rnn','hidden','recurrent','history','transformer'};
checkNoRecurrentFields(proposedAgent.policy,forbidden,'policy');
checkNoRecurrentFields(proposedAgent.value,forbidden,'value');
assert(numel(proposedAgent.policy.mean.W) == numel(baselineAgent.policy.mean.W), ...
    'The proposed actor must keep the baseline layer count.');
% 부호기는 현재 그래프만 보는 순수 함수여야 합니다. 같은 입력을 두 번 넣었을 때
% 결과가 달라지면 내부에 상태가 남아 있다는 뜻입니다.
state = randn(proposedAgent.encoderSpec.stateDim,4);
g1 = landing2d.graphstate.encoderForward(proposedAgent.policy.encoder, ...
    proposedAgent.encoderSpec,state);
g2 = landing2d.graphstate.encoderForward(proposedAgent.policy.encoder, ...
    proposedAgent.encoderSpec,state);
assert(isequal(g1,g2),'The graph encoder must be stateless.');
% 배치 안의 각 표본이 서로 영향을 주지 않아야 합니다 (시간 축 섞임 방지).
single = landing2d.graphstate.encoderForward(proposedAgent.policy.encoder, ...
    proposedAgent.encoderSpec,state(:,2));
assert(norm(single-g1(:,2)) < 1e-12, ...
    'Each time step must be encoded independently.');

%% Test 7 - PPO 학습 중 R-GAT 파라미터가 실제로 갱신되는지.
before = proposedAgent;
trained = landing2d.rl.trainAgent(proposedCfg);
encoderNames = fieldnames(trained.policy.encoder);
assert(~isempty(encoderNames),'The proposed agent must carry encoder weights.');
moved = false;
for i = 1:numel(encoderNames)
    key = encoderNames{i};
    delta = norm(trained.policy.encoder.(key)(:)-before.policy.encoder.(key)(:));
    assert(isfinite(delta));
    moved = moved || delta > 0;
end
assert(moved, ...
    'R-GAT parameters must receive gradients during PPO training.');
valueMoved = false;
valueNames = fieldnames(trained.value.encoder);
for i = 1:numel(valueNames)
    key = valueNames{i};
    valueMoved = valueMoved || norm(trained.value.encoder.(key)(:) ...
        -before.value.encoder.(key)(:)) > 0;
end
assert(valueMoved,'The critic encoder must be trained end to end as well.');

%% 제안 모델도 평가 경로가 기준 모델과 같은 로그 형식을 내는지.
[results,score,info] = landing2d.rl.evaluate(trained,proposedCfg);
reference = landing2d.simulation.run(proposedCfg);
assert(isequal(sort(fieldnames(results)),sort(fieldnames(reference))), ...
    'The proposed run must keep the baseline log format.');
assert(isfinite(score) && numel(info.landed) == size(proposedCfg.scenarioSpeeds,1));

%% 제거 실험 설정도 같은 PPO 코드로 끝까지 돌아야 합니다.
for mode = {'node_pool','gat'}
    ablation = landing2d.graphstate.applyStateRepresentation(c,mode{1});
    ablation.rl.ppoIterations = c.rl.ppoIterations;
    landing2d.graphstate.assertSameProblem(baselineCfg,ablation);
    agent = landing2d.rl.trainAgent(ablation);
    assert(all(isfinite(agent.policy.logStd)));
    assert(~isempty(fieldnames(agent.policy.encoder)));
end
end

% --------------------------------------------------------------------- 보조
function reward = constantActionReward(cfg,agent)
% 마지막 층을 0으로 만들어 어떤 상태에서도 명령이 0이 되게 합니다.
% 상태 표현이 무엇이든 궤적과 전이가 같아지므로 보상만 비교할 수 있습니다.
agent.policy.mean.W{end}(:) = 0;
agent.policy.mean.b{end}(:) = 0;
[r,s] = landing2d.rl.makeEpisode(cfg,1,cfg.rl,[]);
options = struct('deterministic',true,'collect',true,'rs',[]);
[~,traj] = landing2d.rl.rolloutEpisode(agent,r,s,cfg,options);
reward = traj.reward;
end

function checkNoRecurrentFields(node,forbidden,path)
if ~isstruct(node)
    return;
end
keys = fieldnames(node);
for i = 1:numel(keys)
    lowered = lower(keys{i});
    for j = 1:numel(forbidden)
        assert(~contains(lowered,forbidden{j}), ...
            sprintf('%s.%s looks like a temporal encoder the baseline lacks.', ...
            path,keys{i}));
    end
    checkNoRecurrentFields(node.(keys{i}),forbidden,[path '.' keys{i}]);
end
end

function assertThrows(fn,identifier)
threw = false;
try
    fn();
catch err
    threw = true;
    assert(strcmp(err.identifier,identifier), ...
        sprintf('Expected %s but got %s.',identifier,err.identifier));
end
assert(threw,sprintf('Expected the call to fail with %s.',identifier));
end
