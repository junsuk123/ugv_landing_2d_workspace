# 실험 설계: 관계 기반 정책 표현의 유효성 검증 (`relational_policy_v1`)

2026-10-17 재설계. 이 문서는 실험이 **무엇을 주장할 수 있고 무엇은 주장할 수 없는지**와, 각 주장이 어느 코드·어느 출력에 대응하는지를 정의한다.

## 1. 연구 질문과 주장 범위

일반 PPO의 MLP도 12차원 관측 $o_t$에서 관측 품질·상대 운동·자세 사이의 비선형 관계를 학습할 수 있다. 따라서 이 연구는 "일반 PPO는 관계를 고려하지 못한다"고 주장하지 않는다.

검증 대상은 **구조적 사전지식(relational inductive bias)** 이다. TOSM 관계 구조를 R-GAT에 넣으면, 같은 관측·같은 예산에서 다음이 달라지는지를 본다.

| 기대 이점 | 이 실험에서 보는 곳 |
|---|---|
| 학습 효율: 같은 성능에 더 적은 환경 상호작용 | 학습 곡선, 목표 착륙률 도달 스텝, AUC (§5.1) |
| 학습 범위 밖 일반화 | 학습 범위 밖 조건의 성공률·추종 오차 (§5.4) |
| 상황별 관계 정보 집계 | 2×2 사례 효과·상호작용 (§5.3), open-loop 반응·attention 변화 (§5.5) |
| **올바른** 의미 관계의 필요성 | TOSM–R-GAT 대 관계 교란 R-GAT의 seed-paired 차이 (모든 절) |

다음은 이론적으로 기대하지 않는다.

- **새 정보.** 그래프는 $G_t=g(o_t)$로 결정론적으로 만들어진다. 따라서 정보 처리 부등식에 의해 $I(s_t;z_t)\le I(s_t;o_t)$이다. 관측에 없는 상태(예: 마커가 안 보일 때 시작된 UGV 가속)를 R-GAT가 알아낼 수는 없다. 이점이 있다면 같은 정보를 정책에 유용하게 조직하는 데서 나온다.
- **R-GAT의 우월성 보장.** 관계 구조가 틀리거나 불필요하면 오히려 학습이 나빠질 수 있다(Busbridge et al. 2019; Bechler-Speicher et al. 2024). 관계 추론 구조의 이득은 과제에 따라 다르다(Zambaldi et al. 2019).
- **attention 계수의 의미.** α가 "관측 품질이 나쁘면 해당 메시지를 줄인다"를 학습한다는 보장은 없다. α는 PPO 보상을 통해 간접 학습되며, 인과적 중요도도 아니다.

### 결과별 주장 범위

| 결과 (training seed 구간 기준) | 주장할 수 있는 것 |
|---|---|
| TOSM이 더 적은 스텝으로 목표 착륙률 도달 / AUC 큼 | 관계 구조의 학습 효율 개선 |
| TOSM이 학습 범위 밖 조건에서 더 높은 성공률·낮은 오차 | 해당 조건에서의 일반화 개선 |
| TOSM이 Shuffled보다 좋음 | 사전에 정의한 의미 관계 배치의 유효성 |
| TOSM ≈ Shuffled > PPO | 그래프 구조 자체의 효과일 뿐, TOSM 의미 관계의 근거는 아님 |
| TOSM ≈ PPO | 현재 2D 문제에서 관계형 표현의 추가 가치가 제한적 |
| PPO가 지속적으로 우수 | 현재 문제에 TOSM–R-GAT가 불필요하거나 구현 재검토 필요 |

한 학습 시드만으로는 어떤 줄도 주장하지 않는다. 시드 하나의 결과는 실행 간 변동을 담지 못한다(§6).

## 2. 비교군 (3개 고정)

| id | 상태 표현 | 역할 |
|---|---|---|
| `ppo` (M1) | 12차원 $o_t$ → MLP 48-48 | 일반 비선형 정책 표현의 기준 |
| `onto_rgat_ppo` (M2) | 같은 $o_t$의 TOSM 7노드 그래프 → R-GAT → MLP 35-38 / 35-30 | 올바른 의미 관계를 쓰는 제안 모델 |
| `shuffled_rgat_ppo` (M3) | M2와 동일하되 의미 관계 유형을 고정 순열로 교란(self 보존) | 관계 의미가 중요한지 보는 대조군 |

- 세 모델은 환경·센서·보상(reward_v5)·행동·종료·PPO 손실·예산(750 update × 6 episode)·검증 일정·파라미터 수(6,101개)가 같다. 다른 것은 Actor/Critic 상태 표현뿐이다.
- **R-GAT 전용 손실 항 제거.** 이전 코드에는 R-GAT에만 연속 결정 명령 차이를 벌하는 평활화 항(`temporalPolicyConsistencyWeight = 0.03`)이 있었다. 이 항은 한 비교군의 손실을 바꾸고, "불필요한 명령 변화" 지표를 그 비교군에 유리하게 만든다. 그래서 삭제했다(`landing2d.rl.ppoTrain`).
- **attention은 입력 의존**(`input_dependent_v1`)이다. $\alpha^{(r)}_{ij}(X_t)$가 현재 노드 특징에 따라 바뀐다. 이전의 `fixed_relation_v1`은 관측과 무관한 관계별 가중치였다. 파라미터 수는 같다.
- M3의 그래프 시드는 학습 시드와 같다(`s01_g01`, `s02_g02`, …). 그래서 M3의 시드 간 평균은 관계 순열에 대해서도 평균한 값이다.
- 같은 학습 시드의 세 비교군은 같은 학습 에피소드 순서를 본다(`rl.episodeStreamSeedOffset`). 비교군 차이는 학습 시드별로 짝지어 계산한다.
- 이번 설계에서 다루지 않은 대조군: Semantic-Flat PPO, R-GCN PPO, PPO-LSTM. 필요하면 별도 추가 실험으로 등록해야 하며, 현재 결과로 이들과의 비교를 주장하지 않는다.

## 3. 환경

드론 동역학(피치·추력 응답, $a_x\le2.5$, $a_z\le2.0$ m/s²), 제어 주기 0.1 s / 물리 0.01 s, 카메라 FOV·투영, PnP·KF 상태추정, 패드·접촉 판정, reward_v5는 바꾸지 않았다. 바뀐 것은 시나리오 표본과 초기 조건뿐이다.

### 3.1 학습 분포 (2×2 요인, 서로 독립)

| 요인 | 값 | 설정 |
|---|---|---|
| UGV 운동 $m$ | 확률 0.5로 등속(CV, $a_2=0$), 아니면 CV–CA–CV | `scenario.constantVelocityProbability` |
| 초기 UGV 속도 $v_1$ | 0.5–2.0 m/s | `v1Range` |
| 가속도 $a_2$ | 0.3–0.8 m/s² (CA일 때) | `a2Range` |
| 가속 시작 $T_1$ / 지속 $T_2$ | 1–4 s / 0.5–2 s (시작 시각 무작위 → 경과시간으로 가속을 맞힐 수 없음) | `T1Range`, `T2Range` |
| 시작 고도 | 4–8 m | `heightRange` |
| 초기 상대속도 $\Delta v$ | 확률 0.5로 0, 아니면 U(−0.3, 0.3) m/s | `initialSpeedMismatchProbability`, `initialSpeedOffsetRange` |
| 초기 위치 편차 $\delta e_x$ | U(−0.3, 0.3) m. 시작 위치 = 카메라 광축 기준점 $h\tan\gamma$ + $\delta e_x$. 수평 자세에서 패드가 시야 안일 때만 적용 | `initialPositionOffsetRange` (`reset`) |
| 관측 $p$ | 확률 0.5로 정상. 아니면 마커 검출 누락 1회: 경미 0.2–0.4 s 또는 심함 0.5–1.0 s(각 0.5). 시작 시각 U(0.5, 12) s로 $T_1$과 독립 | `sensor.perturbation` |

- 네 셀(CV·CA × 정상·누락)이 각각 약 25%다(selfTest `scenario-family`가 검사).
- 학습에서는 누락이 가속과 일부러 겹치지 않는다. "마커가 안 보이면 UGV가 가속한다"는 거짓 상관을 막기 위해서다.
- 누락 중에도 관측 벡터를 0으로 만들지 않는다. 추정기는 마지막 갱신에서 예측한다.
- 외부에서 주입한 누락(`ExogenousDropout_s`)과 정책이 패드를 시야 밖으로 보내서 생긴 시야 이탈(`ApproachViewLoss_s`)은 따로 기록한다.

### 3.2 착륙 조건

접지 판정은 그대로다: 수평 패드 반길이 0.5 m, 상대속도 0.35 m/s, 수직속도 0.30 m/s, 피치 5°, 피치각속도 10°/s. `LandingCondition` 노드는 현재 추정 상대 위치·속도·자세를 이 한계로 나눈 비율일 뿐이다. 착지 예측기나 guard가 아니다.

## 4. 시드 계약

| 용도 | 범위 | 사용처 |
|---|---|---|
| validation | 2001–2200 (100개 사용) | PPO 중 체크포인트 선택, 학습 곡선 |
| test | 3001–3200 (200개 사용) | 학습 분포 held-out 평가, open-loop probe 상태 |
| stress | 9001–9200 (100개 사용) | 학습 범위 밖 일반화 |
| 고정 사례 | 41001–49999 (S1–S4 = 43001 + r − 1) | 2×2 통제 사례 |
| PPO 학습 에피소드 | 100001–999999 | `ppoTrain` (전용 난수열) |
| train | 1–2000 | 예약 |
| 학습 시드 $s$ | 기본 1–5 (`registry.trainSeeds.default`), 확장 1–10 | `rl.seed = 20240501 + s − 1` |

- 모든 환경 시드는 $10^6$ 미만이다. 같은 시드의 여러 난수열(시나리오·센서·잡음표·정책)은 $10^6$ 간격 오프셋을 쓰므로 서로 겹치지 않는다(`validatePrimaryConfig`).
- test·stress·고정 사례 시드는 체크포인트를 선택하지 않는다.

## 5. 평가 (`landing2d.orchestration.runEvaluation`)

모든 지표는 rollout이 끝난 뒤 평가 전용 참값으로 계산한다(`landing2d.evaluation.episodeMetrics`). 온톨로지 노드·attention·보상은 지표에 쓰지 않는다.

**추종 오차는 aim error** $e_{aim}=e_x-h\tan\gamma$다. 공통 보상이 추종하는 카메라 광축 기준점에서의 수평 오차이며, 착지 시 0이 된다. 고고도에서 $e_x\approx h\tan\gamma$는 설계된 접근 자세다. 그래서 $e_x$ 자체를 오차로 쓰지 않는다.

### 5.1 학습 효율 (`learningEfficiency`)

PPO 중 25 update마다 validation 100개 에피소드의 착륙률을 누적 환경 스텝(결정 수)에 대해 기록한다.

- `StepsTo50`, `StepsTo80`: 착륙률이 처음 50%, 80%에 도달한 스텝. 도달하지 못하면 예산 값으로 censor하고 `Reached = 0`으로 표시한다.
- `AUC`: 학습 곡선 아래 면적 ÷ 예산.
- `BestValidationSuccess`, `SelectedIteration`도 함께 기록한다.

validation은 체크포인트 선택에도 쓰이므로, 이 수치는 held-out 성능이 아니라 학습 속도다.

### 5.2 학습 분포 held-out (`heldOut`)

test 200개 에피소드(모든 run이 같은 에피소드)로 성공·unsafe·timeout, aim error RMS, 상대속도 RMS, 명령 변화율 RMS, 시야 이탈, 부적절 하강을 잰다. 전체와 네 셀별로 보고한다.

### 5.3 2×2 통제 사례 (`factorialCases`, `factorialStudy`)

| 사례 | UGV | 마커 |
|---|---|---|
| S1 | CV ($v_1=1.0$) | 정상 |
| S2 | CV | 3.0–3.8 s 누락 |
| S3 | CA 0.6 m/s², 3.0–4.5 s | 정상 |
| S4 | CA | 누락이 가속 시작과 겹침 (3.0–3.8 s) |

- 모든 값이 학습 범위 안이다. 네 사례는 반복마다 같은 시드(초기 상태·잡음표 동일), 같은 deadline(30 s), 같은 평가 구간 [3.0, 4.5) + settling 2 s를 쓴다. 반복은 20회다.
- 반복별로 다음 효과를 계산한 뒤 run별로 평균한다($L$은 구간 aim error RMS, 상대속도 RMS, 명령 변화율 RMS, 실패율, 부적절 하강).
  - 관측 효과: S2−S1(CV), S4−S3(CA)
  - 운동 효과: S3−S1(정상), S4−S2(누락)
  - **상호작용** $I_L=L_{S4}-L_{S3}-L_{S2}+L_{S1}$: 누락과 가속이 겹칠 때, 각각의 효과를 더한 것보다 추가로 생기는 변화
- $I_L$은 이 설계의 실험적 상호작용이다. 관계 하나가 그 변화를 인과적으로 설명한다는 뜻이 아니다. 사례별 평균과 성공률을 함께 읽는다.
- 명령 변화 감소는 같은 쌍의 추종 오차가 유지될 때만 개선으로 본다. 운동 효과에서 명령 변화가 커지는 것은 필요한 반응일 수 있다.

### 5.4 학습 범위 밖 일반화 (`generalization`)

stress 100개 에피소드를 모든 조건에 똑같이 쓴다(조건 간 짝지음).

| 조건 | 변경 | 학습 범위 |
|---|---|---|
| motion | 모든 에피소드 CA, $a_2$ 1.0–1.5 m/s² | 0.3–0.8 |
| dropout | 모든 에피소드 1.0–2.0 s 누락 | ≤ 1.0 s |
| noise | 센서 잡음 표준편차 ×2 | ×1 |
| combined | motion + dropout | — |

동역학·보상·종료·정책은 그대로다. 그림은 학습 분포 test 결과를 기준으로 함께 보여준다.

### 5.5 Open-loop 동일 상태 probe (`buildProbeSet`, `openLoopProbes`)

폐루프 비행은 정책마다 궤적이 달라져 관측도 달라진다. 이 혼동을 없애기 위해 **모든 정책에 똑같은 관측**을 넣는다. probe 상태는 정책과 무관한 기준 구동기가 test 20개 에피소드를 실제로 비행한 궤적에서 얻는다. 관측은 환경과 같은 센서 경로(`replaySensing`)로 다시 만들며, 명목 재생은 환경 관측과 비트 단위로 같아야 한다.

- **속도 대비**: 마커가 갱신된 상태에서 UGV 속도 추정만 ±0.3 m/s 바꾼다. 상대 위치는 같고, `ugv_vx`와 `relative_vx`가 함께 바뀐다.
  - `SensitivityX` $=(a_x^+-a_x^-)/(2\Delta v)$ [1/s]. UGV가 더 빠르면 앞으로 가속해야 하므로 기대 부호는 양수다.
  - `PositiveSensitivity`: 기대 부호인 probe의 비율.
  - 기준 구동기의 값(속도 이득 1.8)을 척도 기준으로 함께 보고한다.
- **갱신 대비**: 같은 물리 궤적에서 마지막 0.8 s의 마커 프레임을 빼고 재생한다. 추정기는 예측만 한다.
  - `DeltaAx/Az`: (갱신 없음 − 갱신) 명령 차이.
  - `EstimateShift`: 추정 오차 변화. 추정이 거의 같은데 명령이 크게 바뀌면, 추정값이 아니라 갱신 플래그·경과시간에 반응한 것이다.
  - `AttentionShift`: R-GAT 첫 층 Actor attention의 VisionQuality 출발 간선 평균 |Δα|. 기술 지표일 뿐 중요도가 아니다.

## 6. 통계

- **분석 단위는 학습 시드(run)다.** 각 run을 에피소드·반복 평균으로 먼저 요약한다(`runMeans`). 그다음 학습 시드에 대해 평균과 95% t 구간을 낸다(`seedSummary`).
- **비교군 차이는 학습 시드별 짝 차이**다(`methodContrasts`: TOSM−PPO, TOSM−Shuffled, Shuffled−PPO). 평균, 95% t 구간, A>B인 시드 수를 함께 낸다.
- 학습 시드가 하나면 구간은 NaN이다. 잡음 반복 20회의 변동은 한 학습 실행 안의 변동이지 방법 간 차이의 근거가 아니다.
- 5개 시드의 t 구간은 넓다. 구간이 0을 포함하면 "차이의 증거 없음"으로 보고한다. 차이를 주장하려면 `run(struct('trainSeeds',1:10))`로 늘린다.

## 7. 실행 순서

```matlab
run_check                    % self-test 14개 + 모든 단계 smoke (수 분)
run_check('learnability')    % 일반 PPO가 쉬운 구석(CV·정상·속도 일치)에서 착륙을 배우는지 사전 점검
run                          % 3 비교군 × 학습 시드 1–5 학습 → 평가 5종 → 그림
run_scenario('S4')           % 통제 사례 하나의 궤적 보기 (학습된 체크포인트 필요)
```

- 새 환경에서 비교 결과를 믿기 전에 learnability 점검이 통과해야 한다. 이것은 네 번째 비교군이 아니라 과제의 학습 가능성 점검이다.
- `run`은 학습 서명이 맞는 체크포인트를 재사용한다. 중간에 멈춰도 다시 실행하면 이어서 진행한다. 모두 다시 학습하려면 `retrain = true`를 준다.

## 8. 출력

| 경로 | 내용 |
|---|---|
| `results/checkpoints/<method>_sNN[_gNN].mat` | agent, 학습 기록, 학습 서명, 실행 식별 |
| `results/evaluation/*.csv`, `results.mat` | 절별 에피소드 표, run 평균, 시드 요약, 비교군 대비 |
| `results/figures/fig_*.png` | contrasts, learning, heldout, factorial, trajectories, generalization, probes |

## 9. 코드 대응

| 내용 | 위치 |
|---|---|
| 시나리오 표본·초기 편차 | `+scenario/sampleParameters`, `+environment/reset` |
| 관측 요인 | `+sensing/sampleEvents` |
| 설정 | `+config/defaultPlanarVisibilityConfig`, `primaryConfig`, `defaultEvaluationConfig`, `methodRegistry`, `applyMethod` |
| PPO (공통) | `+rl/ppoTrain`, `trainAgent`, `loadOrTrainAgent` |
| R-GAT | `+graphstate/contextSchema`, `observationVectorGraph`, `encoderInit/Forward/Backward`, `+rgat/*` |
| 평가 | `+evaluation/*` |
| 실행 | `+orchestration/runPipeline`, `runCheck`, `runScenario`, `selfTest` |
| 그림 | `+viz/plotResults`, `plotTrajectories` |

## 참고문헌

- Battaglia et al. (2018), Relational inductive biases, deep learning, and graph networks.
- Busbridge et al. (2019), Relational Graph Attention Networks.
- Zambaldi et al. (2019), Deep Reinforcement Learning with Relational Inductive Biases, ICLR.
- Bechler-Speicher et al. (2024), Graph Neural Networks Use Graphs When They Shouldn't, ICML.
- Li, Walsh, Littman (2006), Towards a Unified Theory of State Abstraction for MDPs.
- Kaelbling, Littman, Cassandra (1998), Planning and acting in partially observable stochastic domains.
- Henderson et al. (2018), Deep Reinforcement Learning that Matters, AAAI.
- Agarwal et al. (2021), Deep Reinforcement Learning at the Edge of the Statistical Precipice, NeurIPS.
