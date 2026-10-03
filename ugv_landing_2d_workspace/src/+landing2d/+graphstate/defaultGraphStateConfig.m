function gs = defaultGraphStateConfig()
% DEFAULTGRAPHSTATECONFIG  PPO에 넣을 상태 표현 설정.
%
% 제안 모델과 기준 모델의 차이는 오직 이 설정 하나입니다. 보상, 행동, 환경,
% 종료 조건, PPO 알고리즘과 하이퍼파라미터는 두 모델이 완전히 같은 것을 씁니다.
%
% stateRepresentation
%   'baseline'      기준 모델. landing2d.rl.observation의 11차원 벡터를 그대로
%                   정책/가치망에 넣습니다. 부호기가 항등이므로 수치가 기존과 같습니다.
%   'semantic_flat' 그래프 모델과 같은 의미 노드 특징을 평탄화해 MLP에 넣습니다.
%                   정보 추가 효과와 그래프 구조 효과를 분리하는 대조군입니다.
%   'node_pool'     제거 실험 B. 온톨로지 노드 특징을 노드별로 사영한 뒤 읽기만 합니다.
%                   메시지 전달(간선)이 없습니다.
%   'gat'           제거 실험 C. 그래프 구조는 쓰되 관계 유형을 하나로 합칩니다.
%                   자기 간선까지 같은 인접 행렬에 넣는 표준 GAT 구성입니다.
%   'ontology_rgat' 제안 모델. 관계 유형을 유지한 R-GAT으로 그래프 전체를 부호화하고,
%                   PolicyNode/ValueNode 임베딩을 Actor/Critic이 직접 읽습니다.
%
% 네 설정 모두 같은 PPO 구현(landing2d.rl.ppoTrain)을 공유합니다.
gs.stateRepresentation = 'baseline';

%% 그래프 부호기 (stateRepresentation이 'baseline'이 아닐 때만 사용)
% 9개 의미 노드에 PolicyNode/ValueNode를 붙이고 두 층의 message passing으로
% 정보를 모읍니다. hiddenDim은 각 노드와 두 의사결정 노드의 임베딩 폭입니다.
gs.hiddenDim = 16;           % Lightweight one-layer R-GAT node embedding.
gs.relationDim = 4;          % Compact relation embedding.
gs.graphDim = 32;            % mean/meanmax 제거 실험의 출력 폭 (가상 노드는 hiddenDim)
gs.initScale = 0.12;         % 부호기 초기 가중치 배율
gs.encoderLearnRate = 3e-4;  % 부호기 Adam 학습률

%% 그래프 수준 읽기 (readout)
%   'decision_nodes' Actor는 PolicyNode, Critic은 ValueNode를 직접 읽음 (기본)
%   'meanmax'        tanh(Wg*[mean(H_t,2); max(H_t,2)]+bg)   (제거 실험)
%   'mean'           mean(H_t,2)                              (제거 실험)
% decision_nodes에는 전역 pooling 파라미터 Wg가 없습니다. PPO 기울기가 각 가상
% 노드에서 R-GAT 관계형 message passing으로 직접 전달됩니다.
gs.readout = 'meanmax';

%% Causal graph pretraining and PPO-time adaptation
% Pretraining reconstructs masked current-time node features only. It never
% consumes actions, rewards, outcomes, future samples, or simulator truth.
gs.freezeStaticBackbone = true;
gs.pretrain = struct('enabled',true,'episodes',12,'maxDecisions',80, ...
    'epochs',8,'batchSize',128,'maskProbability',0.25, ...
    'learnRate',1e-3,'seedOffset',7000000);

%% 의미 채널 정규화 기준. landing2d.ontology.defaultOntologyConfig와 같은 뜻이지만
% 여기서는 관측만으로 계산합니다(참값 없음). 별도로 두어 보상 설계 쪽 설정을
% 바꿔도 상태 표현이 따라 바뀌지 않게 합니다.
%
% 중요: 이 값들은 잘라내는 지점이 아니라 채널 값이 **0.5가 되는 지점**입니다
% (landing2d.graphstate.observationSemantics의 부드러운 포화 x/(x+scale)).
% 그래서 이 값보다 훨씬 작은 구간과 훨씬 큰 구간이 모두 구분됩니다.
%
% 예전에는 잘라내기 min(1,x/scale)를 썼고, 그래서 기준값 하나로 두 구간을
% 동시에 덮을 수 없었습니다. 좁게 잡으면(2.5 / 6.0) 표본의 74.6%%에서
% RelativeDistance가 1로 포화해 고도가 사라졌고, 넓게 잡으면(10 / 25) 이번에는
% 패드 근처가 전부 0으로 뭉개져 종말단계 하강 제어를 못 했습니다.
% 아래 값은 접지 직전(수 cm)과 탐색 고도(십수 m)가 모두 살아 있도록 고른 것입니다.
gs.positionScale = 1.0;      % 수평 오차 추정값이 0.5가 되는 지점 [m]
gs.distanceScale = 3.0;      % 상대거리 hypot(오차, 고도)가 0.5가 되는 지점 [m]
gs.alignScale = 1.0;         % 정렬도 exp 감쇠 [m]
gs.speedScale = 1.0;         % 추종 안정도 exp 감쇠 [m/s]
gs.searchScale = 2.0;        % 재탐색 지속 시간이 0.5가 되는 지점 [s]
gs.padSpeedScale = 3.0;      % 마지막 관측 패드 속도가 0.5가 되는 지점 [m/s]

%% 학습 조건
% true면 제안 모델이 기준 유도 법칙을 교사로 쓰지 않고 무작위 초기 정책에서
% PPO만으로 학습합니다(landing2d.rl.applyScratchSettings).
%
% 기본값이 true인 이유: 모방 학습으로 초기화하면 정책이 유도 법칙의 거동을 그대로
% 물려받습니다. 그러면 패드가 시야에서 사라진 구간에서도 유도 법칙과 같은 움직임을
% 보여, 온톨로지 그래프 상태가 무엇을 바꾸는지 볼 수 없습니다. 실제로 두 비교군을
% 모두 모방 학습으로 초기화했을 때 비가시 구간 수평 오차 RMS 차이가 기준 모델과
% 제안 모델 사이에서 0.195 m로, 유도 법칙 대비 차이(0.486~0.616 m)보다 훨씬
% 작았습니다. 즉 제안 모델이 기준 모델을 따라간 것이 아니라 둘 다 교사를 따라간
% 것입니다.
%
% 대가: 기준 모델은 모방 학습 + PPO 60반복, 제안 모델은 교사 없이 2500반복이 되어
% **상태 표현 외의 변수가 함께 달라집니다.** 이 차이는 숨기지 않고
% landing2d.graphstate.assertSameProblem이 목록으로 돌려주고 run_all이 출력합니다.
% 상태 표현만의 효과를 보려면 false로 두거나 기준 모델에도 같은 설정을 적용하십시오.
%
% 학습 시간: 약 4.5 s/반복이므로 2500반복에 약 3시간입니다.
gs.useScratchSettings = true;

%% 저장
gs.policyFile = 'rl_policy_graphstate.mat';
end
