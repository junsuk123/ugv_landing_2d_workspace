# 최종 설정과 데이터 계약

## 버전

| 계약 | 값 |
|---|---|
| 실험 | `planar_visibility_v2` |
| 환경 | `environment_v2` |
| 관측 | `causal_packet_v2` |
| 그래프 | `compact_context_graph_v3_grouped` |
| 정책 알고리즘 | `planar-visibility-ppo-v2.8` |
| 논문 검증 | `paper_validation_v1` |

- 설정 원본: `landing2d.config.primaryConfig` → `defaultPlanarVisibilityConfig`
- 정책 호환성: `trainingSignature` 완전 일치 요구
- 구버전 checkpoint 자동 거부
- 보상·환경·그래프 설정 변경 시 재학습 요구

## `run.m` 기본값

| 옵션 | 기본값 | 의미 |
|---|---|---|
| `executionMode` | `full` | validation·test 각 100 episode (`smoke`: 1반복 통합 검사) |
| `retrain` | `true` | 세 모델 scratch PPO 재학습 |
| `runSelfTest` | `true` | 최종 계약 검사 8개 선행 |
| `generatePaper` | `true` | 대표 시나리오 검증·PNG 생성 |
| `figureVisible` | `true` | 학습·평가 figure 표시 |
| `saveResults` | `true` | checkpoint·MAT·CSV·PNG 저장 |
| `showLiveDashboard` | `true` | 실시간 학습 상태 표시 |
| `profileRepetitions` | 500 | 정책·Actor/Critic 실행시간 반복 측정 |
| `trainingOptions` | `struct()` | `trainEvaluate` 전달 옵션 (`modes`, `ppoIterations`, `rlSeed` 등) |

- `run`: 처음부터 전체 과정 실행
- `run(struct('retrain',false))`: 최종 checkpoint 재사용
- `run_scenario('S1'|'S2'|'S3')`: 단일 대표 시나리오 실행 (기본 `saveResults=false`, `profileRepetitions=100`)
- `run_live(target,options)`: 세 checkpoint 실시간 lockstep 비교, 학습 없음

`run_live` 옵션:

| 옵션 | 기본값 | 의미 |
|---|---|---|
| `target` | `'S3'` | `'S1'`·`'S2'`·`'S3'` 또는 정수 manifest seed (예: 3001) |
| `playbackSpeed` | 1 | 실시간 배속, `Inf`는 대기 없음 |
| `checkpointDir` | `results/` | checkpoint 위치 |
| `videoFile` | `''` | MPEG-4 녹화 파일 |
| `showFullTrajectoryAtEnd` | `true` | 종료 후 전체 궤적 표시 |
| `viewHalfWidth` | 15 | 표시 창 반폭 [m] |

- 동일 scenario·sensor event·측정 잡음 stream 공유
- 결정론적 정책 행동
- `taskFingerprint` 일치 검사

## 시간·동역학

| 항목 | 값 |
|---|---:|
| 물리 주기 | 0.01 s |
| 정책 주기 | 0.10 s |
| 최대 임무시간 | 70 s |
| 질량 | 1.5 kg |
| 중력 | 9.81 m/s² |
| pitch 제한 | 20 deg |
| pitch-rate 제한 | 90 deg/s |
| pitch 고유진동수·감쇠비 | 10 rad/s, 1.0 |
| thrust 시정수 | 0.05 s |
| 최대 추력/중량비 | 1.6 |
| $a_{x,\max}$ | 2.5 m/s² |
| $a_{z,\max}$ | 2.0 m/s² |

## 시나리오 분포

| 독립 변수 | 범위 |
|---|---:|
| $v_1$ | 0.5–2.5 m/s |
| $a_2$ | 0.3–1.5 m/s² |
| $T_1$ | 0.5–4.0 s |
| $T_2$ | 0.5–4.0 s |
| $T_3$ | 15–55 s |
| 초기 고도 (패드 기준) | 4–8 m |

- 패드 표면 높이 0.6 m, 패드 반길이 0.5 m
- 시나리오 seed: `baseSeed` 20261002 + manifest seed
- sensor stream: 시나리오 seed + 1,000,000

종속 변수:

$$
v_3=v_1+a_2T_2
$$

샘플 허용 조건 (최대 1000회 재표본):

$$
v_3\le10-0.5=9.5\ \mathrm{m/s}
$$

$$
T_1+T_2+T_3\le70\ \mathrm{s}
$$

## Seed 분할

| 분할 | 선언 seed | 사용 | 용도 |
|---|---|---|---|
| train | 1:2000 | 1:12 | causal graph 사전학습 |
| validation | 2001:2200 | 2001:2100 (100개) | checkpoint 선택 |
| test | 3001:3200 | 3001:3100 (100개) | 최종 보고 |
| stress | 9001:9200 | 미사용 | 분할 중복 검사용 예약 |

- PPO 학습 episode seed: `RandStream('threefry', rl.seed+404)` 추출 정수 (manifest train 분할 미사용)
- `rl.seed` = 20240501
- 분할 중복 제외 (`validatePrimaryConfig`)
- test 기반 checkpoint 선택 제외
- 논문 대표 시나리오 seed `41001:41003`

## 센서

| 항목 | 값 |
|---|---:|
| 검출 주기 | 0.01 s (100 Hz) |
| FOV | 50 deg |
| 최대 거리 | 50 m |
| bearing noise | 0.15 deg 표준편차 |
| 상대위치 noise | 0.02 m 표준편차 |
| 검출 신뢰도 하한 | 0.05 |
| own-state noise | 없음 |
| 추정기 이득 $\alpha/\beta/\gamma$ | 0.20 / 0.02 / 0.00005 |
| 가속도 추정 포화 | 3.0 m/s² |
| 가속도 추정 감쇠 시정수 | 1.5 s |
| 추정 process acceleration | 1.5 m/s² 표준편차 |
| 재검출 innovation gate | 4σ (최소 0.25 m) |
| 초기 위치·속도·가속도 std | 2 m, 3 m/s, 2 m/s² |
| 예측 horizon | 0.5 s |

Perturbation 구성:

- clean 50%
- short dropout 25% (0.2–0.5 s)
- sustained dropout 25% (3.5–5.0 s)
- dropout 시작 시각: 0.5 s–max(0.5, deadline−5 s) 균등
- pitch-rate event 확률 25% (±2 deg/s 균등, 0.15–0.4 s, dropout과 독립)

## 26필드 관측 packet

| 그룹 | 필드 |
|---|---|
| `own_motion` | `h`, `vx`, `vz`, `sinTheta`, `cosTheta`, `pitchRate` |
| `pad_track` | `exEstimate`, `relativeVxEstimate`, `padVxEstimate`, `padAxEstimate`, `positionStd`, `velocityStd`, `accelerationStd`, `trackInitialized` |
| `visibility` | `detected`, `measuredBearing`, `bearingValid`, `detectionConfidence`, `timeSinceLastDetection`, `predictedBearing`, `predictedFovMargin` |
| `task_memory` | `remainingMissionTime`, `previousNormalizedActionX`, `previousNormalizedActionZ`, `landingInhibited`, `abortRequested` |

규칙:

- 차원 수의 코드 중복 선언 제외
- `observationSchema` 기반 자동 산출
- 부호 정보 보존
- missing value 0 대체 시 validity mask 동반
- hidden truth 대체값 사용 제외
- `remainingMissionTime`: 시나리오 deadline 기준

## 그래프 설정

| 항목 | 값 |
|---|---:|
| 노드 | 9 |
| 노드 특징 | 12 |
| raw semantic 차원 | 108 |
| 의미 간선 | 17 |
| 자기 간선 | 9 |
| relation type | 5 |
| hidden dimension | 8 |
| relation embedding | 4 |
| relation context | 4 |
| message-passing layer | 1 |
| readout | `raw_plus_groups` |

Readout 그룹:

- Perception
- Tracking
- Vehicle
- Safety

Causal 사전학습 (R-GAT 전용):

| 항목 | 값 |
|---|---:|
| 목적 | masked 동시각 노드 재구성 |
| episode | 12 (train seed 1:12) |
| episode당 최대 결정 | 80 |
| epoch | 8 |
| batch | 128 |
| mask 확률 | 0.25 |
| 학습률 | $10^{-3}$ |
| PPO 중 정적 backbone | 고정 |

## 학습 설정

| 항목 | 값 |
|---|---:|
| PPO 반복 | 2,500 |
| episode/반복 | 6 |
| PPO epoch | 8 |
| minibatch | 256 |
| clip ratio | 0.2 |
| GAE $\lambda$ | 0.95 |
| $\gamma$ | $e^{-0.1/70}\approx0.99857$ |
| policy 학습률 | $5\times10^{-4}$ |
| value 학습률 | $10^{-3}$ |
| graph encoder 학습률 | $3\times10^{-4}$ |
| entropy 가중치 | 0.0025 |
| 초기 log std | -1.1 |
| minimum log standard deviation | -2.5 |
| gradient norm 상한 | 1.0 |
| value warm-up | 2 반복 |
| 은닉층 | 48×2 |
| validation 평가 주기 | 25 반복 |
| 모방학습 | 제외 |
| graph adaptation 시작 | 전체 반복의 90% 이후 |
| graph selection margin | 5.0 |
| validation episode | 100 |
| test episode | 100 |

Checkpoint selection score (validation):

$$
S=1000\,p_{succ}-2500\,p_{unsafe}-10\,p_{timeout}-100\,p_{abort}+\bar R
$$

- 선택 후보: curriculum level 1.0 도달 이후 평가만

관계 경로 안전 활성화:

| 항목 | 값 |
|---|---:|
| raw Actor/Critic 갱신 | 제외 |
| 관계 전용 PPO 반복 | 25 |
| 관계 전용 PPO episode/반복 | 6 |
| 관계 전용 PPO epoch | 4 |
| 내부 학습 평가 seed | validation 20개 |
| 최종 성능 가드 seed | validation 100개 |
| residual norm 하한 | $10^{-6}$ |
| residual norm 상한 | 0.005 |
| scale 탐색 격자 | 1 → 0.001 (11단계, 첫 통과 채택) |
| 선택 scale | 0.001 |

- 성공률 하락 불허
- 위험 접촉·안전 중단·시간초과율 증가 불허
- 평균 return·selection score 허용 감소 각각 0.25
- test seed 기반 scale 선택 제외

Curriculum (학습 episode 전용):

- 모드: `performance` (25반복 학습창의 현재 난도 성공률 ≥ 10%, 3창 연속 시 level +0.10)
- 강제 하한: 전체 반복 30%까지 0, 80%에서 1.0 도달
- 초기 고도 배율 0.025–0.05 (0.1–0.4 m) → 명목 4–8 m
- 초기 pad motion scale 0.15 → 1.0 ($v_1$, $a_2$ 범위 배율)
- 초기 $T_1$ 0.1–0.3 s → 0.5–4.0 s
- prolonged loss 12 s → 3 s
- touchdown 속도 한계 2배 → 1배
- 위험 접촉 계열 보상 -20 → -40
- easy replay 1/6
- bridge replay 1/6
- 명목 evaluation 설정 불변

## 안전 설정

| 항목 | 값 |
|---|---:|
| recent track grace | 0.5 s |
| prolonged loss | 3.0 s |
| minimum confidence | 0.25 |
| touchdown height | 0.04 m |
| touchdown 수평 허용 (패드 반길이) | 0.5 m |
| touchdown relative speed | 0.35 m/s |
| touchdown vertical speed | 0.30 m/s |
| touchdown pitch | 5 deg |
| touchdown pitch rate | 10 deg/s |
| ceiling | world z 25 m (지면 기준) |
| minimum height | 0 m |
| abort hold height | 1.0 m |
| abort vertical speed tolerance | 0.10 m/s |
| 감독기 반응 지연 | 0.15 s |
| backup duration | 8 s |

## 보상 설정

| 항목 | 값 |
|---|---:|
| reference time·discount 시정수 | 70 s |
| goal 길이 $x$ / $h$ | 3 m / 4 m |
| goal 수평 비중 | 0.65 |
| goal·view·control 가중치 | 2.0 / 1.0 / 0.25 |
| readiness 가중치·기준 고도 | 8.0 / 1.0 m |
| potential 가중치 | 2.0 |
| `SUCCESS` | +25 |
| `SAFE_ABORT` | -15 |
| `TASK_TIMEOUT` | -12 |
| `UNSAFE_CONTACT`·`UNAUTHORIZED_CONTACT`·`MISSED_PAD_CONTACT`·`SAFETY_ENVELOPE_VIOLATION` | -40 |

## Checkpoint 파일

| 모델 | 파일 |
|---|---|
| Baseline | `results/ppo_baseline_planar_visibility_v2.mat` |
| Semantic-flat | `results/ppo_context_flat_planar_visibility_v2.mat` |
| Ontology R-GAT | `results/ppo_context_rgat_planar_visibility_v2.mat` |

## 논문 시각화 설정

| 시나리오 | $v_1$ | $a_2$ | $T_1$ | $T_2$ | $T_3$ | $v_3$ | 고도 | 센서 이벤트 |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| S1 | 1.5 | 0.6 | 2.0 | 1.5 | 28.0 | 2.4 | 6.0 | clean |
| S2 | 1.0 | 1.5 | 2.0 | 2.25 | 28.0 | 4.375 | 7.0 | clean |
| S3 | 1.0 | 1.2 | 2.0 | 2.75 | 30.0 | 4.3 | 6.5 | 0.8 s short dropout (4.2–5.0 s) |

- 모델 성능 확인 전 고정된 시나리오 값
- 시나리오별 공통 seed 사용
- 결과 기반 seed 선택 제외
