# 실험 설계: 관계 기반 정책 표현의 유효성 검증 (`relational_policy_v1`)

2026-10-17 재설계. 이 문서는 실험이 **무엇을 주장할 수 있고 무엇은 주장할 수 없는지**와, 각 주장이 어느 코드·어느 출력에 대응하는지를 정의한다.

## 1. 연구 질문과 주장 범위

일반 PPO의 MLP도 공통 관측 $o_t$(v2.3부터 10차원)에서 관측 품질·상대 운동·자세 사이의 비선형 관계를 학습할 수 있다. 따라서 이 연구는 "일반 PPO는 관계를 고려하지 못한다"고 주장하지 않는다.

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

### 둔감함과 반응성: 함께 읽는 규칙 (결과 전에 고정)

원하는 정책 특성은 "관측 교란에는 불필요하게 반응하지 않고, 실제 운동 변화에는 반응한다"이다. 작은 잡음 민감도나 작은 궤적 분산만으로는 이것을 주장하지 않는다. 입력을 무시하는 정책도 잡음에 둔감하기 때문이다.

| 둔감함 쪽 지표 | 반응성 쪽 지표 (같이 읽음) |
|---|---|
| open-loop 잡음 민감도 `NoiseActionVar` $=\mathrm{tr\,Cov}[a]$ (§5.5) | 같은 probe 상태의 속도 민감도 `SensitivityX` (기대 부호 양수) |
| S2 궤적 분산 `TrajectoryVariance_m2` (§5.3) | S3·S4 구간 aim error RMS, CA 에피소드 `RecoveryTime_s` |
| 누락 효과의 명령 변화 `Dropout\|CA` (§5.3) | 같은 쌍의 구간 aim error RMS |

| 결과 (TOSM−PPO, TOSM−Shuffled의 시드 짝 차이) | 해석 |
|---|---|
| 둔감함 ↓ **그리고** 반응성 유지(구간이 0을 포함하거나 개선) | 관측 교란에 덜 민감하면서 운동 변화 대응을 유지 (가장 강한 주장) |
| 둔감함 ↓ **그러나** 회복 시간·추종 오차 악화 또는 `SensitivityX` 감소 | robustness가 아니라 과도한 평활화·보수적 정책 가능성. 개선으로 보고하지 않음 |
| 둔감함 차이 없음 | 해당 축에서 관계 구조의 효과 근거 없음 |

TOSM−Shuffled 차이가 이 규칙을 만족할 때만 "의미 관계 배치"의 효과로 읽는다. TOSM−PPO만 만족하면 그래프 구조 자체의 효과일 수 있다.

## 2. 비교군 (3개 고정)

| id | 상태 표현 | 역할 |
|---|---|---|
| `ppo` (M1) | 10차원 $o_t$ → MLP 48-51 / 47-50 (v2.2까지 12차원, 48-48) | 일반 비선형 정책 표현의 기준 |
| `onto_rgat_ppo` (M2) | 같은 $o_t$의 TOSM 7노드 그래프 → R-GAT → MLP 38-42 / 40-36 | 올바른 의미 관계를 쓰는 제안 모델 |
| `shuffled_rgat_ppo` (M3) | M2와 동일하되 의미 관계 유형을 고정 순열로 교란(self 보존) | 관계 의미가 중요한지 보는 대조군 |

- 세 모델은 환경·센서·보상(reward_v5)·행동·종료·PPO 손실·예산(750 update × 6 episode)·검증 일정·파라미터 수(6,101개)가 같다. 다른 것은 Actor/Critic 상태 표현뿐이다.
- **R-GAT 전용 손실 항 제거.** 이전 코드에는 R-GAT에만 연속 결정 명령 차이를 벌하는 평활화 항(`temporalPolicyConsistencyWeight = 0.03`)이 있었다. 이 항은 한 비교군의 손실을 바꾸고, "불필요한 명령 변화" 지표를 그 비교군에 유리하게 만든다. 그래서 삭제했다(`landing2d.rl.ppoTrain`).
- **attention은 입력 의존**(`input_dependent_v1`)이다. $\alpha^{(r)}_{ij}(X_t)$가 현재 노드 특징에 따라 바뀐다. 이전의 `fixed_relation_v1`은 관측과 무관한 관계별 가중치였다. 파라미터 수는 같다.
- M3의 그래프 시드는 학습 시드와 같다(`s01_g01`, `s02_g02`, …). 그래서 M3의 시드 간 평균은 관계 순열에 대해서도 평균한 값이다.
- **M3 교란 비율 하한(2026-10-18).** 의미 간선 13개 중 최소 10개(`registry.relationShuffle.minChangedFraction = 0.7`)의 관계 유형이 바뀐 순열만 받는다. 제약 없는 순열은 평균 47/13 ≈ 3.6개 간선의 원래 유형을 우연히 유지한다. 이전 레지스트리(v3)의 그래프 s01–s05는 각각 7·8·10·6·10개만 바뀌어, 세 run이 TOSM 배치의 절반 가까이를 유지했다. 하한은 학습 서명(`graphState.relationPerturbation`)에 들어가므로 M3 체크포인트는 다시 학습된다. 실제 교란 비율은 `training_relations.csv`에 기록된다(§5.6).
- **M3 연산군 교란 하한(2026-10-19, registry v5).** `typed_v1`의 실제 계산은 네 관계 이름이 아니라 `modulate`/`propagate` 두 연산군으로 나뉜다. v4의 라벨 변경 하한만으로는 연산군 변경을 보장하지 않았다. 실제 n=8 그래프에서 연산군 변경 수는 시드별 4–10/13이었고, 시드 3은 라벨 10개가 바뀌어도 연산군은 4개만 바뀌었다. v5는 관계별 간선 수와 self 보존을 그대로 유지하면서 연산군도 최소 10/13개 바뀌게 한다(`minOperatorChangedFraction = 0.7`). 원래 modulate 8개·propagate 5개를 유지하는 순열에서 가능한 최대 변경이 10개이므로, 이는 결과를 보고 특정 순열을 고르는 기준이 아니라 모든 그래프 시드에 동일하게 적용되는 구조적 대조군 계약이다.
- 같은 학습 시드의 세 비교군은 같은 학습 에피소드 순서를 본다(`rl.episodeStreamSeedOffset`). 비교군 차이는 학습 시드별로 짝지어 계산한다.

### 2.1 관계 연산자 `typed_v1` (2026-10-18, 설계 이력 포함)

**이력.** 첫 설계(`additive_v1`)에서는 모든 관계가 같은 덧셈 메시지 형태였고, 관계 유형마다 가중치 $W_r$만 달랐다. 시드 1–5에서 TOSM과 교란 대조군은 성공률·학습 속도·잡음 민감도에서 차이가 없었고, 가속 사례(S3·S4)에서는 대조군이 더 잘 추종했다(`results/checkpoints/archive/pre_fix_2026-10-18` 이후 재평가). 이 설계 변경은 그 test 결과를 본 뒤에 이루어졌으므로 아래 확인 실험은 이 사실을 함께 보고한다.

**진단(validation만 사용).** 학습된 두 모델 모두 의미 간선을 실제로 쓴다. 의미 간선을 모두 제거하면 validation 착륙률이 약 0.44–0.46으로 떨어진다. 그러나 노드마다 특징 채널의 의미가 달라서, 한 관계로 묶인 간선이 $W_r$을 공유해도 얻는 구조가 없다. 그래서 어떤 묶음(TOSM이든 교란이든)으로도 같은 성능을 학습한다. 관계 유형이 계산에서 의미를 갖지 않는 구조였다.

**변경.** 관계 유형이 메시지의 연산 형태를 정한다(`contextSchema.relationOperators`).

| 관계 | 의미 | 연산 |
|---|---|---|
| `qualifiesEstimate` | 관측 품질이 추정치의 신뢰를 정한다 | 조절(modulate) |
| `conditionsLanding` | 조건이 착륙 판단의 무게를 정한다 | 조절(modulate) |
| `informsMotion`, `affectsVisibility`, self | 출발 상태가 도착 상태를 바꾼다 | 전파(propagate) |

$H = (1+\tanh(\mathrm{RGAT}_{mod}(X)))\odot\tanh(\mathrm{RGAT}_{prop}(X)+W_0X+b_0)$. 전파 간선(self 포함)과 조절 간선은 각각 도착 노드 기준으로 정규화된 attention 그래프다. `operator_shared_v1`에서는 전파와 조절 연산군이 각자의 $W_1,a_1,E_1$ 한 묶음을 공유한다. 따라서 교란된 관계 라벨이 독립 파라미터를 통해 새 의미로 재학습되는 우회 경로가 없다. 줄어든 인코더 파라미터는 Actor 38-42·Critic 40-36 head로 옮겨 전체는 6,101개로 유지한다. 조절 간선이 없는 노드의 게이트는 정확히 1이고, 초기값에서도 1 근처다. 연산 종류는 관계 유형에 붙으므로 교란 대조군에서는 같은 연산자가 순열된 간선에 적용된다. 보상·손실·환경·관측은 바뀌지 않는다. `additive_v1`과 기존 관계별 파라미터 방식은 명시적 설정 선택지로만 유지한다.

**사전 가설 (개발·확인 결과 전에 기록).**
- H1: 품질 게이트가 올바른 간선(VisionQuality → 추정 노드)에만 있으므로, 누락 관련 지표(`TrackingReacquisition_s`, S2·S4 구간 aim error, stale 갱신 반응)에서 TOSM − Shuffled < 0.
- H2: 가속 대응(`RecoveryTime_s`, S3 구간 aim error)은 TOSM이 Shuffled보다 나쁘지 않다.
- 해석은 §1의 규칙을 그대로 따른다. H1·H2가 지지되지 않으면 그대로 보고한다.

**절차.** 개발은 학습 시드 6·7과, 체크포인트 선택에 쓰지 않은 validation 시드 2101–2200으로만 한다. 확인 실험은 학습 시드 1–5에서 전체 평가를 한 번 실행한다. test·S1–S4·stress·probe는 확인 실험에서만 쓴다.

**개발 결과 (시드 6·7, validation 2101–2200, 시드 2개라 판단 근거 아님).**
- 학습 AUC: TOSM 0.72·0.70 대 Shuffled 0.10·0.57. 두 시드 모두 TOSM이 공중 정지 국소해를 먼저 벗어났다(Shuffled 시드 6은 예산 안에서 미수렴, best validation 0.74).
- 수렴 후 추종: 시드 7에서 TOSM이 나빴다(aim error 0.39 대 0.25 m, CA 회복 6.6 대 3.2 s). 시드 6은 비슷했다. H1·H2는 개발 단계에서 지지되지 않았다.
- 검토 후 기각한 가설: `informsMotion`이 수평(RelativeVelocity → RelativePosition)과 수직(DroneMotion → RelativePosition) 운동을 같은 $W$로 묶어 간섭한다는 가설. 시드 7에서 수직 간선만 제거하면 CA 추종이 오히려 나빠져(aim error 0.55 → 0.74 m) 기각했고, 이에 따른 온톨로지 수정은 하지 않았다.

**확인 결과 (시드 1–5, 2026-10-18 20:41 평가, `results/evaluation`).**
- TOSM − Shuffled 시드 짝 차이 중 95% 구간이 0을 벗어난 headline 지표는 없다. 규칙상 "TOSM ≈ Shuffled"로 보고한다.
- 학습 수렴: TOSM은 5/5 시드가 수렴했다(held-out 성공률 0.94–0.995). Shuffled는 시드 4가 예산 안에서 수렴하지 못했다(best validation 0.63, held-out 0.54). 개발 시드를 포함하면 `typed_v1`에서 미수렴은 TOSM 0/7, Shuffled 2/7이다. 방향은 TOSM 쪽이지만 표본이 작아 통계적 근거는 아니다(Fisher 정확검정 p ≈ 0.46).
- 수렴한 시드끼리(1·2·3·5)의 추종 품질은 엇갈린다. aim error 차이는 +0.06·−0.10·−0.07·+0.02 m다.
- open-loop 속도 민감도: TOSM 1.66, Shuffled 0.87, 기준 구동기 1.8(차이 +0.79 ± 1.05, 4/5 시드). 잡음 민감도는 차이가 없다(+0.014 ± 0.066). 반응성 쪽 방향이지만 구간이 0을 포함한다.
- `additive_v1`에서 유의했던 S4 구간 aim error의 Shuffled 우위(+0.20 ± 0.16 m)는 `typed_v1`에서 나타나지 않았다(−0.46 ± 1.42, 시드 4 영향 큼).
- H1·H2: 지지도 반증도 되지 않았다(구간이 넓음). 주장하려면 새 학습 시드(8–10 등)를 추가해야 한다. 개발에 쓴 시드 6·7은 확인 분석에 넣지 않는다.
- 이번 설계에서 다루지 않은 대조군: Semantic-Flat PPO, R-GCN PPO, PPO-LSTM. 필요하면 별도 추가 실험으로 등록해야 하며, 현재 결과로 이들과의 비교를 주장하지 않는다.

**확장 계획 (2026-10-18 22:20, 시드 8–10 학습 전에 기록).**
- 결정 시점: 시드 1–5 확인 결과를 본 뒤에 정한 순차 확장이다. 그래서 n = 5 결과(위)와 n = 8 결과를 함께 보고한다. 이 확장 결과를 보고 시드를 더 넣거나 빼지 않는다. 더 늘리려면 새 확인 실험으로 따로 등록한다.
- 학습: 새 학습 시드 8–10에서 3 비교군 모두(PPO 포함)를 학습한다. 설정·예산·코드는 시드 1–5와 같다(`typed_v1`, 750 update). 시드 8–10은 이전에 학습·평가에 쓴 적이 없다.
- 분석 집합: 학습 시드 {1–5, 8–10}, n = 8. 개발 시드 6·7은 넣지 않는다.
- 평가: `run(struct('trainSeeds',[1:5 8:10]))`를 한 번 실행한다. 시드 1–5만으로 낸 20:41 평가는 덮어쓰기 전에 보관한다.
- 지표: §6의 headline 짝 차이와 §1의 함께 읽는 규칙을 그대로 쓴다. 수렴 여부는 기존 지표 `Reached80`(학습 중 validation 착륙률 0.8 도달, `c.evaluation.learning.targets`)으로 정한다. 수렴 비교는 시드별 짝 개수와 McNemar 정확검정(양측, 불일치 쌍의 이항검정)으로 보고하고, p < 0.05일 때만 차이를 주장한다.
- H1·H2와 해석 규칙은 바꾸지 않는다.

**확장 결과 (registry v4, 시드 1–5·8–10, n=8, 2026-10-19 02:50 평가).**
- held-out 성공률은 TOSM 0.9319, Shuffled 0.9238로 짝 차이 `+0.0081 ± 0.1770`이었다. 학습 AUC 차이는 `−0.0009 ± 0.1800`이었다.
- S4 구간 aim error 차이는 `−0.173 ± 0.802 m`, open-loop 속도 민감도 차이는 `+0.547 ± 0.688`, 잡음 유발 행동 분산 차이는 `+0.010 ± 0.036`으로 모두 95% 구간이 0을 포함했다.
- 요인 상호작용에서는 TOSM의 aim error가 `+0.103 ± 0.079 m`, 명령 변화율이 `+0.103 ± 0.080 m/s³` 더 컸다. 둘을 함께 읽어도 TOSM에 유리한 방향이 아니다. stale-update 수평 반응 크기도 `+0.129 ± 0.087 m/s²`로 더 컸다.
- 결론은 n=5와 같다. H1·H2와 올바른 관계 의미의 우위는 입증되지 않았다. 그래프 특징 자체의 효과와 관계 의미의 효과를 구분할 수 없으며, v4 결과를 폐기하거나 성공 결과로 재해석하지 않는다.

**원인 진단과 대조군 수정 계획 (2026-10-19, 새 학습 전 고정).**
- 정보 한계: S4에서 누락 중 시작된 미관측 UGV 가속은 어느 정책도 알 수 없다. 따라서 품질 관계가 숨은 가속을 복원한다는 주장은 하지 않는다. H1은 같은 관측에서 불필요한 반응을 줄이는지와 측정 재획득 뒤 회복하는지만 본다.
- attention 한계: `qualifiesEstimate` 세 간선은 modulate 부분그래프에서 각 도착 노드로 들어가는 유일한 간선이라 softmax 계수는 항상 1이다. 품질 반응은 attention 변화가 아니라 메시지로 만든 gate에서 생긴다. attention 변화는 계속 기술 지표로만 둔다.
- 식별 실패: v4 셔플은 관계 라벨 10/13개 변경만 강제하여 실제 연산군은 4/13개만 바뀌는 그래프도 허용했다. v5는 위의 연산군 하한을 추가한다. 보상·환경·관측·PPO 손실·예산·파라미터 수와 TOSM 그래프는 바꾸지 않는다.
- 보상 가능성: v4는 네 관계 라벨마다 독립적인 $W_1,a_1,E_1$을 학습하므로, 잘못 붙은 라벨도 학습 중 해당 간선 묶음의 새 의미로 재정의할 수 있었다. v5 `operator_shared_v1`은 modulate/propagate별로 파라미터를 공유하고 절약분을 head로 옮겨 총 파라미터 수를 보존한다. 이는 출력 가드나 추가 손실이 아니라 비교하려는 관계 연산의 식별성을 확보하는 표현 제약이다.
- 개발 확인은 이미 개발에 사용한 학습 시드 6·7과 validation 2101–2200만 쓴다. test·stress·S1–S4·probe를 보고 구현을 고르지 않는다.
- 새 확인 실험은 아직 쓰지 않은 학습 시드 11–15(`registry.trainSeeds.confirmatory`)에서 세 비교군을 모두 같은 설정으로 새로 학습한 뒤 한 번만 평가한다. 분석 단위는 학습 시드이고 M3 그래프 시드는 학습 시드와 같다. 이 결과를 보고 시드를 넣거나 빼지 않는다.

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
| 학습 시드 $s$ | 기본 1–5, v4 확장 1–10, v5 확인 11–15 | `rl.seed = 20240501 + s − 1` |

- 모든 환경 시드는 $10^6$ 미만이다. 같은 시드의 여러 난수열(시나리오·센서·잡음표·정책)은 $10^6$ 간격 오프셋을 쓰므로 서로 겹치지 않는다(`validatePrimaryConfig`).
- test·stress·고정 사례 시드는 체크포인트를 선택하지 않는다.

## 5. 평가 (`landing2d.orchestration.runEvaluation`)

모든 지표는 rollout이 끝난 뒤 평가 전용 참값으로 계산한다(`landing2d.evaluation.episodeMetrics`). 온톨로지 노드·attention·보상은 지표에 쓰지 않는다.

**추종 오차는 aim error** $e_{aim}=e_x-mh$, $m=\tan(-\theta_C)$다(`landing2d.evaluation.aimError`). $\theta_C=-30°$는 카메라 장착 피치이고, $m$은 공통 보상(`computeReward`, `REWARD_KO.md`의 $e_x^*=mh$)이 쓰는 기울기다. v2.2까지의 TOSM N3 특징 `normalizedCrossTrack`은 같은 $m$을 정규화 좌표에 적용해 $e_{aim}$과 같은 값이 아니었고, v2.3(`tosm7_v2`)에서 뺐다(`TOSM7_ONTOLOGY_KO.md`). 공통 보상이 추종하는 카메라 광축 기준점에서의 수평 오차이며, 착지 시 $e_x$와 같아진다. 고고도에서 $e_x\approx mh$($h=6$ m에서 3.46 m)는 설계된 접근 자세다. 그래서 $e_x$ 자체를 오차로 쓰지 않는다.

> **2026-10-18 수정.** 이전 평가 코드는 $e_x-h\tan\theta_C$로 계산해 부호가 반대였다(광축 기준점에서 0이 아니라 $2mh$). 그 이전에 생성된 `AimErrorRMS_m`, `WindowAimErrorRMS_m`, `WindowMaxAbsAimError_m`과 aim error 그림은 무효이며 재평가해야 한다. 학습·보상·관측은 이 오류와 무관하다.

에피소드별 추가 지표(`episodeMetrics`, 모두 평가 전용 참값):

| 지표 | 정의 |
|---|---|
| `RecoveryTime_s` | CA 에피소드. 가속 시작 $T_1$부터, 가속 구간이 끝난 뒤 $\lvert e_{aim}\rvert\le$ 0.5 m(접지 위치 허용치)가 1 s(`evaluation.tracking.hold`) 또는 에피소드 끝까지 유지되기 시작한 시각까지. 가속 구간 길이 $T_2$를 포함한다 |
| `TrackingReacquisition_s` | 누락 에피소드. 누락 후 첫 마커 측정 시각부터 같은 기준으로 추종이 회복될 때까지 (`ReacquisitionLatency_s`는 누락 끝 → 첫 측정) |
| `TouchdownPositionError_m`, `TouchdownRelativeSpeed_mps`, `TouchdownVerticalSpeed_mps` | 접촉 순간 $\lvert e_x\rvert$, $\lvert v_r\rvert$, $\lvert v_z\rvert$ (접촉 없으면 NaN) |
| `FailureClass` | `landing2d.evaluation.failureClasses`의 결정론적 규칙. 접촉 실패는 패드 밖 → 상대속도 → 수직속도 → 자세 순, timeout은 재획득 실패(누락 후 마커 미측정) → 시야 이탈(마지막 2 s 중 50% 이상 패드가 기하학적 시야 밖) → 추종 실패(마지막 2 s aim error RMS > 0.5 m) → 하강 미완료(hovering) 순 |

실패 분류는 `*_failureRuns.csv`(run별 비율)와 `*_failureSummary.csv`(시드 간)로 나온다. 성공률 숫자만이 아니라 실패가 어떤 상황에서 생겼는지 비교군별로 본다.

### 5.1 학습 효율 (`learningEfficiency`)

PPO 중 25 update마다 validation 100개 에피소드의 착륙률을 누적 환경 스텝(결정 수)에 대해 기록한다.

- `StepsTo50`, `StepsTo80`: 착륙률이 처음 50%, 80%에 도달한 스텝. 도달하지 못하면 예산 값으로 censor하고 `Reached = 0`으로 표시한다.
- `AUC`: 학습 곡선 아래 면적 ÷ 예산.
- `BestValidationSuccess`, `SelectedIteration`도 함께 기록한다.
- `LateGain`: plateau 확인. 마지막 20% 평가의 평균 착륙률 − 그 앞 20%의 평균. 0에 가까우면 예산 안에서 곡선이 평탄해졌고, 뚜렷한 양수면 아직 개선 중이다. "일반 PPO를 덜 학습시킨 것 아닌가"에 대한 답은 이 값과 학습 곡선으로 한다.
- 학습 곡선(`learning_curves.csv`)에는 PPO 갱신 진단(학습 창의 return·착륙률·에피소드 길이, actor surrogate 손실, critic MSE, 엔트로피, 근사 KL, clip 비율, actor/critic head·인코더의 clip 전 기울기 노름)도 들어간다. 2026-10-18 이후 학습한 run만 값이 있다. 진단 기록은 갱신을 바꾸지 않는다(리팩토링 전후 짧은 학습이 비트 단위로 같음을 확인).

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
- 사례별 비교군 차이(`factorial_caseContrasts.csv`)도 계산한다.
- **잡음에 의한 궤적 분산**(보조 지표). 한 사례의 반복 20회는 물리 시나리오·초기 상태가 같고 센서 잡음표만 다르다. run·사례마다 $V_{traj}=\frac1T\sum_t\mathrm{tr\,Cov}_{rep}[(x_d-x_p,\,z_d)(t)]$를 모든 반복이 비행 중인 결정 시점(`CommonHorizon_s`)에서 평균하고, 사건 구간만의 값도 낸다(`factorial_dispersion*.csv`). 과거 세미나의 "궤적 분산 99% 감소"와 같은 종류의 지표이므로, 위의 함께 읽는 규칙(§1) 없이 주장하지 않는다.

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
- **잡음 대비** (관측 교란 민감도): 속도 대비와 같은 결정 시점에서, 같은 물리 궤적을 명목 잡음표와 16개의 다른 잡음표(잡음 기준 시드 + $j\times10^7$, 다른 모든 난수열과 겹치지 않음)로 다시 재생한다. 물리 상태·누락 일정은 같고 관측만 $o'=o+\epsilon$ 경로(마커 검출 → PnP·KF)로 달라진다.
  - `NoiseActionVar` $=\mathrm{tr\,Cov}_j[a]$ [(m/s²)²]. 정책 잡음 민감도 $S_{noise}=\mathrm{tr}(J_\pi\Sigma_oJ_\pi^\top)$의 Monte Carlo 값이다. 선형화하지 않고, $\Sigma_o$는 센서·추정기 체인이 실제로 만드는 관측 공분산이다. `NoiseStdAx/Az`는 축별 표준편차.
  - 기준 구동기 값을 척도 기준으로 함께 보고한다. 작을수록 좋다고 단정하지 않는다(§1 함께 읽는 규칙).
- **attention**(`probes_attention*.csv`, 그림 `fig_attention`): 갱신 대비 입력에서 간선별 첫 층 Actor α의 평균. 기술 지표다.

### 5.6 학습 진단 (`trainingDiagnostics`)

체크포인트만으로 계산하므로 진단 기록 이전에 학습한 run에도 쓸 수 있다.

- **기울기 전달**: 학습된 정책에서, run 자신의 학습 에피소드 난수열의 첫 4개 에피소드(확률적 정책, PPO와 같은 advantage 정규화)로 공통 PPO actor 손실·critic 손실의 기울기를 구한다(`landing2d.rl.policyLossGradient`, `valueLossGradient`, PPO 갱신과 같은 함수). actor/critic 인코더 기울기 노름이 0이 아니면 PPO 손실 → MLP → graph embedding → R-GAT 경로가 실제로 기울기를 전달한다는 뜻이다.
- **파라미터 변화**: `landing2d.rl.initialAgent`로 PPO 시작점을 정확히 재구성해 $\lVert\theta_{final}-\theta_{init}\rVert$와 상대 변화를 인코더·head별로, 인코더는 파라미터 묶음(W1, a1, E1, W0, b0, Wc, Wn, bg)별로도 낸다(`training_parameters.csv`).
- **사용한 그래프**: run별 의미 간선 수, 관계 유형 및 연산군이 바뀐 간선 수·비율, 관계별 간선 수, 그래프 해시(`training_relations.csv`)와 간선별 TOSM/실제 관계·연산군(`training_edges.csv`).

논문에는 한 문장이면 된다: Actor와 Critic R-GAT 인코더가 PPO 학습 중 0이 아닌 기울기와 파라미터 갱신을 받았음을 확인했다.

## 6. 통계

- **분석 단위는 학습 시드(run)다.** 각 run을 에피소드·반복 평균으로 먼저 요약한다(`runMeans`). 그다음 학습 시드에 대해 평균, 표준편차, 95% t 구간, 중앙값·사분위수(type 7), 시드 수, 총 에피소드 수를 낸다(`seedSummary`).
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
- **2026-10-18 점검 결과: 통과하지 못함.** 일반 PPO(시드 1)는 쉬운 조건(CV·정상·속도 일치)에서도 착륙률 0%였다. 초기 위험 접촉 뒤 약 50 update부터 공중 정지 정책(timeout 100%, return −8.6)으로 수렴해 700 update 동안 벗어나지 못했다. 본 실험에서도 PPO는 시드 1–4에서 validation 0%였다. 따라서 R-GAT 계열 대 PPO의 차이는 현재 "표현의 효과"로 해석하지 않는다. 가능한 원인으로, R-GAT 입력에는 보상과 같은 기울기 $m$을 쓴 cross-track 특징(`normalizedCrossTrack`)과 착지 한계 비율이 파생 특징으로 들어가지만 일반 PPO는 포화 스케일된 관측에서 이런 결합을 직접 학습해야 한다는 점이 있다(검증 전 가설). 단 cross-track 특징은 정규화 좌표에서 계산되어 미터 단위 aim error $e_x-mh$와 같지 않고 광축 기준점에서도 0이 아니다($h=6$ m에서 0.29, 2026-10-19 확인, `VARIABLE_NAMING_AUDIT.md` F5). 그래서 "R-GAT가 aim error를 직접 입력으로 받는다"고 쓰지 않는다. 착지 한계 비율은 역정규화한 물리 값으로 계산하므로 접지 한계를 그대로 나타낸다. 관계 의미의 효과는 TOSM 대 Shuffled(같은 특징·같은 구조)로만 판단한다.
- `run`은 학습 서명이 맞는 체크포인트를 재사용한다. 중간에 멈춰도 다시 실행하면 이어서 진행한다. 모두 다시 학습하려면 `retrain = true`를 준다.

## 8. 출력

| 경로 | 내용 |
|---|---|
| `results/checkpoints/<method>_sNN[_gNN].mat` | agent, 학습 기록, 학습 서명, 실행 식별 |
| `results/evaluation/*.csv`, `results.mat` | 절별 에피소드 표, run 평균, 시드 요약, 비교군 대비, 실패 분류. `training_*`는 기울기·파라미터 변화·그래프. `results.mat`의 `factorial.display`는 표시 시드의 S1–S4 시계열(위치·속도·피치·명령·가시성·사건) |
| `results/figures/fig_*.png` | contrasts, learning, heldout, factorial, trajectories, timeseries(S4), generalization, probes, diagnostics, attention, training(진단이 기록된 run만) |

## 9. 코드 대응

| 내용 | 위치 |
|---|---|
| 시나리오 표본·초기 편차 | `+scenario/sampleParameters`, `+environment/reset` |
| 관측 요인 | `+sensing/sampleEvents` |
| 설정 | `+config/defaultPlanarVisibilityConfig`, `primaryConfig`, `defaultEvaluationConfig`, `methodRegistry`, `applyMethod` |
| PPO (공통) | `+rl/ppoTrain`, `trainAgent`, `loadOrTrainAgent` |
| R-GAT | `+graphstate/contextSchema`, `observationVectorGraph`, `encoderInit/Forward/Backward`, `+rgat/*` |
| 평가 | `+evaluation/*` (지표 `episodeMetrics`, `aimError`, `failureClasses`, `failureTable`; 학습 진단 `trainingDiagnostics`) |
| 기울기 (PPO와 진단 공통) | `+rl/policyLossGradient`, `valueLossGradient`, `initialAgent` |
| 실행 | `+orchestration/runPipeline`, `runCheck`, `runScenario`, `selfTest` |
| 그림 | `+viz/plotResults`, `plotTrajectories`, `plotCaseTimeSeries` |

## 10. 검토했지만 채택하지 않은 설계

| 제안 | 결정과 이유 |
|---|---|
| M3 관계 순열을 학습 시드와 분리된 고정 시드(예: 2026) 하나로 | 채택하지 않음. 그래프 시드 = 학습 시드로 두면 M3의 시드 간 평균이 특정 순열 하나가 아니라 순열들에 대한 평균이 된다. 고정 순열이 필요하면 `applyMethod(cfg,'shuffled_rgat_ppo',s,g)`로 지정할 수 있다 |
| S2에 잡음 수준 변화·측정 지연 포함 | 잡음 ×2는 학습 범위 밖이므로 §5.4 generalization에 둔다. 측정 지연은 환경 계약(관측 경로)을 바꾸므로 넣지 않는다. S2는 마커 누락만 바꾼다 |
| S3에 감속(CV → 감속 → CV) 포함 | 학습 분포의 가속도는 0.3–0.8 m/s²(양수)뿐이므로 감속은 학습 범위 밖이다. 통제 사례는 학습 범위 안이어야 한다 |
| 그래프 노드 7개·간선 16개(세미나 자료) | 현재 계약은 `tosm7_v1`(의미 13 + self 7 = 20 간선, 노드 구성도 다름, `TOSM7_ONTOLOGY_KO.md`) |
| 결과 폴더 `results/train/…`, `results/eval/S1…` | 기존 계약(`checkpoints/`, `evaluation/`, `figures/`)을 유지. 같은 내용은 CSV 이름으로 구분된다 |
| 상대 위치 RMSE를 $e_x$로 | $e_x$는 설계된 접근 오프셋 $mh$를 포함하므로 추종 오차가 아니다. aim error를 쓴다 |

## 참고문헌

- Battaglia et al. (2018), Relational inductive biases, deep learning, and graph networks.
- Busbridge et al. (2019), Relational Graph Attention Networks.
- Zambaldi et al. (2019), Deep Reinforcement Learning with Relational Inductive Biases, ICLR.
- Bechler-Speicher et al. (2024), Graph Neural Networks Use Graphs When They Shouldn't, ICML.
- Li, Walsh, Littman (2006), Towards a Unified Theory of State Abstraction for MDPs.
- Kaelbling, Littman, Cassandra (1998), Planning and acting in partially observable stochastic domains.
- Henderson et al. (2018), Deep Reinforcement Learning that Matters, AAAI.
- Agarwal et al. (2021), Deep Reinforcement Learning at the Edge of the Statistical Precipice, NeurIPS.
