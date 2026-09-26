# UGV 착륙 2차원 MATLAB 모듈형 프로젝트

> **재현성 주의:** 접근 보상의 거리 변화율이 `d_(t-1)-d_t`가 아니라 `0-d_t`로 계산되던 오류를 수정했습니다. 아래의 과거 수치 결과와 기존 정책 파일은 수정 전 구현에서 생성되었으므로 새 결론의 근거로 재사용하지 않습니다. 정책 설정 지문에 알고리즘 버전을 포함해 자동 재학습되며, 새 결과는 별도 출력 폴더에서 다시 산출해야 합니다.

UGV 위 착륙 패드를 추종하는 드론의 **시야 이탈 → 상승 → 재포착 → 착륙** 시뮬레이션입니다.
세 가지 제어기를 같은 환경에서 비교합니다.
**모든 비교군의 제어 명령은 수평/수직 가속도 [m/s^2]** 입니다.

1. **PN guidance** — 비례 항법 유도 (기준선)
2. **PPO 강화학습 (기준 모델)** — 정책 입력은 `landing2d.rl.observation`의 11차원 관측 벡터
3. **온톨로지 그래프 상태 (제안 모델)** — 2번과 같은 관측 정보로 온톨로지 상황 그래프
   `G_t = (V_t, E_t, X_t)`를 만들고, R-GAT으로 그래프 전체를 부호화한 뒤(`H_t`),
   모든 노드를 읽어 그래프 수준 표현 `g_t`를 Actor/Critic에 넣습니다.

2번과 3번은 **보상 함수와 계수, 행동 정의와 한계, 환경 동역학, 종료 조건, PPO 구현이
완전히 같습니다.** `landing2d.graphstate.assertSameProblem`이 학습 전에 실행 중으로
검사하고 하나라도 다르면 중단합니다. 달라지는 것은 PPO가 받는 상태 표현입니다.

학습 조건(교사 모방 사용 여부, 반복 수)은 실험 설계에 따라 고르며, 기본값에서는
두 PPO 비교군 모두 교사 없이 동일한 조건으로 학습합니다. 자세한 내용은 아래 "학습 조건" 절에 있습니다.

### 핵심 결과

**교사 없이 학습한 경우** (두 비교군 모두, 학습 조건 차이 0개 → 실험 변수는 상태 표현 하나)

| 상태 표현 | 최초 착륙 | 최종 착륙률 | 최종 점수 | 포착률 |
| --- | --- | --- | --- | --- |
| 기준 관측 벡터 11차원 | **없음** | **0%** | -38.2 | 85% |
| 온톨로지 그래프 | **550반복** | **100%** | **+151.4** | 95% |

기준 관측 벡터로는 교사 없이 2500반복 동안 한 번도 착륙하지 못하고, 포착률만 높은
국소 최적해(떠서 패드를 시야에 유지)에 갇힙니다. 온톨로지 그래프 상태로는 550반복에서
착륙을 찾고 최종적으로 착륙률 100%, 점수 +151.4에 도달합니다.

이 점수는 **교사를 쓴 기준 모델(+125.4)보다 높습니다.** 착륙 시각도
28.7 / 31.1 / 38.3 s로 교사를 쓴 기준 모델(30.2 / 39.3 / 42.1 s)보다 빠르고,
포착률도 95%로 가장 높습니다. PN 유도를 한 번도 보지 않고 도달한 값입니다.

**두 비교군 모두 교사를 쓴 경우** (시드 3개)

| 상태 표현 | 평균 착륙률 | 평균 점수 | 평균 포착률 |
| --- | --- | --- | --- |
| 기준 관측 벡터 | 100% | +125.4 | 86% |
| 온톨로지 그래프 | 100% | +97.0 | 84% |

교사가 있으면 두 표현 모두 안정적으로 착륙하며, 이 조건에서는 기준 관측 벡터가
평균 점수에서 앞섭니다. 즉 **온톨로지 그래프 상태의 이점은 사전 지식 없이 학습할 때
드러납니다.** 교사가 있으면 그 사전 지식이 표현의 차이를 덮습니다.

> 보상 가중치를 온톨로지 R-GAT으로 설계하던 **옛 제안 모델**은 지우지 않았고
> `cfg.useLegacyOntologyReward = true`일 때만 실행됩니다.
> 새 제안 모델은 그 경로를 전혀 쓰지 않고 기준 모델과 **같은 보상 함수**를 씁니다.

구현 중 찾아 고친 문제 네 가지와 남은 차이는
[docs/ONTOLOGY_GRAPH_STATE_KO.md](docs/ONTOLOGY_GRAPH_STATE_KO.md) 4절에
측정값과 함께 정리했습니다.

별도 Toolbox나 Simulink는 사용하지 않습니다. 신경망, PPO, R-GAT 모두 이 저장소 안의 행렬 연산으로 구현했습니다.

## 바로 실행

ZIP 전체를 압축 해제한 뒤 MATLAB의 Current Folder를 `ugv_landing_2d_workspace`로 지정합니다.

```matlab
run_all     % 통합 실행: 세 비교군의 전체 시나리오 + 학습 + 비교 그림
run_demo    % 기준 유도 법칙만 실시간 표시 + 결과 그래프
```

`run_all`은 비교군을 순서대로 처리합니다. 저장된 정책의 설정 지문이 같으면 다시 씁니다.
학습 시간은 조건에 따라 다릅니다.

| 조건 | 기준 모델 | 제안 모델 |
| --- | --- | --- |
| 교사 사용 (PPO 60반복) | 약 26초 | 약 600초 |
| 교사 없이 (PPO 2500반복) | 약 900초 | 약 3.4시간 |

`rl.earlyStopPatience`로 조기 종료를 켤 수 있지만 **기본값은 0(끔)** 입니다.
이 문제의 학습 곡선은 정체 구간이 평가 50회를 넘다가 뒤늦게 크게 좋아지므로,
정체를 기준으로 멈추면 최종 최고점을 놓칩니다. 근거는
`src/+landing2d/+rl/defaultRlConfig.m` 주석에 있습니다.

```matlab
run_all;                                   % 필요한 학습만 수행하고 전체 비교
run_all(struct('rlRetrain',true));         % 두 정책 모두 다시 학습
run_all(struct('figureVisible',false));    % 창 없이 계산과 저장만
run_all(struct('showLiveDashboard',false)); % 실시간 대시보드만 끄고 최종 그림은 생성
run_all(struct('controller','pd'));        % 기준을 기존 PD로 바꿔 실행
run_all(struct('stateRepresentation','gat'));    % 제거 실험으로 제안 모델 교체
run_all(struct('stateRepresentation','semantic_flat')); % 같은 의미 특징의 평탄 MLP 대조군
run_all(struct('scratchBaseline',false));        % 옛 혼합 초기화 조건을 의도적으로 재현
run_all(struct('useLegacyOntologyReward',true)); % 옛 보상 설계 비교군까지 포함
```

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

## 실시간 학습·온톨로지·평가 대시보드

`run_all`을 실행하면 기본으로 통합 대시보드가 열립니다. 한 창에서 다음 내용을
계산 진행과 함께 확인할 수 있습니다.

- 기준/제안 정책의 PPO 학습 점수와 평균 학습 return
- 평가 착륙률과 패드 포착률
- 온톨로지 R-GAT 학습의 train/validation loss와 현재 `G_t` 노드 값
- PN, baseline PPO, ontology graph PPO의 몬테카를로 평균 이동 궤적과 1σ 공분산 타원

저장된 정책을 재사용할 때도 저장된 학습 이력을 곡선으로 복원합니다. 대시보드는
표시 전용이며 정책 지문, 보상, 행동, 동역학 및 결과 저장값을 바꾸지 않습니다.
창을 닫아도 계산은 계속되며, `showLiveDashboard=false`로 처음부터 끌 수 있습니다.
최종 평가 시각화는 기본 20회 반복하며 모든 비교군이 같은 초기조건 표본을 사용합니다.
반복 수와 표본 범위는 다음 옵션으로 조절할 수 있습니다.

```matlab
run_all(struct('evaluationMonteCarloRuns',50));
% evaluationHeightRange / evaluationOffsetRange / evaluationSpeedRange
% evaluationMonteCarloSeed
```

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

## 강화학습 비교군의 공통 구조

기준 모델과 제안 모델은 아래를 **완전히 공유**합니다.
`landing2d.graphstate.assertSameProblem`이 학습 전에 실행 중으로 검사하고,
하나라도 다르면 즉시 중단합니다.

- **환경**: 유도 법칙과 같은 함수(`sensing.observePad`, `environment.resolveContact`,
  `dynamics.stepDrone`)와 같은 상태 전환 규칙(`control.trackingMode`)을 씁니다.
- **행동**: 제한 없는 2차원 명령을 환경이 `tanh`로 `axMax`, `azMax` 안에 넣습니다.
  포화가 정책 분포 밖에 있으므로 log 확률 보정이 필요 없습니다.
- **보상**: 아래 두 항. 계수와 형태 모두 같습니다.
- **종료 조건**: 착륙/접촉 실패 판정이 같습니다.
- **PPO**: 같은 구현(`landing2d.rl.ppoTrain`)을 씁니다. 클리핑 목적함수 + GAE이며,
  주기적으로 결정론적 평가를 해 **가장 좋은 정책을 보관**하고 마지막에 그것을 돌려줍니다.

### 보상 (두 항)

```text
r = captureWeight  * capture(s)
  + distanceWeight * distance(s)

capture  : 'margin' 시야 중앙 +1, 시야 가장자리 -1, 시야 밖 -1 (착륙 완료는 +1)
distance : 'hybrid' = share * 변화율 + (1-share) * 근접도
           변화율  = clip((이전거리 - 현재거리)/(dt*distanceRateScale), -1, 1)
           근접도  = clip(1 - (상대거리/distanceScale)^distanceExponent, -1, 1)
```

기본값은 `captureWeight = 0.20`, `distanceWeight = 0.71`,
`distanceRateShare = 0.30`, `distanceScale = 6.0`, `distanceExponent = 0.5`입니다.

변화율만 쓰면 어느 고도에 있든 누적 가치가 같아져(망원경 합) 고도를 포착 항이 혼자
결정하고 정책이 높은 곳에 머뭅니다. 근접도 항이 있어야 "낮은 곳에 있는 것" 자체에
가치가 생겨 착륙이 목표가 됩니다. 즉 변화율은 유도(shaping), 근접도는 목표(objective)입니다.

학습 설정은 `src/+landing2d/+rl/defaultRlConfig.m` 한 곳에 모여 있습니다.

### 학습 조건은 실험 설계에 따라 고릅니다

보상·행동·환경·종료 조건과 달리, **학습 조건은 세 가지 조합 중에서 고릅니다.**

| `cfg.scratchBaseline` | `cfg.graphState.useScratchSettings` | 내용 | 학습 조건 차이 |
| --- | --- | --- | --- |
| false | false | 둘 다 PN 유도를 교사로 모방 학습 | 없음 (통제됨) |
| false | true (기본) | 기준만 교사, 제안은 교사 없이 | 있음 (실행 시 출력) |
| true | true | 둘 다 교사 없이 | 없음 (통제됨) |

기본값이 두 번째인 이유는, 모방 학습으로 초기화하면 정책이 유도 법칙의 거동을 그대로
물려받기 때문입니다. 두 비교군을 모두 모방 학습으로 초기화했을 때 비가시 구간 궤적의
RMS 차이는 다음과 같았습니다(시나리오 1, 비가시 표본 3,463개).

| 비교 | 고도 RMS | 수평 오차 RMS |
| --- | --- | --- |
| PN 유도 vs 기준 모델 | 0.984 m | 0.616 m |
| PN 유도 vs 제안 모델 | 1.378 m | 0.486 m |
| 기준 모델 vs 제안 모델 | 0.766 m | **0.195 m** |

두 비교군이 서로 가까운 것은 제안 모델이 기준 모델을 따라가서가 아니라 **둘 다 같은
교사를 따라갔기 때문**입니다. 이 상태로는 패드가 시야에서 사라진 구간에서 상태 표현이
무엇을 바꾸는지 볼 수 없습니다.

기본값(세 번째)은 두 모델 모두 scratch 학습을 사용하므로 상태 표현 외 학습 조건이
같습니다. 두 번째 혼합 조건은 과거 실험 재현을 위해서만 명시적으로 선택하십시오.
`assertSameProblem`은 차이가 있으면 항목을 목록으로 돌려주며 `run_all`이 출력합니다.

```matlab
run_all(struct('scratchBaseline',true));   % 실험 변수 = 상태 표현 하나
```

## 제안 모델: 온톨로지 그래프 상태 표현

기준 모델과의 차이는 **PPO가 받는 상태 하나**입니다.

```text
기준 모델
  o_t (11차원 관측 벡터)  ->  Actor / Critic

제안 모델
  o_t와 같은 관측 정보
        -> 온톨로지 상황 그래프 G_t = (V_t, E_t, X_t)
        -> R-GAT으로 그래프 전체를 부호화 -> H_t  (9개 노드 임베딩)
        -> 그래프 수준 읽기(mean + max)   -> g_t
        -> Actor pi(a_t | g_t) / Critic V(g_t)
```

**온톨로지와 R-GAT은 보상에 전혀 관여하지 않습니다.** 보상 가중치 생성, 가중치 동적 변경,
보상항 교체/추가, 잠재함수 생성, 잠재 기반 보상 성형 가운데 어느 것도 이 경로에는 없습니다.

### 그래프 구성

노드와 간선은 기존 `landing2d.ontology.nodeSchema('core')` 그대로이며,
새 온톨로지 클래스나 관계를 만들지 않았습니다.

- 노드 9개: PositionError, DescentSpeed, PadMotion, FovMargin, SearchDuration,
  PadVisibility, RelativeDistance, TouchdownSafety, SafeLanding
- 관계 4종: `degrades`, `supports`, `contributes`, `self` (간선 22개)
- 관계 유형은 합치지 않습니다. `gat` 제거 실험에서만 하나로 합칩니다.

노드 특징 행렬 `X_t`:

```text
1     : 노드 값 (온톨로지가 정의한 크기, [0,1))
2     : 1 - 노드 값
3     : 위험 노드 표시
4     : 편향
5     : 방향 부호 ([-1,1], 방향이 없는 노드는 0)
6.... : 노드 정체성 one-hot
```

읽기는 **모든 노드**를 씁니다. 특정 노드(목표 노드 등)를 골라 쓰지 않습니다.

```text
g_t = tanh(W_g [mean(H_t, 노드축) ; max(H_t, 노드축)] + b_g)
```

Actor와 Critic은 각자 부호기를 하나씩 갖고, 기울기는 PPO 목적함수에서 R-GAT까지
끊김 없이 이어집니다. 미리 계산해 얼리지 않습니다.

### 정보경계

제안 모델은 기준 모델이 보는 정보만 씁니다. 노드 값을 계산하는
`landing2d.graphstate.observationSemantics`는 환경 참값 인자를 **아예 받지 않습니다**
(보상 설계용 `landing2d.ontology.semanticState`는 받습니다). 함수 서명 자체가
경계를 강제하고, `tests/test_graph_state_adapter.m`이 이를 검사합니다.

### 제거 실험

`cfg.graphState.stateRepresentation`으로 고르며, 네 설정 모두 **같은 PPO 구현**을 씁니다.

| 값 | 내용 |
| --- | --- |
| `baseline` | 기준 관측 벡터 (부호기가 항등이라 수치가 리팩터링 이전과 같음) |
| `node_pool` | 노드 특징 + 읽기, 메시지 전달 없음 (간선 미사용) |
| `gat` | 그래프 구조만 사용, 관계 유형을 하나로 합침 |
| `ontology_rgat` | 관계 유형을 유지한 R-GAT + 그래프 수준 읽기 (제안 모델) |

### 구현 중 찾아 고친 네 가지

온톨로지 의미 채널은 원래 **보상 가중치 설계**용이라 그대로 정책 상태로 쓰면 문제가
생겼습니다. 넷 다 노드·간선·관계 유형은 그대로 둔 채 적응 계층에서 고쳤습니다.
측정값과 근거는 `docs/ONTOLOGY_GRAPH_STATE_KO.md` 4절에 있습니다.

| # | 문제 | 수정 | 효과 |
| --- | --- | --- | --- |
| 1 | 잘라내기 정규화가 비행 영역을 못 덮음 (표본 74.6%에서 고도 소실) | 부드러운 포화 `x/(x+scale)` | 높은 고도 수평 명령 손실 0.0970 → 0.0411 |
| 2 | 노드 값이 전부 절댓값이라 좌/우·상승/하강 구분 불가 | `X_t`에 방향 부호 채널 추가 | 교사 모방 손실 0.352 → 0.038 |
| 3 | 읽기 단계 용량 병목 | `hiddenDim`/`graphDim` 16 → 32 | 모방 손실 0.0949 → 0.0667 |
| 4 | 추종/탐색 구간이 없어 종말 수직 명령이 학습 불가 | `PadVisibility` 부호 채널에 구간 탑재 | 종말 az 손실 0.0445 → 0.0007 |

4번이 가장 컸습니다. 교사의 수직 명령은 구간에 따라 법칙이 다른데
(h < 1.5 m에서 교사 az 평균이 `mode 1`은 0.024, `mode 2`는 **2.005**),
같은 물리 상태에서 명령이 정반대라 구간을 모르면 어느 쪽도 재현할 수 없습니다.
이 정보가 없을 때 정책은 하강 → 시야 상실 → 상승 → 재포착을 약 7초 주기로 반복하는
리밋 사이클에 갇혔습니다. 기준 관측 벡터는 이 값을 `o(2)`, `o(3)`으로 이미 받고
있었으므로 특권 정보가 아닙니다.

## 결과

### 두 비교군 모두 교사를 쓴 경우 (시드 3개, 통제된 비교)

| 상태 표현 | 시드별 착륙률 | 평균 착륙률 | 평균 점수 | 평균 포착률 |
| --- | --- | --- | --- | --- |
| 기준 관측 벡터 | 100% / 100% / 100% | 100% | +125.4 | 86% |
| 온톨로지 그래프 | 100% / 100% / 100% | **100%** | +97.0 | 84% |

두 비교군 모두 모든 시드에서 세 시나리오를 착륙합니다. 가장 좋은 실행의 제안 모델
점수(+142.98)는 기준 모델의 어느 시드보다 높지만, 느리게 착륙하는 실행이 있어 평균
점수는 아직 기준 모델보다 낮습니다.

`run_all` 한 번 실행 기준 착륙 시각:

| 비교군 | 시나리오 1 | 2 | 3 |
| --- | --- | --- | --- |
| PN guidance | 42.85 s | 54.98 | 57.63 |
| PPO (기준 상태) | 30.24 s | 39.25 | 42.06 |
| PPO (온톨로지 그래프) | 30.21 s | 39.20 | 41.62 |

### 두 비교군 모두 교사 없이 학습한 경우 (통제된 비교)

학습 조건 차이가 **0개**이므로 실험 변수는 상태 표현 하나뿐입니다.

| 상태 표현 | 최초 착륙 | 최종 착륙률 | 최종 점수 | 포착률 | 착륙 시각 |
| --- | --- | --- | --- | --- | --- |
| 기준 관측 벡터 | 없음 | 0% | -38.2 | 85% | 없음 |
| 온톨로지 그래프 | 550반복 | **100%** | **+151.4** | **95%** | 28.7 / 31.1 / 38.3 s |

기준 모델은 교사 없이는 한 번도 착륙하지 못하고, 포착률만 높은 국소 최적해
(떠서 패드를 시야에 유지)에 갇혔습니다. 초반 225반복에서 포착률 92%까지 올라간 뒤
오히려 나빠졌습니다.

제안 모델의 학습 경과입니다.

```text
550반복   최초 착륙
1100반복  점수 124.00 (착륙 100%)
~2300반복 이 점수를 넘지 못하는 긴 정체 구간
2375반복  점수 151.38 (착륙 100%)  <- 최종 선택
```

**정체 구간이 평가 51회에 이르다가 뒤늦게 크게 좋아집니다.** 그래서 "정체하면 멈춘다"는
조기 종료가 이 문제에서는 성능을 깎습니다(`rl.earlyStopPatience` 기본값이 0인 이유).

최종 점수 +151.4는 **교사를 쓴 기준 모델(+125.4)보다 높고**, 착륙 시각도
28.7 / 31.1 / 38.3 s로 더 빠릅니다. 학습에는 약 3.4시간이 걸렸습니다.

## 옛 제안 모델: 온톨로지 R-GAT 보상 가중치 설계 (legacy)

`cfg.useLegacyOntologyReward = true`일 때만 실행되는 **분리된 경로**입니다.
지우지 않고 남겼지만 새 제안 모델은 이 경로를 전혀 쓰지 않습니다.

이 비교군은 보상의 형태를 바꾸지 않고 두 항의 **가중치만** 온톨로지에서 추론합니다.

```text
1. 잡음을 섞은 유도 법칙 시연에서 온톨로지 그래프와 착륙 성공 여부를 모읍니다.
2. R-GAT이 안전 착륙 잠재함수 Phi(G) in [-1,1]를 학습합니다.
3. 보상항에 대응하는 노드를 "무해한 값"으로 바꿨을 때 Phi가 변하는 크기를 중요도로 봅니다.
4. designRepeats번 반복해 평균하고, 유계 단체에 사영해 가중치를 확정합니다.
```

`landing2d.ontology.applyDesign`은 자신이 지난 설정에 `ontologyRewardApplied` 표식을
남기고, `assertSameProblem`이 이 표식을 보고 새 제안 모델 경로에 옛 보상 설계가
섞여 들어오는 것을 거부합니다. 자세한 내용은 `docs/ONTOLOGY_RGAT_KO.md`에 있습니다.

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
| `graphState` | `defaultGraphStateConfig()` | 상태 표현 설정 묶음 (제안 모델) |
| `scratchBaseline` | true | true면 기준 모델도 교사 없이 학습(기본 통제 비교) |
| `useLegacyOntologyReward` | false | true면 옛 보상 설계 비교군까지 실행 |
| `ontology` | `defaultOntologyConfig()` | [legacy] 온톨로지/R-GAT 가중치 설계 설정 |

상태 표현 관련 설정은 `src/+landing2d/+graphstate/defaultGraphStateConfig.m`에 모여 있습니다.

| 항목 | 기본값 | 역할 |
|---|---|---|
| `stateRepresentation` | `'baseline'` | `baseline` / `node_pool` / `gat` / `ontology_rgat` |
| `hiddenDim`, `graphDim` | 32, 32 | R-GAT 노드 임베딩 폭 `d`, 그래프 표현 차원 `d_g` |
| `readout` | `'meanmax'` | `meanmax` 또는 `mean` |
| `encoderLearnRate` | 3e-4 | 부호기 Adam 학습률 |
| `positionScale`, `distanceScale` | 1.0, 3.0 | 채널 값이 0.5가 되는 지점 [m] |
| `useScratchSettings` | true | 제안 모델을 교사 없이 학습 |

`run_all`은 이 설정을 직접 건드리는 대신
`landing2d.graphstate.applyStateRepresentation(cfg, mode)`를 씁니다.
이 함수는 상태 표현과 저장 파일 이름만 바꾸고 보상·행동·환경은 건드리지 않습니다.

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
│  ├─ +graphstate/                # 온톨로지 그래프 상태 표현 (제안 모델)
│  ├─ +ontology/                  # [legacy] 보상 가중치 설계
│  ├─ +rgat/                      # 관계형 주의 계층 (두 경로가 공유)
│  ├─ +dynamics/                  # 드론 위치·속도 적분
│  ├─ +environment/               # 착륙/접촉 판정
│  ├─ +viz/                       # 실시간 화면, 탭 요약, 구간 배경
│  ├─ +metrics/                   # 요약 지표, 비교 지표, 상대거리
│  ├─ +io/                        # MAT/CSV/PNG/FIG 저장
│  └─ +util/                      # 포화, Adam, 기울기 클리핑, 체크섬
├─ tests/                         # 회귀/관측/구간/강화학습/온톨로지/그래프상태/그래픽 테스트
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
├─ rl_policy.mat                   # 기준 모델 정책 (교사 사용) + 설정 지문
├─ rl_policy_baseline_scratch.mat  # 기준 모델 정책 (교사 없이, scratchBaseline=true)
├─ rl_policy_graphstate_ontology_rgat.mat   # 제안 모델 정책
├─ comparison.mat
├─ comparison_summary.csv
├─ scenario_1_pn_guidance_log.csv
├─ scenario_1_ppo_rl_log.csv
├─ scenario_1_comparison.png       # 탭 1 (비교군을 겹쳐 표시)
├─ ...                             # 시나리오 2, 3도 같은 형식
└─ comparison_tabs.fig
```

`useLegacyOntologyReward = true`로 실행하면 옛 보상 설계 경로의 결과가 추가됩니다.

```text
├─ rl_policy_ontology.mat          # 추론한 가중치로 학습한 정책
├─ reward_design.mat               # R-GAT 파라미터, 학습 이력, 설계 지문
├─ reward_design_weights.csv       # 항별 중요도/부호/비율/가중치
└─ ontology_node_importance.csv    # 노드별 반사실 기여도
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
run_tests          % 16개: 수치 회귀 + 유도 + 정보경계 + 구간 + 검증 + 강화학습 + 온톨로지 + 그래프상태 + 그래픽
run_tests(false)   % 14개: 그래픽 테스트 제외
```

상태 표현 관련 테스트 세 개가 포함됩니다.

| 테스트 | 검사 내용 |
| --- | --- |
| `test_graph_state_adapter` | 정보경계(비가시 구간 참값 차단), 그래프 무결성, 방향 부호와 추종 구간 보존 |
| `test_graph_state_encoder` | 부호기 기울기(중앙 차분 대조), 노드 재번호 정합, 모든 노드가 읽기에 기여 |
| `test_graph_state_ppo` | 보상 동일(차이 < 1e-12), 행동 공간 동일, 기준 경로 불변, 순환 기억 없음, 학습 중 R-GAT 기울기 |

보상 동일성은 마지막 층을 0으로 만든 에이전트로 두 설정을 굴려, 같은 전이에서 보상열이
완전히 일치하는지 확인합니다.

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
