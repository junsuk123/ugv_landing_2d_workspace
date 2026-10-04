function onto = defaultOntologyConfig()
% DEFAULTONTOLOGYCONFIG  온톨로지 기반 R-GAT 보상 가중치 설계 설정.
% R-GAT은 학습 시점에만 쓰이며, 결과는 고정된 두 개의 보상 가중치입니다.
onto.seed = 20240611;

%% 의미 채널 정규화 기준 [단위는 주석 참조]
onto.positionScale = 2.5;     % 수평 오차 정규화 [m]
onto.alignScale = 1.0;        % 정렬도 exp 감쇠 [m]
onto.speedScale = 1.0;        % 추종 안정도 exp 감쇠 [m/s]
onto.searchScale = 2.0;       % 재탐색 지속 시간 정규화 [s]
onto.padSpeedScale = 7.0;     % 패드 이동 위험 정규화 [m/s]

%% 데이터셋: 잡음을 섞은 PD 전문가 시연
onto.dataEpisodes = 24;       % 에피소드 수
onto.sampleStride = 5;        % 제어 주기 몇 번마다 그래프 한 장
onto.noiseRange = [0.05,1.20]; % 실행 잡음 세기 범위 (로그 균등)
onto.heightRange = [0.7,1.3];  % 초기 고도 배율. PD가 제한 시간 안에 착륙 가능한 범위
onto.labelGamma = 0.98;       % 표본당 미래 결과 할인율

%% R-GAT
onto.hiddenDim = 16;
onto.relationDim = 6;
onto.initScale = 0.12;
onto.epochs = 40;
onto.batchSize = 32;
onto.learnRate = 3e-3;
onto.maxGradNorm = 1.0;
onto.validationSplit = 0.2;
onto.outputRegularization = 1e-4;

%% 반사실 민감도 -> 가중치 증류
onto.designRepeats = 5;       % R-GAT을 몇 번 학습해 중요도를 평균할지

%% weightObjective='weightGraph'에서만 사용
onto.sweepPoints = 9;         % 자료를 모을 가중치 배분 개수
onto.sweepShareRange = [0.10,0.90];  % 배분 탐색 범위 (포착 항 비율)
onto.sweepFromScratch = true; % 탐색 학습도 제안 모델과 같은 조건(모방 학습 없음)으로
onto.sweepIterations = 800;   % 배분마다 돌릴 PPO 반복 수
% 탐색 학습이 모방 학습으로 초기화되면 착륙 라벨이 제안 모델의 조건과 달라집니다.
% 실제로 모방 학습 기준 라벨은 배분 0.77까지 착륙 100%%를 보고했지만, 같은 배분을
% 처음부터 학습하면 착륙하지 못했습니다. 그래서 탐색도 처음부터 학습합니다.
onto.sweepGrid = 41;          % 마지막 배분 탐색 해상도
onto.maxAttributionSamples = 2000;
onto.importanceFloor = 1e-3;  % 모든 항이 0일 때의 하한
onto.weightMin = 0.15;        % 정규화 가중치 하한 (합 1 기준)
onto.weightMax = 0.85;        % 정규화 가중치 상한
% 가중치 크기 기준: 온톨로지는 두 항의 '비율'만 추론하고, 절대 크기는 기준 항에 맞춥니다.
% 거리 항은 과제 자체(착륙)를 정의하므로 손 설정과 같은 값으로 고정하고,
% 포착 항을 추론한 비율만큼 키웁니다. 합을 고정하면 비율이 포착 쪽으로 기울 때
% 거리 항이 함께 작아져 착륙 압력이 사라지므로 이 방식을 쓰지 않습니다.
% 가중치를 정하는 기준.
%   'alignment'      : 두 항의 가중합이 학습된 착륙 잠재함수 Phi를 따라가도록 적합.
%                      보상이 큰 상태 = 착륙으로 이어지는 상태가 되므로,
%                      보상 최대화가 곧 착륙을 향합니다.
%   'counterfactual' : 보상항 노드를 무해한 값으로 바꿨을 때 Phi가 변하는 크기.
%                      "무엇이 Phi를 좌우하는가"를 재는 값이며 해석용으로는 유용하지만,
%                      그 비율을 그대로 가중치로 쓰면 착륙이 최적해가 아닌 보상이 됩니다.
%   'weightGraph'    : 보상 가중치를 온톨로지 노드로 넣고, 가중치를 바꿔가며 실제로
%                      정책을 학습시킨 자료로 R-GAT을 학습합니다. 그 다음 가중치 노드를
%                      훑어 착륙 잠재함수가 가장 큰 배분을 고릅니다.
%                      "이 배분이 착륙에 도움이 되는가"를 직접 계산하는 방식이며,
%                      대신 배분마다 짧은 학습이 필요해 설계 시간이 깁니다.
% 기본값은 counterfactual입니다. alignment는 보상 거리 항이 'proximity'일 때만
% 쓸 수 있습니다(변화율은 한 상태의 그래프에서 읽을 수 없음).
onto.weightObjective = 'counterfactual';
onto.anchorTerm = 'distance'; % 크기를 고정할 기준 항
onto.anchorWeight = 0.71;     % 기준 항의 가중치 (손 설정과 동일)

%% 저장
onto.designFile = 'reward_design.mat';
onto.redesign = false;        % true면 저장된 설계가 있어도 다시 학습
onto.verbose = true;
end
