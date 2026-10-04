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

- 정책 호환성: `trainingSignature` 완전 일치 요구
- 구버전 checkpoint 자동 거부
- 보상·환경·그래프 설정 변경 시 재학습 요구

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
| 초기 고도 | 4–8 m |

종속 변수:

$$
v_3=v_1+a_2T_2
$$

샘플 허용 조건:

$$
v_3\le10-0.5=9.5\ \mathrm{m/s}
$$

$$
T_1+T_2+T_3\le70\ \mathrm{s}
$$

## Seed 분할

| 분할 | seed | 용도 |
|---|---|---|
| train | 1:2000 | PPO·causal graph 사전학습 |
| validation | 2001:2200 | checkpoint 선택 |
| test | 3001:3200 | 최종 보고 |
| stress | 9001:9200 | 별도 스트레스 평가 |

- 분할 중복 제외
- test 기반 checkpoint 선택 제외
- 논문 대표 시나리오 seed `41001:41003`

## 센서

| 항목 | 값 |
|---|---:|
| FOV | 50 deg |
| 최대 거리 | 50 m |
| bearing noise | 0.15 deg 표준편차 |
| 상대위치 noise | 0.02 m 표준편차 |
| 추정 process acceleration | 1.5 m/s² 표준편차 |
| 예측 horizon | 0.5 s |

Perturbation 구성:

- clean 50%
- short dropout 25%
- sustained dropout 25%
- pitch event 확률 25%

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

## 학습 설정

| 항목 | 값 |
|---|---:|
| PPO 반복 | 2,500 |
| episode/반복 | 6 |
| 모방학습 | 제외 |
| minimum log standard deviation | -2.5 |
| graph adaptation 시작 | 전체 반복의 90% 이후 |
| graph selection margin | 5.0 |
| validation episode | 100 |
| test episode | 100 |

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
| 선택 scale | 0.001 |

- 성공률 하락 불허
- 위험 접촉·안전 중단·시간초과율 증가 불허
- 평균 return·selection score 허용 감소 각각 0.25
- test seed 기반 scale 선택 제외

Curriculum:

- 초기 고도 범위 0.025–1.0 m
- 명목 고도 4–8 m로 확장
- 초기 pad motion scale 0.15
- 전체 motion 1.0으로 확장
- easy replay 1/6
- bridge replay 1/6
- 전체 난도 강제 도달 80% 지점
- 명목 evaluation 설정 불변

## 안전 설정

| 항목 | 값 |
|---|---:|
| recent track grace | 0.5 s |
| prolonged loss | 3.0 s |
| minimum confidence | 0.25 |
| touchdown height | 0.04 m |
| touchdown position tolerance | 0.5 m |
| touchdown relative speed | 0.35 m/s |
| touchdown vertical speed | 0.30 m/s |
| touchdown pitch | 5 deg |
| touchdown pitch rate | 10 deg/s |
| ceiling | 25 m |
| backup duration | 8 s |

## Checkpoint 파일

| 모델 | 파일 |
|---|---|
| Baseline | `results/ppo_baseline_planar_visibility_v2.mat` |
| Semantic-flat | `results/ppo_context_flat_planar_visibility_v2.mat` |
| Ontology R-GAT | `results/ppo_context_rgat_planar_visibility_v2.mat` |

## 논문 시각화 설정

| 시나리오 | $v_1$ | $a_2$ | $T_2$ | $v_3$ | 고도 | 센서 이벤트 |
|---|---:|---:|---:|---:|---:|---|
| S1 | 1.5 | 0.6 | 1.5 | 2.4 | 6.0 | clean |
| S2 | 1.0 | 1.5 | 2.25 | 4.375 | 7.0 | clean |
| S3 | 1.0 | 1.2 | 2.75 | 4.3 | 6.5 | 0.8 s dropout |

- 모델 성능 확인 전 고정된 시나리오 값
- 시나리오별 공통 seed 사용
- 결과 기반 seed 선택 제외
