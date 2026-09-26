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
%                   모든 노드를 읽어 그래프 수준 표현 g_t를 만듭니다.
%
% 네 설정 모두 같은 PPO 구현(landing2d.rl.ppoTrain)을 공유합니다.
gs.stateRepresentation = 'baseline';

%% 그래프 부호기 (stateRepresentation이 'baseline'이 아닐 때만 사용)
% 노드 9개를 g_t 한 벡터로 모으므로 읽기 단계가 병목이 되기 쉽습니다.
% 교사 모방 손실로 측정한 결과 16 -> 32에서 0.0949 -> 0.0667로 줄었고,
% 48로 더 키워도 0.0674로 나아지지 않았습니다. 그래서 32를 기본값으로 둡니다.
gs.hiddenDim = 32;           % R-GAT 노드 임베딩 폭 d. H_t는 [d x N]
gs.relationDim = 6;          % 관계 임베딩 폭
gs.graphDim = 32;            % 그래프 수준 표현 g_t의 차원 d_g
gs.initScale = 0.12;         % 부호기 초기 가중치 배율
gs.encoderLearnRate = 3e-4;  % 부호기 Adam 학습률

%% 그래프 수준 읽기 (readout)
%   'meanmax' g_t = tanh(Wg*[mean(H_t,2); max(H_t,2)]+bg)   (기본)
%   'mean'    g_t = mean(H_t,2)                              (가장 단순한 형태)
% 어느 쪽도 특정 노드를 골라 쓰지 않습니다. 모든 노드가 g_t에 기여합니다.
% 평균만 쓰면 노드별 차이가 씻겨 나갑니다(모방 손실 0.0821 대 0.0667).
gs.readout = 'meanmax';

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
