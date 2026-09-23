# UGV 착륙 2차원 MATLAB 모듈형 프로젝트

UGV 위 착륙 패드를 추종하는 드론의 **시야 이탈 → 상승 → 재포착 → 착륙** 시뮬레이션입니다.
세 가지 제어기를 같은 환경에서 비교합니다. **세 비교군 모두 제어 명령은 수평/수직 가속도 [m/s^2]** 입니다.

1. **PN guidance**: 비례 항법 유도 (기준)
2. **PPO 강화학습 (기준 모델)**: PN 유도를 교사로 모방 학습한 초기 정책 + PPO 미세조정.
   정책 입력은 11차원 관측 벡터입니다.
3. **온톨로지 그래프 상태 (제안 모델)**: 2번과 **보상, 행동, 환경, 종료 조건, PPO 알고리즘과
   하이퍼파라미터, 학습 일정, 시드가 모두 같고**, PPO에 넣는 **상태 표현만** 다릅니다.
   같은 관측 정보로 온톨로지 상황 그래프 `G_t = (V_t, E_t, X_t)`를 만들고, R-GAT으로 그래프
   전체를 부호화한 뒤(`H_t`), 모든 노드를 읽어 그래프 수준 표현 `g_t`를 만들어 Actor/Critic에
   넣습니다. 설계와 근거는 [docs/ONTOLOGY_GRAPH_STATE_KO.md](docs/ONTOLOGY_GRAPH_STATE_KO.md).

> 보상 가중치를 온톨로지 R-GAT으로 설계하던 **옛 제안 모델**은 지우지 않았고
> `cfg.useLegacyOntologyReward = true`일 때만 실행됩니다. 새 제안 모델은 그 경로를 쓰지 않으며,
> 기준 모델과 **같은 보상 함수**를 씁니다.

**현재 결과 (시드 3개, 같은 학습 예산):** 제안 모델은 아직 기준 모델보다 못합니다.

| 상태 표현 | 시드별 착륙률 | 평균 착륙률 | 평균 점수 |
| --- | --- | --- | --- |
| 기준 관측 벡터 | 100% / 100% / 100% | **100%** | **+125.4** |
| 온톨로지 그래프 | 0% / 67% / 100% | 56% | -20.8 |

가장 좋았던 실행에서는 제안 모델의 착륙 시각이 기준 모델과 대등했지만(28.8/41.6/40.7 s 대
30.2/39.3/42.1 s), 시드에 따른 분산이 큽니다. 원인 분석과 남은 개선 여지는
[docs/ONTOLOGY_GRAPH_STATE_KO.md](docs/ONTOLOGY_GRAPH_STATE_KO.md) 4절에 있습니다.

별도 Toolbox나 Simulink는 사용하지 않습니다. 신경망, PPO, R-GAT 모두 이 저장소 안의 행렬 연산으로 구현했습니다.

## 바로 실행

ZIP 전체를 압축 해제한 뒤 MATLAB의 Current Folder를 `ugv_landing_2d_workspace`로 지정합니다.

```matlab
run_all     % 통합 실행: 세 비교군의 전체 시나리오 + 학습 + 비교 그림
run_demo    % 기준 유도 법칙만 실시간 표시 + 결과 그래프
```

`run_all`은 세 비교군을 순서대로 처리합니다.
처음 실행은 학습 때문에 약 100초, 이후 재실행은 저장된 정책을 다시 써서 약 9초입니다.

```matlab
run_all;                                   % 필요한 학습만 수행하고 전체 비교
run_all(struct('rlRetrain',true));         % 두 정책 모두 다시 학습
run_all(struct('figureVisible',false));    % 창 없이 계산과 저장만
run_all(struct('controller','pd'));        % 기준을 기존 PD로 바꿔 실행
run_all(struct('stateRepresentation','gat'));    % 제거 실험으로 제안 모델 교체
run_all(struct('useLegacyOntologyReward',true)); % 옛 보상 설계 비교군까지 포함
```

상태 표현 제거 실험은 `cfg.graphState.stateRepresentation`으로 고릅니다.
네 설정 모두 **같은 PPO 구현**을 씁니다.

| 값 | 내용 |
| --- | --- |
| `baseline` | 기준 관측 벡터 (부호기 항등) |
| `node_pool` | 노드 특징 + 읽기, 메시지 전달 없음 |
| `gat` | 그래프 구조만 사용, 관계 유형을 하나로 합침 |
| `ontology_rgat` | 관계 유형을 유지한 R-GAT + 그래프 수준 읽기 (제안 모델) |

`run_demo`의 표시 배속은 4배속입니다. 함수의 기본 배속은 기존과 같은 1배속입니다.

```matlab
% 기본 설정: 1배속 실시간 표시 + 최종 결과 탭
[results, summaryTable, cfg] = run_ugv_landing_2d;

% 표시만 4배속. 적분 간격과 제어 결과는 바뀌지 않음.
[results, summaryTable, cfg] = run_ugv_landing_2d(struct('playbackSpeed',4));

% 실시간 표시 없이 계산한 뒤 최종 그래프 표시
[results, summaryTable, cfg] = run_ugv_landing_2d(struct('animate',false));
```

기존 호출 이름 `ugv_landing_2d_demo(options)`도 호환 진입점으로 남겨두었습니다.
**새 프로젝트는 파일 하나가 아니라 전체 폴더를 함께 사용해야 합니다.**

## 결과 그래프 구성

창 하나에 **시나리오별 탭 3개**, 탭마다 **그래프 2개**로 총 6개입니다.

| 위치 | 내용 | 가로축 | 세로축 | 배경 의미 |
|---|---|---|---|---|
| 왼쪽 | 패드와 드론의 상대거리 | 시간 [s] | 상대거리 [m] | 시간 구간 S1/S2/S3 |
| 오른쪽 | 드론과 착륙 패드의 전체 궤적 | 진행 위치 x [m] | 고도 z [m] | 구간 전환 시각의 UGV 위치 |

상대거리는 패드 중심과 드론 사이의 x-z 평면 거리입니다.
착륙하면 0에서 유지되고, 접촉에 실패하면 UGV가 멀어지며 다시 커집니다.

두 그래프 모두 같은 구간 색상을 사용합니다.

| 구간 | 기본 시간 범위 | 배경 | 밴드 안의 표시 |
|---|---|---|---|
| S1 | 0–8초 | 파랑 | S1 및 해당 시나리오의 목표 속도 |
| S2 | 8–15초 | 주황 | S2 및 해당 시나리오의 목표 속도 |
| S3 | 15–70초 | 초록 | S3 및 해당 시나리오의 목표 속도 |

표시 속도는 **UGV 목표 속도**입니다.
구간 전환 후 실제 속도는 가감속 한계를 따라 변하므로 목표와 즉시 같아지지 않습니다.

오른쪽 궤적 그래프의 배경 경계는 **구간 전환 시각에 UGV가 있던 진행 위치**입니다.
따라서 왼쪽의 시간 구간과 달리, **공간 배경 자체가 드론이 해당 위치를 통과한 시간 구간을 의미하지는 않습니다.**
배경 위치는 목표 속도를 적분해 근사하지 않고 저장된 실제 UGV 위치에서 계산합니다.

사건 표시는 두 그래프에서 같은 기호를 씁니다.
시야 이탈은 빨간 `x`, 재포착은 초록 사각형, 착륙은 검은 삼각형, 실패는 빨간 삼각형입니다.
사건 기호는 제어기와 무관하게 고정하고, 제어기는 선 색과 선 종류로 구분합니다.

`makeDetailPlots=true`로 두면 기존의 위치/속도 4패널 그림과 단독 x-z 궤적 그림을 시나리오마다 추가로 만듭니다.
기본값은 `false`이며, 이때 창은 탭 그림 하나뿐입니다.

## 기준 유도 법칙: 비례 항법 (PN guidance)

추종 구간에서는 드론에서 패드로 향하는 시선(LOS)을 기준으로 두 성분을 더해 가속도를 만듭니다.

```text
시선 직교 성분 : a_perp = N * |v_rel| * lambda_dot      (시선각 속도를 0으로)
시선 방향 성분 : a_par  = k * (Vc_ref - Vc)             (접근 속도를 거리에 맞게)
Vc_ref = min(pnApproachSpeed, pnApproachGain * R)
```

- 순수 비례 항법만 쓰면 접근 속도가 남아 충돌이 되므로, 접근 속도 기준을 거리에 비례시켜
  거리와 함께 0으로 보냅니다. 그래서 접지 속도가 착륙 허용치 안에 들어옵니다.
- 직교 성분의 이득으로 접근 속도 `Vc` 대신 **상대 속도 크기**를 씁니다.
  충돌 경로 위에서는 둘이 같으므로 진 비례 항법과 일치하고,
  재포착 직후처럼 시선각 속도가 큰 구간에서는 더 큰 권한을 줍니다.
- 시선각 속도를 0으로 유지하면 시선각이 보존되므로, 패드는 시야 안의 같은 상대 위치에 머뭅니다.
- 패드가 보이지 않는 재포착 구간은 종말 유도가 아니므로 다른 법칙을 씁니다.
  상승해 시야를 넓히면서, 패드가 시야 가장자리에 들어오면 시선을 수직으로 되돌립니다.
  이 구간에서 현재 패드 참값을 쓰지 않는 것은 다른 비교군과 같습니다.

| 옵션 | 기본값 | 역할 |
|---|---|---|
| `controller` | `'pn'` | `'pn'` 비례 항법, `'pd'` 기존 PD (원본 회귀 비교 전용) |
| `pnGain` | 3.0 | 비례 항법 이득 N |
| `pnApproachSpeed` | 0.7 | 최대 접근 속도 [m/s] |
| `pnApproachGain` | 0.60 | 접근 속도 기준 = min(pnApproachSpeed, gain*거리) [1/s] |
| `pnClosingGain` | 1.2 | 접근 속도 오차 -> 시선 방향 가속도 [1/s] |
| `pnRecoveryGain` | 0.7 | 재포착 구간 시선 정렬 이득 [1/s] |

기존 PD 제어기는 `controller='pd'` 경로로 남아 있으며, 원본 단일 파일과 1e-10 안에서 같은 수치를 유지합니다.

## 강화학습 비교군

구성은 다음과 같습니다.

- **환경**: 유도 법칙과 완전히 같은 함수(`sensing.observePad`, `environment.resolveContact`, `dynamics.stepDrone`)를 사용합니다.
  추종/탐색 상태 전환 규칙(`control.trackingMode`)도 공유합니다.
  세 비교군이 다른 것은 **가속도 명령을 만드는 방식뿐**입니다.
- **초기 정책**: 기준 유도 법칙(비례 항법)을 교사로 한 모방 학습입니다.
  시연을 모을 때 실행에만 작은 잡음을 섞고 라벨은 잡음 없는 PD 명령을 써서,
  학생 정책이 교사 궤적에서 조금 벗어나도 돌아올 수 있게 합니다.
- **미세조정**: PPO(클리핑 목적함수 + GAE).
  주기적으로 결정론적 평가를 해 **가장 좋은 정책을 보관**하고 마지막에 그 정책을 돌려줍니다.
- **관측**: 11차원. 패드가 보이지 않는 동안에는 패드 참값을 넣지 않고,
  마지막 관측값과 마지막 관측 패드 속도로만 추측합니다.
- **행동**: 제한 없는 2차원 명령을 환경이 `tanh`로 `axMax`, `azMax` 안에 넣습니다.

**보상은 두 항입니다.**

```text
r = captureWeight * (착륙 패드를 포착 중이면 +1, 아니면 -1)
  + distanceWeight * clip(1 - (상대거리/distanceScale)^distanceExponent, -1, +1)
```

지수를 1보다 작게(기본 0.5) 두면 거리 0 부근의 기울기가 커집니다.
지수가 1이면 패드 바로 위에 머무는 것과 실제로 접지하는 것의 보상 차이가 작아서
정책이 착륙 대신 호버링을 선택할 수 있습니다.

착륙 상태는 포착으로 간주하고 상대거리가 0이므로 두 항 모두 최대입니다.
접촉에 실패하면 포착이 끊기고 UGV가 멀어지므로 두 항 모두 최소가 됩니다.
따라서 패드를 놓치지 않으면서 빨리 착륙 지점에 도달하는 행동이 최적이 됩니다.

학습 설정은 `src/+landing2d/+rl/defaultRlConfig.m` 한 곳에 모여 있습니다.

```matlab
cfg = landing2d.config.defaultConfig(pwd);
cfg.rl.captureWeight  = 0.20;   % 포착 항 가중치
cfg.rl.distanceWeight = 0.50;   % 접근 항 가중치
cfg.rl.distanceScale  = 6.0;    % 접근 항의 부호가 바뀌는 거리 [m]
cfg.rl.distanceExponent = 0.5;  % 거리 지수. 작을수록 착륙 직전 기울기가 커짐
cfg.rl.ppoIterations  = 60;     % PPO 반복 수
cfg.rl.seed           = 20240501;
```

학습한 정책은 `results/rl_policy.mat`에 저장합니다.
환경/학습 설정 지문이 같으면 다시 쓰고, 하나라도 바뀌면 자동으로 다시 학습합니다.

결과는 아래 통합 표에 함께 정리했습니다.

## 온톨로지 기반 R-GAT 보상 가중치 설계

이 비교군은 **보상의 형태를 바꾸지 않고, 위 두 항의 가중치만** 온톨로지에서 추론합니다.

```text
1. 잡음을 섞은 기준 유도 법칙 시연에서 온톨로지 그래프와 착륙 성공 여부를 모읍니다.
2. R-GAT이 그래프에서 안전 착륙 잠재함수 Phi(G) in [-1,1]를 학습합니다.
3. 각 보상항에 대응하는 노드를 "무해한 값"으로 바꾸었을 때 Phi가 평균 얼마나 변하는지를
   그 항의 중요도로 봅니다(반사실 민감도).
4. 2~3을 designRepeats번 반복해 중요도를 평균합니다(초기화 난수 영향 완화).
5. 평균 중요도를 유계 단체(합 1, [0.15,0.85])에 사영한 비율에 가중치 총량을 곱해 확정합니다.
6. 확정한 가중치는 PPO 학습 내내 고정됩니다.
```

온톨로지는 원 저장소(OntoReward-RL)의 13노드 스키마를 이 축소형 시나리오에 맞게 다시 구성한 뒤,
**노드별 기여도를 측정해 8노드까지 줄인 최소 구성**입니다.

| # | 노드 | 종류 | 보상항 | # | 노드 | 종류 | 보상항 |
|---|---|---|---|---|---|---|---|
| 1 | PositionError | 위험 | distance | 5 | PadVisibility | 지원 | capture |
| 2 | DescentSpeed | 위험 | - | 6 | RelativeDistance | 위험 | distance |
| 3 | FovMargin | 위험 | capture | 7 | TouchdownSafety | 지원 | - |
| 4 | SearchDuration | 위험 | capture | 8 | SafeLanding | 목표 | - |

위험 노드 → 중간 노드(TouchdownSafety) → 목표 노드의 2단 구조와 네 종류 관계
(`degrades`, `supports`, `contributes`, `self`)가 최소화의 하한입니다.

11노드에서 제거한 것은 기여도가 거의 없던 세 개입니다.
Alignment(0.013)와 TrackingStability(0.0003)는 PositionError의 단조 변환이라 정보가 겹치고,
PadMotion(0.045)은 보상항 어디에도 속하지 않는 배경 노드였습니다.
세 개를 빼도 검증 MSE(0.089)와 추론 비율(0.40)이 그대로였고,
네 번째로 DescentSpeed까지 빼면 두 항의 비중이 뒤집힙니다.

기본 설정에서 나온 결과입니다.

| 항 | 대응 온톨로지 노드 | 반사실 중요도 | 비율 | 추론 가중치 | 손 설정 |
|---|---|---|---|---|---|
| capture | FovMargin + SearchDuration + PadVisibility | 0.0918 | 0.368 | **0.258** | 0.200 |
| distance | PositionError + RelativeDistance | 0.1581 | 0.632 | **0.442** | 0.500 |

한 번만 학습하면 초기화 난수에 따라 비율이 크게 흔들려서(표준편차 0.12),
`designRepeats = 5`번 학습한 중요도를 평균합니다. 학습별 비율과 그 편차도 함께 저장합니다.
온톨로지 R-GAT은 사람이 손으로 맞춘 배분과 같은 방향의 배분을 독립적으로 도출했습니다.

### 모방 학습 없이 학습합니다

제안 모델인 이 비교군은 **기준 유도 법칙의 모방 학습으로 정책을 초기화하지 않습니다.**
결과가 유도 법칙의 사전 지식이 아니라 보상 설계에서 나왔다고 말하려면 그래야 하기 때문입니다.
좋은 초기 정책이 없으므로 탐색과 학습량을 키운 설정(`cfg.rl.scratch`)을 함께 적용합니다.

| 설정 | 강화학습 비교군 | 온톨로지 비교군 |
|---|---|---|
| 초기 정책 | PN 유도 모방 학습 | 무작위 |
| 탐색 잡음 `initialLogStd` | -1.6 | -0.7 |
| 정책 학습률 | 2e-4 | 5e-4 |
| 엔트로피 가중치 | 0.002 | 0.005 |
| PPO 반복 | 60 | 700 |
| 학습 시간 | 약 38초 | 약 305초 |

학습 경과: 250회쯤에 패드 추종(포착률 99%)을 익히고, 600~650회 사이에 착륙을 찾습니다.

## 세 비교군 결과

같은 시드, 같은 환경, 같은 모방 학습 구조에서 얻은 값입니다.

| 제어기 | 재포착 지연 (S1/S2/S3) | 재포착 상승 고도 | 평균 포착률 | 착륙 |
|---|---|---|---|---|
| PN guidance | 4.9 / 9.2 / 14.3 s | 7.0 / 13.7 / 14.3 m | 0.79 | 42.9 / 55.0 / 57.6 s |
| PPO RL (모방 학습, 손 설정 0.20/0.50) | 5.6 / 12.1 / 15.8 s | 6.1 / 14.0 / 15.6 m | 0.73 | 23.8 / 41.0 / 43.9 s |
| Onto R-GAT (처음부터, 추론 1.40/0.50) | 없음 / 없음 / 9.4 s | 2.1 / 0 / 2.4 m | **0.98** | **미착륙** |

**의도한 동작은 확인됐지만 착륙은 완성되지 않았습니다.**

온톨로지가 추론한 포착 우위 가중치(capture : distance = 2.8 : 1, 손 설정은 0.4 : 1)로 학습한 정책은
교사가 쓰던 상승 동작 없이 패드를 시야에 유지합니다. 재포착 상승 고도가 7~15 m에서 0~2.4 m로 줄고,
시나리오 1·2에서는 시야를 아예 놓치지 않습니다. 평균 포착률도 0.73~0.79에서 0.98로 올라갑니다.

그러나 같은 정책이 최종 접지를 시도하지 않습니다. 원인은 측정으로 확인했습니다.

- 착륙 판정은 고도 4 cm에서 패드 **중심**이 카메라 발자국(±1.9 cm) 안에 있어야 성립합니다.
- 포착 : 거리 = 2.8 : 1이므로 마지막 1 m 하강 중 시야를 놓치면 스텝당 -2.8,
  착륙으로 얻는 이득은 스텝당 약 +0.5입니다. 확률적 정책에게 최종 하강은 기댓값이 음수입니다.
- 탐색 부족이 아닙니다. 1800회(13분) 학습, 접지 직전 고도(6 cm)에서 시작하는 에피소드 혼합,
  엔트로피 보너스 축소를 모두 시도했으나 착륙률은 0%였습니다.
- 가중치 합을 고정하는 방식은 더 나쁩니다. 거리 항이 0.184로 작아져 정책이 32~79 m까지 올라갑니다.

### 다음 단계 후보

- **카메라 모델 보정(권장)**: 지금은 패드 **중심**이 발자국 안에 있어야 "보인다"고 봅니다.
  고도 4 cm에서 발자국은 ±1.9 cm로, 반길이 50 cm인 패드 **안쪽**을 보고 있는데도
  모델은 시야 상실로 판정합니다. `|ex| <= 발자국 + 패드 반길이`로 바꾸면 이 역인센티브가 사라집니다.
  다만 세 비교군의 환경이 모두 바뀌고 PD 회귀 기준도 다시 잡아야 합니다.
- **비율 상한 조정**: `ontology.weightMax`를 낮춰 포착 항이 거리 항의 일정 배수를 넘지 않게 합니다.
- **짧은 모방 학습 도입**: 접지 동작만 교사에서 가져오고 나머지는 처음부터 학습합니다.

## 설정 수정

전체 기본 설정은 아래 한 파일에 모여 있습니다.

```text
src/+landing2d/+config/defaultConfig.m
```

기존의 최상위 옵션 이름을 유지했습니다. 필요한 값만 실행 시 덮어쓸 수도 있습니다.

```matlab
options = struct();
options.scenarioSpeeds = [
    1.0, 4.0, 1.5
    1.5, 5.5, 2.0
    2.0, 7.0, 2.5
];
options.segmentTimes = [8,15];
options.segmentColors = [
    0.27, 0.56, 0.88   % S1 파랑
    0.96, 0.61, 0.22   % S2 주황
    0.32, 0.72, 0.54   % S3 초록
];
options.segmentAlpha = 0.16;       % 0=완전 투명, 1=완전 불투명
options.showSegmentLabels = true;
options.playbackSpeed = 4;
[results, summaryTable, cfg] = run_ugv_landing_2d(options);
```

| 옵션 | 기본값 | 역할 |
|---|---|---|
| `segmentColors` | 3×3 RGB 행렬 | S1/S2/S3 색상 |
| `segmentAlpha` | 0.16 | 배경 불투명도. 클수록 진하게 표시 |
| `showSegmentLabels` | true | 배경에 구간 번호와 목표 속도 표시 |
| `showEventLines` | true | 두 그래프의 사건 기호 표시 |
| `makeFinalPlots` | true | 모든 최종 그래프 생성의 전체 스위치 |
| `makeDetailPlots` | false | 위치/속도 4패널 등 상세 그림 추가 생성 |
| `makeTrajectoryPlots` | true | 상세 그림에서 단독 x-z 궤적 그림 생성 여부 |
| `trajectoryFlightOnly` | true | 착륙/실패 시점까지만 공간 궤적 표시 |
| `figureVisible` | true | 최종 창 표시. false일 때 animate도 false로 지정 |
| `figureResolution` | 200 | PNG 해상도(dpi) |
| `saveResults` | true | 데이터·그림 저장 |
| `saveFig` | true | 편집용 MATLAB FIG도 함께 저장 |
| `outputDir` | 프로젝트/results | 결과 저장 폴더 |
| `rl` | `defaultRlConfig()` | 강화학습 학습 설정 묶음 |
| `ontology` | `defaultOntologyConfig()` | 온톨로지/R-GAT 가중치 설계 설정 묶음 |

물리 모델이나 제어기를 바꾸지 않고 배경의 농도만 조절할 때는 `segmentAlpha`만 바꾸면 됩니다.
`makeFinalPlots=false`이면 최종 그림을 생성하지 않습니다.

## 저장 결과만 다시 그리기

새로 시뮬레이션하지 않고 기존 MAT에서 구간 배경·색상·라벨을 변경할 수 있습니다.

```matlab
% 새 프로젝트에서 최근 저장한 결과
replot_results;

% 배경을 조금 더 진하게 표시
replot_results([],struct('segmentAlpha',0.22));

% 이전 단일 파일 버전에서 저장한 결과도 지원
replot_results('기존결과폴더/simulation_results.mat', ...
    struct('segmentAlpha',0.18, ...
           'saveResults',true, ...
           'outputDir',fullfile(pwd,'results_replot')));
```

`replot_results`는 MAT의 물리·제어·시나리오 설정을 유지합니다.
색상/표시/저장 관련 옵션만 변경할 수 있으며, 속도나 구간 전환 시각을 바꾸려면 다시 시뮬레이션해야 합니다.
이전 MAT에는 새 시각화 설정이 없으므로 해당 항목에 새 기본값을 적용합니다.
원본 MAT와 CSV는 다시 쓰지 않고 그림만 생성합니다. 같은 출력 폴더를 지정하면 같은 이름의 PNG/FIG는 덮어씁니다.

## 폴더 구조

```text
ugv_landing_2d_workspace/
├─ run_demo.m                     # 편집기 Run용 예시 스크립트
├─ run_ugv_landing_2d.m           # PD 주 실행 함수
├─ run_all.m                     # 통합 실행: 세 비교군 전체 시나리오 + 학습
├─ ugv_landing_2d_demo.m          # 기존 호출 호환
├─ setup_project.m                # MATLAB 경로 설정
├─ replot_results.m               # 저장 결과 재시각화
├─ run_tests.m                    # 테스트 실행
├─ ugv_landing_2d.code-workspace  # 로컬 VS Code 작업공간
├─ .vscode/tasks.json             # MATLAB 일괄 실행/비교/테스트 작업
├─ src/+landing2d/
│  ├─ +config/                    # 기본 설정, 옵션 적용, 검증
│  ├─ +scenario/                  # UGV 궤적, 구간 번호/경계
│  ├─ +simulation/                # 초기화와 전체 시간 루프
│  ├─ +sensing/                   # 카메라 FOV/관측 정보경계
│  ├─ +control/                   # 비례 항법 유도, 상태기계, 기존 PD 경로
│  ├─ +rl/                        # 교사 시연, 모방 학습, PPO, 정책 rollout
│  ├─ +dynamics/                  # 드론 위치·속도 적분
│  ├─ +environment/               # 착륙/접촉 판정
│  ├─ +viz/                       # 실시간 화면, 탭 요약, 구간 배경
│  ├─ +metrics/                   # 요약 지표, 비교 지표, 상대거리
│  ├─ +io/                        # MAT/CSV/PNG/FIG 저장
│  └─ +util/                      # 포화, Adam, 기울기 클리핑, 체크섬
├─ tests/                         # 회귀/관측/구간/강화학습/온톨로지/그래픽 테스트
│  └─ reference/                  # 원본 단일 파일의 고정 비교용 사본
├─ docs/                          # 모듈 안내 및 검증 범위
├─ AGENTS.md                      # 후속 코드 수정 가이드
└─ results/                       # 실행 후 결과 생성
```

`+` 접두어는 함수 이름 충돌을 피하는 MATLAB 패키지 구조입니다.
실제 호출은 `landing2d.control.pdController(...)`처럼 합니다. `setup_project`는 루트와 `src`만 경로에 추가합니다.
개별 `+폴더`에 `addpath`하거나 `genpath`를 사용할 필요가 없습니다.

## 실행 후 생성되는 파일

`run_ugv_landing_2d`:

```text
results/
├─ simulation_results.mat
├─ summary.csv
├─ scenario_1_log.csv
├─ scenario_1_summary.png          # 탭 1 (상대거리 + 궤적)
├─ scenario_2_summary.png
├─ scenario_3_summary.png
└─ summary_tabs.fig                # 탭 3개를 가진 창 전체
```

`run_all`:

```text
results/
├─ rl_policy.mat                   # 손 설정 가중치로 학습한 정책과 설정 지문
├─ rl_policy_ontology.mat          # 추론한 가중치로 학습한 정책
├─ reward_design.mat               # R-GAT 파라미터, 학습 이력, 설계 지문
├─ reward_design_weights.csv       # 항별 중요도/부호/비율/가중치
├─ ontology_node_importance.csv    # 노드별 반사실 기여도 (최소화 근거)
├─ comparison.mat
├─ comparison_summary.csv
├─ scenario_1_pn_guidance_log.csv
├─ scenario_1_ppo_rl_log.csv
├─ scenario_1_onto_r_gat_log.csv
├─ scenario_1_comparison.png       # 탭 1 (세 비교군을 겹쳐 표시)
├─ ...                             # 시나리오 2, 3도 같은 형식
└─ comparison_tabs.fig
```

CSV에는 위치/속도/관측/모드에 더해 `SpeedSegment`, 수평·수직 가속도 명령, 상대 고도 기준값도 포함합니다.
기본 결과 폴더는 **프로젝트 루트의 results**입니다.
같은 폴더에서 재실행하면 같은 이름의 결과를 덮어씁니다. 실행을 보존하려면 `outputDir`를 바꾸세요.

## VS Code에서 열기

`ugv_landing_2d.code-workspace`를 엽니다. 이는 로컬 코드 작업공간이며 원격 GitHub Codespaces를 생성하지 않습니다.
편집은 이 작업공간에서, 실행은 MATLAB의 주 함수 또는 포함된 작업으로 수행할 수 있습니다.
작업 실행을 이용하려면 MATLAB이 설치되어 있고 `matlab` 명령을 운영체제 PATH에서 찾을 수 있어야 합니다.
일괄 실행 작업은 GUI를 숨기고 결과 파일을 저장한 뒤 종료합니다.

## 테스트 및 확인 범위

```matlab
run_tests          % 16개: 수치 회귀 + 유도 + 정보경계 + 구간 + 검증 + 강화학습 + 온톨로지 + 그래픽
run_tests(false)   % 14개: 그래픽 테스트 제외
```

테스트에는 원본 단일 파일과 신규 모듈의 세 시나리오 전체 수치 로그를 비교하는 회귀 검사를 포함합니다.
기본 유도 법칙을 비례 항법으로 바꾼 뒤에도 **`controller='pd'` 경로는 1e-10 허용오차 안에서 원본과 동일**합니다.
`tests/reference`는 이 비교에만 사용하며 정상 실행 경로에는 추가하지 않습니다.

이번 변경은 **MATLAB R2025b에서 실제로 실행해 16개 테스트 통과와 그림 생성까지 확인**했습니다.
자세한 내용과 알려진 제약은 `docs/VALIDATION_KO.md`를 참고하세요.
코드는 MATLAB R2020a 이상 문법을 대상으로 작성했으며, 추가 Toolbox나 Simulink는 사용하지 않습니다.

## 반투명 배경 구현 참고

MathWorks 공식 `patch` / `FaceAlpha` 설명:
https://www.mathworks.com/help/matlab/ref/patch.html

MathWorks 공식 투명도 설정 예제:
https://www.mathworks.com/help/matlab/creating_plots/changing-transparency-of-images-patches-or-surfaces.html
