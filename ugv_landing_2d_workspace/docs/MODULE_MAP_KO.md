# 모듈별 수정 위치

## 실행 흐름

```text
run_demo / run_ugv_landing_2d
    ├─ setup_project
    ├─ config.defaultConfig -> applyOptions -> validateConfig
    ├─ simulation.run
    │    ├─ simulation.initialize -> simulation.initializeCase
    │    │    ├─ scenario.makeUgvTrajectory
    │    │    └─ scenario.segmentIndex
    │    └─ 각 시간 스텝 / 각 시나리오
    │         ├─ environment.resolveContact
    │         ├─ sensing.observePad
    │         ├─ control.command -> pnGuidance / pdController
    │         ├─ 현재 상태/관측/명령 로그 기록
    │         ├─ dynamics.stepDrone
    │         └─ viz.updateAnimation (선택)
    ├─ metrics.makeSummary
    ├─ io.saveData
    └─ viz.plotFinalResults
         ├─ viz.plotRunSummary -> viz.createSummaryTabs -> io.saveTabbedFigure
         └─ makeDetailPlots=true일 때만
              ├─ viz.createPositionVelocityFigure
              ├─ viz.createTrajectoryFigure
              └─ io.saveFigure

run_all
    ├─ simulation.run                      (비례 항법 유도 결과)
    ├─ graphstate.applyStateRepresentation (상태 표현만 바꾸는 설정 헬퍼)
    ├─ rl.loadOrTrainAgent                 (기준 모델: 관측 벡터 상태)
    │    └─ rl.trainAgent
    │         ├─ rl.teacherDataset         (기준 유도 법칙 교사 시연)
    │         ├─ rl.behaviorClone          (모방 학습)
    │         └─ rl.ppoTrain               (PPO 미세조정 + 최고 정책 선택)
    ├─ graphstate.assertSameProblem        (보상/행동/환경/PPO 동일성 검사)
    ├─ rl.loadOrTrainAgent                 (제안 모델: 온톨로지 그래프 상태)
    │    └─ rl.trainAgent -> rl.ppoTrain   (기준 모델과 같은 구현)
    │         └─ 정책/가치망 앞단 부호기
    │              ├─ graphstate.situationGraph   G_t = (V_t, E_t, X_t)
    │              │    ├─ graphstate.observationSemantics  (관측만 사용)
    │              │    ├─ ontology.nodeValues
    │              │    └─ graphstate.nodeFeatures          (X_t)
    │              ├─ graphstate.encoderForward   -> rgat.relationForward  (H_t)
    │              │    └─ 그래프 수준 읽기 (mean+max)      -> g_t
    │              └─ graphstate.encoderBackward  -> rgat.relationBackward
    ├─ rl.evaluate -> rl.rolloutEpisode    (강화학습 결과)
    ├─ metrics.makeComparisonSummary
    ├─ io.saveComparison
    └─ viz.plotRunSummary

run_all (cfg.useLegacyOntologyReward = true 일 때만 추가되는 옛 제안 모델)
    ├─ ontology.loadOrDesignWeights
    │    └─ ontology.designRewardWeights
    │         ├─ ontology.buildDataset     (잡음 섞은 유도 법칙 시연 -> 그래프 + 결과)
    │         │    ├─ ontology.semanticState   (환경 참값 사용: 설계 전용)
    │         │    ├─ ontology.nodeValues
    │         │    └─ ontology.buildGraph
    │         ├─ ontology.trainPotential   (R-GAT으로 안전 착륙 잠재함수 학습)
    │         │    ├─ rgat.potentialForward -> rgat.relationForward
    │         │    └─ rgat.potentialBackward -> rgat.relationBackward
    │         └─ ontology.distillWeights   (반사실 민감도 -> 유계 단체 -> 고정 가중치)
    ├─ ontology.applyDesign                (보상 가중치 변경 + 표식)
    ├─ rl.loadOrTrainAgent
    └─ io.saveRewardDesign

replot_results
    ├─ 저장된 results 및 cfg 읽기
    ├─ 시각화 옵션만 변경
    └─ viz.plotFinalResults
```

## 수정 대상에 따른 파일

| 변경하려는 기능 | 수정할 파일 (`src/+landing2d/` 기준) |
|---|---|
| 시나리오 속도, 구간 전환 시간, 카메라/제어 상수 | `+config/defaultConfig.m` |
| PPO 상태 표현 방식 / 제거 실험 선택 | `+graphstate/defaultGraphStateConfig.m`, `+graphstate/applyStateRepresentation.m` |
| 온톨로지 그래프 노드 값 (관측만 사용) | `+graphstate/observationSemantics.m` |
| 온톨로지 그래프 노드 특징 행렬 X_t | `+graphstate/nodeFeatures.m` |
| 그래프 부호기와 그래프 수준 읽기 | `+graphstate/encoderInit.m`, `encoderForward.m`, `encoderBackward.m` |
| 상태 표현 경로 디버깅 출력 | `+graphstate/inspectPipeline.m` |
| 새 옵션 검증 규칙 | `+config/validateConfig.m` |
| 구간별 UGV 목표 속도/실제 가감속 | `+scenario/makeUgvTrajectory.m` |
| 속도 구간의 시간·공간 경계 메타데이터 | `+scenario/segmentMetadata.m` |
| 카메라 시야와 가시성 판정 | `+sensing/observePad.m` |
| 비례 항법 유도 (기본 제어기) | `+control/pnGuidance.m` |
| 제어기 선택 | `+control/command.m`, `cfg.controller` |
| 추종/탐색 상태 전환, 재포착 유지 시간 | `+control/trackingMode.m` |
| 기존 PD 제어 (회귀 비교 전용) | `+control/pdController.m` |
| 드론 가속도 입력 운동 모델 | `+dynamics/stepDrone.m` |
| 안전 착륙/높이 위반 판정 | `+environment/resolveContact.m` |
| 실시간 화면 초기화/갱신 | `+viz/createAnimation.m`, `+viz/updateAnimation.m` |
| 탭 구성, 상대거리 그래프, 궤적 그래프 | `+viz/createSummaryTabs.m` |
| 비교 선 색/선형/이름 | `+viz/normalizeRuns.m` |
| 사건 기호와 색 | `+viz/eventStyles.m` |
| 반투명 배경 패치/라벨 | `+viz/addSegmentBackground.m` |
| 축 변경 시 배경 갱신 | `+viz/refreshSegmentBackground.m` |
| 상세 시간 그래프 네 패널 (선택 출력) | `+viz/createPositionVelocityFigure.m` |
| 상세 x-z 궤적 그래프 (선택 출력) | `+viz/createTrajectoryFigure.m` |
| 상대거리 정의 | `+metrics/relativeDistance.m` |
| 결과 지표 / 비교 지표 | `+metrics/makeSummary.m`, `+metrics/makeComparisonSummary.m` |
| CSV 저장 필드 | `+io/resultToTable.m` |
| MAT/CSV 저장 | `+io/saveData.m`, `+io/saveComparison.m` |
| PNG/FIG 저장 | `+io/saveFigure.m`, `+io/saveTabbedFigure.m` |
| 학습률·보상 가중치·PPO 설정 | `+rl/defaultRlConfig.m` |
| 정책 입력(관측) 정의 | `+rl/observation.m` |
| 보상 두 항의 계산 | `+rl/rolloutEpisode.m` |
| 교사 시연 수집 방식 | `+rl/teacherDataset.m` |
| 모방 학습 / PPO 갱신 | `+rl/behaviorClone.m`, `+rl/ppoTrain.m` |
| 교사 없이 학습할 때의 설정 | `+rl/applyScratchSettings.m`, `cfg.rl.scratch` |
| 신경망 기본 연산 | `+rl/mlpForward.m`, `+rl/mlpBackward.m` |
| Adam, 기울기 클리핑, 포화 | `+util/adamUpdate.m`, `+util/clipGradient.m`, `+util/saturate.m` |
| 온톨로지 노드·간선·보상항 대응 | `+ontology/nodeSchema.m` |
| 의미 채널 계산 | `+ontology/semanticState.m` |
| 그래프 노드 특징 | `+ontology/buildGraph.m` |
| R-GAT 학습 데이터/정답 | `+ontology/buildDataset.m` |
| R-GAT 순전파/역전파 | `+rgat/relationForward.m`, `+rgat/relationBackward.m` |
| 잠재함수 구조와 손실 | `+rgat/potentialForward.m`, `+rgat/potentialLoss.m` |
| 보상항 단위 반사실 민감도 | `+ontology/termImportance.m` |
| 노드 단위 반사실 기여도 (최소화 근거) | `+ontology/nodeImportance.m` |
| 중요도 평균과 가중치 증류 | `+ontology/distillWeights.m` |
| 간선 주의 가중치 (해석용) | `+rgat/attention.m` |
| 온톨로지/R-GAT 설정 | `+ontology/defaultOntologyConfig.m` |

## 주요 인터페이스

### 드론 상태 `s`

`x`: 진행 위치 [m], `h`: 패드 면 기준 상대 고도 [m], `vx`: 수평 속도 [m/s], `vz`: 수직 속도 [m/s].

`heightReference`: 수직 PD의 상대 고도 기준 [m], `lastPadSpeed`: 마지막 관측 패드 속도 [m/s], `seenTime`: 연속 재포착 조건 충족 시간 [s].

`mode`: 1=추종/정렬/하강, 2=상승 탐색, 3=착륙 완료, 4=접촉 실패.

`mode` 전환은 `control.trackingMode`가 담당하며, 비례 항법 유도와 강화학습 rollout이 함께 씁니다.
`pdController`는 회귀 비교를 위해 같은 규칙의 사본을 자기 안에 유지합니다.
착륙 판정이 `mode==1`을 요구하므로 세 제어기가 모두 같은 조건에서 비교됩니다.

### 제어기 관측 `obs`

`visible`, `halfWidth`, `xError`, `vError`, `padSpeed`로 구성합니다.
가시성 판정에는 환경의 실제 좌표를 쓰지만, 패드가 보이지 않을 때 `xError`, `vError`, `padSpeed`를 NaN으로 설정합니다.
제어기는 `obs.visible=false`일 때 이 참값을 사용하지 않고 `lastPadSpeed`만 이용합니다.

### 정책 관측 `o` (11차원)

`rl.observation`이 만들며 순서는 다음과 같습니다.

1. 패드 가시 여부
2. 상승 탐색 상태(`mode==2`)
3. 착륙 완료 상태(`mode==3`)
4. 수평 오차 / 5 m
5. 상대 수평 속도 오차 / 3 m/s
6. 수평 오차 / FOV 반폭 (시야 여유)
7. 마지막으로 본 수평 오차 / 5 m (비가시 구간은 추측 항법)
8. 마지막 관측 후 경과 시간 / 2 s
9. 패드 면 기준 고도 / 상승 한계 (1.2에서 포화)
10. (드론 수평 속도 - 마지막 관측 패드 속도) / 수평 속도 한계
11. 수직 속도 / 수직 속도 한계

4·5·6번 항목은 패드가 보이지 않으면 0이며, 7·8번만 기억으로 유지합니다.
비가시 구간의 참값은 어떤 항목에도 들어가지 않습니다.

### 제어 명령

세 비교군의 출력은 모두 수평/수직 가속도 [m/s^2]이며 `axMax`, `azMax`로 포화됩니다.

비례 항법 유도(`+control/pnGuidance.m`)는 추종 구간에서 드론->패드 시선(LOS)을 기준으로
직교 성분 `N*|v_rel|*lambda_dot`과 시선 방향 성분 `k*(Vc_ref - Vc)`를 더합니다.
`Vc_ref = min(pnApproachSpeed, pnApproachGain*R)`이므로 거리와 함께 접근 속도가 0으로 갑니다.
재포착 구간은 종말 유도가 아니므로 상승 + 시선 정렬 항을 따로 씁니다.

### 행동과 보상

정책은 제한 없는 2차원 명령을 내고 환경이 `tanh`로 `axMax`, `azMax` 안에 넣습니다.
포화가 정책 분포 밖에 있으므로 log 확률 보정이 필요 없습니다.

보상은 두 항의 합입니다.

```text
r = captureWeight * (포착 중이면 +1, 아니면 -1)
  + distanceWeight * clip(1 - (상대거리/distanceScale)^distanceExponent, -1, +1)
```

착륙 상태는 포착으로 간주하고 거리가 0이므로 두 항 모두 최대가 됩니다.
접촉 실패 상태는 UGV가 멀어지면서 두 항 모두 최소가 됩니다.

### 결과 `r`

PD와 강화학습이 같은 필드를 채웁니다.
`time`, `xUgv`, `zPad`, `vxUgv`, `vxUgvCommand`, `xDrone`, `zDrone`, `vxDrone`, `vzDrone`, `xError`, `fovHalfWidth`, `mode`, `visible`, `descending`, `axCommand`, `azCommand`, `heightReference`, `segmentId`.

사건 시각은 `lossTimes`, `reacquireTimes`, `landingTime`, `failureTime`으로 기록합니다.
`zDrone`은 지면 기준이지만 `heightReference`는 패드 면 기준이라는 차이에 유의하세요.
강화학습에는 PD의 기준 궤적이 없으므로 `heightReference`에 실제 상대 고도를 기록합니다.

### 온톨로지 그래프

`+ontology/nodeSchema.m`에 노드 8개, 간선 19개, 보상항 대응이 모여 있습니다.
노드별 반사실 기여도를 측정해 기여가 거의 없는 노드를 제거한 최소 구성입니다.
노드 특징은 `[값; 1-값; 위험 표시; 편향] + 노드 정체성 one-hot`이며 `inDim = 4 + 노드 수`입니다.
관계는 `degrades`, `supports`, `contributes`, `self` 네 가지입니다.

R-GAT은 그래프에서 안전 착륙 잠재함수 `Phi(G) in [-1,1]`을 학습하고,
각 보상항에 대응하는 노드를 무해한 값으로 바꾸었을 때의 `|dPhi|` 평균이 그 항의 중요도가 됩니다.
중요도를 유계 단체에 사영해 두 항의 **비율**을 얻고, 절대 크기는 기준 항(`anchorTerm`, 기본 distance)의
가중치를 `anchorWeight`로 고정한 뒤 나머지를 비율에 맞춰 키웁니다.
두 가중치의 합을 고정하면 비율이 포착 쪽으로 기울 때 거리 항이 함께 작아져
착륙 압력이 사라지므로 이 방식을 쓰지 않습니다.
초기화 난수의 영향을 줄이려고 `designRepeats`번 학습한 중요도를 평균합니다.

자세한 설계 근거와 결과는 `docs/ONTOLOGY_RGAT_KO.md`를 참고하세요.

## 그래프 의미

시간 그래프(왼쪽)의 배경: `[0,t1)`, `[t1,t2)`, `[t2,tEnd]`.

공간 그래프(오른쪽)의 배경: `[xUGV(0),xUGV(t1)]`, `[xUGV(t1),xUGV(t2)]`, `[xUGV(t2),xUGV(tEnd)]`.

공간 그래프에서 드론의 이동 시각을 배경만으로 판단하지 않습니다. 드론이 특정 x 위치를 지난 시각은 드론/UGV 간 지연 때문에 다를 수 있습니다.
`segmentMetadata`에서 두 기준을 따로 반환해 이 혼동을 방지합니다.
