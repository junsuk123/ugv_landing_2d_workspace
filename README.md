# UGV 착륙용 Causal Ontology R-GAT PPO

## 최종 결론

- 연구 대상: 가속 중인 이동 패드에 대한 2차원 드론 착륙
- 공통 조건: 환경·센서·보상·행동·안전 감독기·종료 조건 동일
- 비교 변수: Actor/Critic 상태 표현만 변경
- 비교군: 저수준 관측 MLP, semantic-flat MLP, ontology R-GAT PPO
- 최신 코드: `planar_visibility_v2`, 알고리즘 `planar-visibility-ppo-v2.8`
- 최신 통합 검증: MATLAB R2025b self-test 8/8·smoke pipeline·S3 scenario 통과
- 기본 진입점: `ugv_landing_2d_workspace/run.m`
- 보조 진입점: `run_scenario.m` 단일 시나리오 비교, `run_live.m` 세 비교군 실시간 lockstep 테스트
- 관계 경로: 검증 성능 가드 기반 비영 R-GAT readout 활성화
- 핵심 제한: 성능 보존 신뢰구간에 따른 relation scale 0.001
- 해석 범위: 관계 경로 활성 검증 완료·R-GAT 우월성 주장 제외

## 최신 결과

- 평가 갱신: 2026-10-06 09:31 KST (최신 코드·기존 체크포인트 재평가, 결과율 동일 재현)
- 성능 평가: 고정 test seed `3001:3100` 100개
- 논문 시나리오·그림: 최종 활성 R-GAT checkpoint 재실행
- 추론 시간: 동일 호스트(Intel i7-14700F) 단일 실행의 500회 반복 평균, packet·graph 구성 + Actor 순전파

### 100개 fresh test seed 평가

| 모델 | 성공률 | 위험 접촉률 | 안전 중단률 | 시간 초과율 | 평균 return | 파라미터 | 추론 시간 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Low-level MLP PPO | 74% | 2% | 23% | 1% | 19.139 | 7,445 | 0.105 ms |
| Semantic-flat MLP PPO | 75% | 9% | 13% | 3% | 18.496 | 15,317 | 0.115 ms |
| Ontology R-GAT PPO | 72% | 9% | 14% | 5% | 17.930 | 17,001 | 0.179 ms |

- 단일 학습 seed의 최종 체크포인트 평가
- 모델 선택에 사용하지 않은 test seed `3001:3100` 사용
- R-GAT 우월성 미확인
- 다중 학습 seed 평균·분산 검증 필요

### 고정 대표 시나리오 평가

| 시나리오 | Low-level | Semantic-flat | Ontology R-GAT | 안정성 지수 비교 |
|---|---|---|---|---|
| S1 정상 정렬 | 성공 | 비허가 접촉 | 성공 | 88.7 / 85.0 / **93.5** |
| S2 급가속 | 안전 중단 | 성공 | 성공 | 37.9 / **75.9** / 74.3 |
| S3 가시성 손실 | 안전 중단 | 성공 | 성공 | 47.6 / 70.8 / **80.6** |

- 사전 선언 시나리오 사용
- 모델별 동일 물리 조건·센서 이벤트·노이즈 seed 사용
- S1~S3 모두 양의 속도·가속도 authority margin 확인
- S3의 일시적 `LandingInhibit` 원인: sensor dropout

![대표 시나리오 착륙 궤적](ugv_landing_2d_workspace/docs/assets/paper/paper_trajectories.png)

![안정성 지표](ugv_landing_2d_workspace/docs/assets/paper/paper_stability.png)

### Monte Carlo 평균·분산 궤적

![Monte Carlo 평균·1시그마 궤적과 최종 평가](ugv_landing_2d_workspace/docs/assets/paper/planar_visibility_monte_carlo.png)

- 왼쪽 상단: 100개 test seed의 평균 궤적과 1시그마 공분산 윤곽
- 오른쪽 상단: 동일 test seed의 성공·위험·안전 중단·포착률
- 왼쪽 하단: 학습 중 validation return 궤적 (25 iteration 간격)
- 가운데 하단: packet·graph 구성과 Actor·Critic 순전파 합계 시간 (25회 반복)
- 오른쪽 하단: 최종 R-GAT 평균 relation attention

## 실험 설정

- 논문 표기용 설정 요약
- 출처: `defaultPlanarVisibilityConfig.m`, `primaryConfig.m`, `defaultRlConfig.m`, `defaultGraphStateConfig.m`
- 세 비교군 공통 적용: 상태 표현 외 전 항목 동일, task fingerprint 일치 검사

### 시뮬레이션 환경

| 항목 | 설정 |
|---|---|
| 시뮬레이터 | MATLAB R2025b 자체 구현 2D(x–z) 시뮬레이터, Simulink·외부 물리엔진 미사용 |
| 신경망·학습 | 자체 구현 MLP·R-GAT·PPO·Adam, Deep Learning Toolbox 미사용 |
| 병렬화 | 반복당 에피소드 수집 `parfor`, 에피소드별 사전 난수열로 직렬 실행과 동일 결과 |
| 물리 적분 주기 | 0.01 s (100 Hz) |
| 정책 결정 주기 | 0.10 s (10 Hz), 결정 사이 zero-order hold |
| 학습 호스트 | Intel Core i7-14700F (20코어), RAM 16 GB, Windows 11, Parallel Computing Toolbox |
| 학습 소요 시간 | Low-level 1.14 h, Semantic-flat 1.55 h, R-GAT 1.91 h (체크포인트 `info.trainingSeconds`) |
| 최대 임무 시간 | 70 s |
| 난수 생성기 | `threefry`, 시나리오·센서·정책 독립 스트림 (offset 0 / 1,000,000 / 2,000,000) |

### 드론 동역학

| 항목 | 값 |
|---|---|
| 모델 | 평면 pitch–thrust 모델, 가속도 명령 → pitch·추력 setpoint 변환 |
| 질량 / 중력 | 1.5 kg / 9.81 m/s² |
| 최대 추력중량비 | 1.6 |
| 추력 1차 지연 시정수 | 0.05 s |
| pitch 내부 루프 | 2차 응답, ωₙ = 10 rad/s, ζ = 1.0 |
| pitch / pitch rate 한계 | ±20° / ±90°/s |
| 행동 한계 | $a_{x,\max}$ = 2.5 m/s², $a_{z,\max}$ = 2.0 m/s² |
| 운용 고도 상한 | 지면 기준 25 m (world z, 초과 시 envelope violation) |

### UGV 이동 패드 시나리오

| 항목 | 분포·값 |
|---|---|
| 운동 구조 | 등속(CV) → 등가속(CA) → 등속(CV) 3구간 |
| 1구간 속도 $v_1$ | U[0.5, 2.5] m/s |
| 2구간 가속도 $a_2$ | U[0.3, 1.5] m/s² |
| 구간 지속시간 $T_1$, $T_2$ | U[0.5, 4] s, U[0.5, 4] s |
| 3구간 지속시간 $T_3$ | U[15, 55] s |
| 3구간 속도 | $v_3=v_1+a_2T_2$ (파생값) |
| 초기 상대 고도 | U[4, 8] m |
| 패드 높이 | 지면 기준 0.6 m |
| 기각 조건 | 마감시간 > 70 s 또는 $v_3$ > 9.5 m/s (지속 비행속도 10 m/s − margin 0.5 m/s) |
| 드론 초기 상태 | 패드 바로 위, 패드와 동일 수평속도, $v_z=0$, pitch 0 |

### 센서 구성과 데이터 주기

| 센서·신호 | 주기 | 특징 | 노이즈 |
|---|---|---|---|
| 하향 카메라 패드 검출 | 100 Hz (물리 스텝마다) | 기체 고정 하향 카메라, 전체 FOV 50°, 최대 거리 50 m, 기체 pitch에 따른 시야 회전 | 아래 별도 표 |
| 상대 수평 위치 $e_x$ | 100 Hz | 검출 시에만 유효, 미검출 시 valid=0 | 가우시안 백색잡음 σ = 0.02 m |
| 패드 bearing $\beta$ | 100 Hz | 카메라 광축 기준 각도 | 가우시안 백색잡음 σ = 0.15° |
| 검출 신뢰도 | 100 Hz | $\max(0.05,\,1-(\lvert\beta\rvert/(\mathrm{FOV}/2))^2)$, 시야 가장자리일수록 감소 | 잡음 bearing으로 계산 |
| 드론 자체 상태 (고도·속도·pitch·pitch rate) | 정책 10 Hz 입력 | 시뮬레이터 참값 사용 | 미적용 (이상적 own-state) |
| 정책 관측 패킷 | 10 Hz | 26차원 causal packet (own motion 6, pad track 8, visibility 7, task memory 5) | 추정기 출력 경유 |

- 패드 검출 조건: 카메라 깊이 > 0, 거리 ≤ 50 m, $\lvert\beta\rvert$ < 25°, dropout 비활성
- 오검출(false positive)·측정 지연: 미모델링
- 측정 timestamp: 생성 시점 기록·시간 역행 시 오류 처리

### 인지 알고리즘

| 항목 | 설정 |
|---|---|
| 검출 방식 | 영상 처리 없는 기하 투영 검출기 (패드 중심을 기체 고정 카메라 좌표로 투영) |
| 출력 | 검출 여부, 상대 수평 위치, bearing, 신뢰도, validity flag |
| 이상치 게이트 | 예측 위치 대비 innovation ≤ max(4σ, 0.25 m) 일 때만 채택 |
| 예측 bearing·FOV margin | 0.5 s 앞 상대 위치·pitch 외삽 후 재투영 |
| 온톨로지 의미화 | 관측 패킷 → 9노드 × 12특징 causal graph (`PadVisibility`, `ViewRecovery` 등) |

### 상태 추정 알고리즘

| 항목 | 설정 |
|---|---|
| 추정기 | 인과적 timestamp 기반 등가속도 α-β-γ 필터 (패드 위치·속도·가속도) |
| 측정 입력 | 유효 측정의 상대 위치 + 동기화된 드론 자체 위치 |
| 갱신 이득 | α = 0.20, β = 0.02, γ = 0.00005 |
| 가속도 추정 감쇠 | 시정수 1.5 s 지수 감쇠, ±3.0 m/s² 포화 |
| 공정 잡음 | 가속도 σ = 1.5 m/s² (불확실성 전파용) |
| 초기 불확실성 | 위치 2 m, 속도 3 m/s, 가속도 2 m/s² |
| 초기화 | 첫 유효 측정으로 위치 설정, 패드 속도 사전값 = 드론 수평속도 |
| 미검출 구간 | 등가속도 예측만 수행, 불확실성 증가, 미관측 시간 누적 |
| 참값 사용 | 미사용 (hidden pad truth는 보상 계산에만 사용) |

### 외란과 노이즈

| 종류 | 발생 확률 | 설정 |
|---|---|---|
| 측정 잡음 | 항상 | 상대 위치 σ = 0.02 m, bearing σ = 0.15° 가우시안 |
| 센서 dropout 없음 | 50% | 전 구간 정상 검출 (FOV 이탈 제외) |
| 짧은 dropout | 25% | 지속 U[0.2, 0.5] s, 시작 시각 U[0.5, 마감−5] s |
| 지속 dropout | 25% | 지속 U[3.5, 5.0] s, 시작 시각 U[0.5, 마감−5] s |
| pitch 외란 | 25% (dropout과 독립) | pitch rate 외란 U[−2, 2] °/s, 지속 U[0.15, 0.4] s, 시작 U[0.5, 마감−1] s |
| UGV 기동 | 항상 | CA 구간 가속 (시나리오 자체의 과제 외란) |
| 바람·돌풍·지면효과 | 미적용 | — |
| 드론 상태 센서 잡음 | 미적용 | — |

- 외란 일정: 정책 실행 전 센서 난수열로 사전 추출 (정책 행동과 독립)
- 비교군 간 동일 seed → 동일 시나리오·dropout·pitch 외란·측정 잡음 열

### 안전 감독기·종료 조건

| 항목 | 값 |
|---|---|
| 착륙 성공 | 접촉 높이 0.04 m, 수평 오차 ≤ 0.5 m, 상대 수평속도 ≤ 0.35 m/s, 수직속도 ≤ 0.30 m/s, pitch ≤ 5°, pitch rate ≤ 10°/s |
| 장기 시야 상실 | 3.0 s 초과 시 abort (복구 상승) 요청 |
| 최소 track 신뢰도 | 0.25 |
| 감독기 응답 지연 가정 | 0.15 s (정지거리 계산) |
| 복구 상승 한계 | 8.0 s |
| 종료 분류 | `SUCCESS`, `SAFE_ABORT`, `TASK_TIMEOUT`, `UNSAFE_CONTACT`, `UNAUTHORIZED_CONTACT`, `MISSED_PAD_CONTACT`, `SAFETY_ENVELOPE_VIOLATION` |
| 종료 보상 | +25 / −15 / −12 / −40 / −40 / −40 / −40 |

### PPO 학습 설정

| 항목 | 값 |
|---|---|
| 초기화 | 세 비교군 모두 무작위 초기화, 모방학습 미사용 |
| PPO 반복 수 | 2,500 iteration (조기 종료 없음) |
| 반복당 에피소드 | 6 |
| 모델당 학습 에피소드 | 15,000 |
| 반복당 업데이트 | 8 epoch, mini-batch 256 |
| 할인율 γ / GAE λ | $\exp(-0.1/70)\approx0.99857$ / 0.95 |
| clip ratio | 0.2 |
| 학습률 | policy 5×10⁻⁴, value 1×10⁻³, graph encoder 3×10⁻⁴ (Adam) |
| entropy 가중치 | 0.0025 |
| 탐색 log σ | 초기 −1.1, 하한 −2.5 |
| gradient clipping | L2 norm 1.0 |
| value warm-up | 처음 2 iteration value만 학습 |
| MLP 구조 | 은닉층 2개 × 48 |
| R-GAT 구조 | 노드 임베딩 8, 관계 임베딩 4, 4개 의미 그룹 readout |
| 관계 경로 적응 | 마지막 10% (2,251 iteration 이후), raw semantic 정책 고정 |
| 학습 seed | `rl.seed = 20240501`, 단일 학습 seed |
| 학습 에피소드 seed | PPO 난수열에서 추출한 int32 seed (validation·test seed와 별도 범위) |

### 커리큘럼 (학습 에피소드에만 적용)

| 항목 | 설정 |
|---|---|
| 방식 | 성능 기반 승급 (착륙률 ≥ 10%가 3개 평가창 연속 시 +0.1) + 일정 기반 하한 |
| 초기 고도 | 공칭 4–8 m의 0.025–0.05배(0.1–0.4 m)에서 시작해 공칭 범위로 확장 |
| UGV 운동 | 속도·가속도 범위 0.15배에서 시작, 전체 학습의 65% 지점까지 공칭 복귀 |
| 장기 시야 상실 한계 | 12 s에서 시작, 55% 지점까지 공칭 3 s로 복귀 |
| 착륙 속도 허용치 | 공칭의 2배에서 시작해 공칭으로 수렴 |
| 위험 접촉 보상 | −20에서 시작해 공칭 −40으로 수렴 |
| 공칭 난이도 보장 | 30%부터 하한 상승, 80% 이후 공칭 분포 위주 |
| 망각 방지 replay | 6개 배치 중 쉬운 에피소드 1개·중간 에피소드 1개 |
| 평가 분포 | 커리큘럼 미적용, 항상 공칭 분포 |

### 그래프 사전학습·관계 경로 보정 (R-GAT 전용)

| 항목 | 값 |
|---|---|
| 사전학습 목표 | masked same-time node feature reconstruction |
| 사전학습 데이터 | train seed `1:12`, 에피소드당 최대 80 decision |
| 사전학습 설정 | 8 epoch, batch 128, mask 확률 0.25, 학습률 1×10⁻³ |
| 관계 전용 PPO 보정 | 25 iteration × 6 에피소드, 4 epoch |
| relation scale 탐색 | {1, 0.75, 0.5, 0.25, 0.1, 0.05, 0.02, 0.01, 0.005, 0.002, 0.001} |
| 채택 조건 | validation 100 seed에서 성공률 비하락, 위험·중단·시간초과율 비증가 |
| 최종 선택 scale | 0.001 |

### 데이터 분할과 평가 횟수

| 구분 | Seed | 에피소드 수 (모델당) | 용도 |
|---|---|---:|---|
| 학습 | PPO 난수열 | 15,000 | 정책 학습 |
| 그래프 사전학습 | `1:12` | 12 | R-GAT encoder 사전학습 |
| Validation | `2001:2100` | 100 × 101회 | 학습 전 1회 + 25 iteration마다 checkpoint 선택 (공칭 커리큘럼 도달 후 checkpoint만 대상) |
| Test | `3001:3100` | 100 | 최종 성능 보고 (선택에 미사용) |
| 대표 시나리오 | S1–S3 고정 | 3 | 논문 궤적·안정성 그림 |
| 추론 시간 측정 | — | 500회 반복 | 정책 상태 구성 + Actor 순전파 (표), Actor+Critic 합계 별도 기록 |

- 평가 정책: 결정론적 (Gaussian 평균 행동)
- Monte Carlo 그림: test 100 seed와 동일 표본
- 학습 반복: 모델당 1회 (단일 학습 seed)

### 대표 시나리오 파라미터

| 시나리오 | $v_1$ [m/s] | $a_2$ [m/s²] | $T_1$ [s] | $T_2$ [s] | $T_3$ [s] | 초기 고도 [m] | 센서 이벤트 |
|---|---:|---:|---:|---:|---:|---:|---|
| S1 정상 정렬 | 1.50 | 0.60 | 2.00 | 1.50 | 28.0 | 6.0 | 없음 |
| S2 급가속 | 1.00 | 1.50 | 2.00 | 2.25 | 28.0 | 7.0 | 없음 |
| S3 가시성 손실 | 1.00 | 1.20 | 2.00 | 2.75 | 30.0 | 6.5 | dropout 4.2–5.0 s |

## 시스템 구조

![전체 파이프라인](ugv_landing_2d_workspace/docs/assets/pipeline.svg)

### 최종 소스 계층

```text
src/
├─ orchestration/  실행·설정·검증·저장·최소 시각화
├─ simulations/    환경·동역학·센서·시나리오·안전 감독기
└─ algorithms/     PPO·그래프 상태·온톨로지·R-GAT
```

- 루트 실행 파일: `run.m`, `run_scenario.m`, `run_live.m`
- MATLAB 소스: 133개
- 구 진입점·분산 테스트·중복 시각화·미사용 레거시 모듈 제거

### 온톨로지·R-GAT 전체 시각화

```matlab
addpath(fullfile(pwd,'src','orchestration'), ...
    fullfile(pwd,'src','simulations'),fullfile(pwd,'src','algorithms'))
view = landing2d.viz.ontologyRgatExplorer();
```

- 9개 노드·26개 간선·5개 관계형 전체 표시
- 12×9 특징 텐서와 4개 readout 그룹 표시
- 최종 체크포인트의 Actor/Critic attention·message·파라미터 표시

| 비교군 | Actor/Critic 입력 | 그래프 관계 사용 |
|---|---|---|
| Low-level MLP | 26필드 causal packet | 제외 |
| Semantic-flat MLP | 9노드 × 12특징 평탄화 벡터 | 제외 |
| Ontology R-GAT | 동일한 9노드 × 12특징 + typed relation context | 포함 설계 |

### 행동과 실행 주기

정규화 전 Gaussian 정책 명령:

$$
u_t \in \mathbb{R}^{2}
$$

환경 입력 가속도 명령:

$$
a_t=[a_x,a_z]^\top=\mathrm{diag}(a_{x,\max},a_{z,\max})\tanh(u_t)
$$

- 정책 주기: 0.10 s
- 물리 주기: 0.01 s
- 실시간 역전파: 제외
- 배포 시 계산: packet 구성, graph 구성, R-GAT 순전파, Actor/Critic 순전파

## 온톨로지 설계

![온톨로지 상황 그래프](ugv_landing_2d_workspace/docs/assets/ontology_graph.svg)

### 노드

| 그룹 | 노드 | 핵심 의미 |
|---|---|---|
| Perception | `PadVisibility` | 검출·bearing·FOV margin·confidence |
| Perception | `ViewRecovery` | 미관측 시간·예측 bearing·복구 긴급도 |
| Tracking | `PadMotion` | 패드 속도·가속도 추정·불확실성 |
| Tracking | `RelativeTracking` | 상대 위치·상대속도·추정 불확실성 |
| Tracking | `TrackingCorrection` | 방향 보존 수평 복구 문맥 |
| Vehicle | `DroneTranslation` | 고도·수평속도·수직속도 |
| Vehicle | `DroneAttitude` | pitch·pitch rate |
| Safety | `DescentEligibility` | 정렬·속도·자세·신뢰도 기반 하강 허용도 |
| Safety | `LandingInhibit` | 일시적 하강 금지·abort 상태 |

### 관계

- 의미 간선 17개
- 자기 간선 9개
- 전체 간선 26개
- 관계 유형: `informs`, `affects_visibility`, `supports`, `inhibits`, `self`
- 임의 역방향 간선 추가 제외
- 고립 노드 제외
- 보상·행동·성공 여부·미래 상태 노드 제외

### 노드 특징

각 노드 특징 $x_i\in\mathbb{R}^{12}$ 구성:

$$
x_i=[p_i,\tilde p_i,s_i,\tilde s_i,m_i,c_i,u_i,\tau_i,q_i,T_i,1,\kappa_i]^\top
$$

- $p_i,s_i$: 주요·보조 의미 크기
- $\tilde p_i,\tilde s_i$: 방향 보존 부호 특징
- $m_i$: 유효성 mask
- $c_i$: 신뢰도
- $u_i$: 불확실성
- $\tau_i$: 변화 추세
- $q_i$: 긴급도
- $T_i$: 잔여 임무시간
- $\kappa_i$: 노드 유형 식별자 $i/9$
- 전 특징 $[-1,1]$ clipping, $p_i\in[0,1]$

## 온톨로지의 강화학습 입력 방식

### Typed R-GAT message passing

관계 $r$을 갖는 간선 $i\rightarrow j$의 attention logit:

$$
e_{ij}^{(r)}=\mathrm{LeakyReLU}_{0.2}\!\left(
{a_r}^{\top}[W_r x_i\,\Vert\,W_r x_j\,\Vert\,E_r]
\right)
$$

- $W_r\in\mathbb{R}^{8\times12}$, $E_r\in\mathbb{R}^{4}$, $a_r\in\mathbb{R}^{20}$
- 단일 R-GAT 층

목적 노드 기준 정규화(전 관계 유형·자기 간선 포함 incoming 간선 전체)와 노드 갱신:

$$
\alpha_{ij}^{(r)}=
\frac{\exp(e_{ij}^{(r)})}
{\sum_{(k,r')\in\mathcal{N}(j)}\exp(e_{kj}^{(r')})+10^{-9}},
\qquad
h_j=\tanh\!\left(\sum_{(i,r)\in\mathcal{N}(j)}
\alpha_{ij}^{(r)}W_r x_i+W_0x_j+b_0\right)
$$

4개 의미 그룹 readout ($\bar h$: 그룹 내 노드 평균, $W_g\in\mathbb{R}^{4\times32}$, 0 초기화):

$$
c_t=\tanh\!\left(W_g\,
[\bar h_{\mathrm{perception}}\Vert
\bar h_{\mathrm{tracking}}\Vert
\bar h_{\mathrm{vehicle}}\Vert
\bar h_{\mathrm{safety}}]+b_g\right)
$$

### Actor/Critic 결합

Raw semantic bypass $s_t=\mathrm{vec}(X_t)\in\mathbb{R}^{108}$ 보존:

$$
\mu_t=f_{\pi}(s_t)+\tilde\delta_t,
\qquad
\delta_t=W_{\pi}c_t,\quad W_\pi\in\mathbb{R}^{2\times4}
$$

추가 하강 residual의 의미 제약:

$$
\tilde\delta_{z,t}=
\begin{cases}
\delta_{z,t}, & \delta_{z,t}\ge 0,\\
E_t\delta_{z,t}, & \delta_{z,t}<0,
\end{cases}
\qquad E_t\in[0,1]
$$

Critic 결합:

$$
V_t=f_V(s_t)+w_V^{\top}c_t
$$

- $E_t$: `DescentEligibility` 노드의 primary 특징, $[0,1]$ clipping, gradient 미전달
- $E_t$ 구성: 신뢰도 × track 초기화 × (1−위치 위험)(1−속도 위험)(1−자세 위험)(1−각속도 위험) × ¬`landingInhibited`
- 공개 `landingInhibited` 플래그 활성 시 $E_t=0$, 추가 하강 residual 차단
- 상승·제동 residual과 수평 residual $\tilde\delta_{x,t}=\delta_{x,t}$ 유지
- Actor·Critic encoder: 사전학습 encoder 복사 후 독립 파라미터
- PPO 중 고정: $E_r$, $W_0$, $b_0$ / 적응: $W_r$, $a_r$, $W_g$, $b_g$
- Critic gate 없음, $w_V\in\mathbb{R}^4$

## 사전학습과 PPO 학습

- 사전학습 데이터: train seed의 현재 시점 causal graph
- 목표: masked same-time node feature reconstruction
- 입력 제외: 행동, 보상, 성공/실패, 미래 상태, 교사 명령, hidden pad truth
- PPO 초기 90%: raw semantic base 정책 학습
- PPO 마지막 10%: base 고정 후 관계 residual 미세조정
- checkpoint 선택: 100 validation seed와 안전 가중 점수 사용
- 비활성 checkpoint 복구: raw 정책 고정·관계 전용 PPO 25 iteration × 6 episode
- 성능 가드: 성공률 비하락·위험/중단/시간초과율 비증가·residual trust region
- test split: checkpoint 선택에서 제외

## 최종 체크포인트 구조 감사

| 항목 | Policy | Value |
|---|---:|---:|
| Graph readout norm $\lVert W_g\rVert_F$ | 0.0001665 | 0.0006056 |
| Relation head norm | 0.1517 | 0.4792 |
| 관계 경로 활성 | 예 | 예 |

- 원인 해결: flat-equivalent anchor 보존 후 관계 파라미터만 미세조정
- 검증 선택: test 미사용 100개 validation seed의 성능 가드
- test 결과율: 성공 72%·위험 접촉 9%·안전 중단 14%·시간초과 5% 유지
- test 평균 return: 17.873에서 17.930으로 증가
- test 평균 절대 행동 residual: 수평 $1.27\times10^{-5}$·수직 $3.86\times10^{-5}$
- 제한: 안전 보존을 위한 작은 관계 residual·다중 학습 seed 우월성 미확인

![온톨로지 정책 추적 및 관계 경로 감사](ugv_landing_2d_workspace/docs/assets/paper/paper_ontology.png)

## 착륙 가능성과 LandingInhibit

- 물리적 착륙 가능성: 정책 독립 authority margin 평가
- 속도 margin: $m_v=(v_{\mathrm{drone,sustain}}-m_{\mathrm{reserve}})-v_{\mathrm{pad,peak}}$
- 가속도 margin: $m_a=a_{x,\max}-a_{\mathrm{pad}}$
- 시간 margin: $m_T=T_{\max}-T_{\mathrm{deadline}}$
- 물리 가능 조건: $m_v\ge0$, $m_a>0$, $m_T\ge0$
- `LandingInhibit`: 영구적 착륙 불가능 판정이 아닌 현재 시점 하강 금지
- 원인 분해: sensor dropout, trajectory/FOV, relative speed, uncertainty/gate

![착륙 가능성과 하강 금지 원인](ugv_landing_2d_workspace/docs/assets/paper/paper_feasibility.png)

## 실행

```matlab
cd ugv_landing_2d_workspace   % 저장소 루트 기준 프로젝트 폴더(run.m 위치)
run
```

기본 실행 범위:

- 최종 계약 self-test
- 세 모델 scratch PPO 학습
- validation checkpoint 선택
- held-out test 100 seed 평가
- Monte Carlo·논문 그림 저장
- 옵션: `executionMode`(기본 `'full'`, `'smoke'`), `retrain`·`runSelfTest`·`generatePaper`·`figureVisible`·`saveResults`·`showLiveDashboard`(기본 `true`), `profileRepetitions`(기본 500), `trainingOptions`

저장 checkpoint 재사용:

```matlab
run(struct('retrain',false))
```

빠른 smoke 검사:

```matlab
run(struct('executionMode','smoke','generatePaper',false, ...
    'figureVisible',false,'saveResults',false,'showLiveDashboard',false))
```

특정 시나리오:

```matlab
run_scenario('S1')
run_scenario('S2')
run_scenario('S3')
```

- 저장 checkpoint 기반 궤적 그림만 생성, 학습 없음
- 옵션: `figureVisible`(기본 `true`), `saveResults`(기본 `false`, 활성 시 `results/scenario/`), `profileRepetitions`(기본 100)

실시간 세 비교군 테스트:

```matlab
run_live            % S3 가시성 손실·재포착
run_live('S2')      % 고정 대표 시나리오 S1·S2·S3
run_live(3001)      % held-out test seed
run_live('S1',struct('playbackSpeed',4))                   % 4배속
run_live('S3',struct('videoFile','results/live_s3.mp4'))   % MP4 저장
```

- 저장 checkpoint 3개 로드, 학습 없음
- 동일 시나리오·센서 dropout·pitch 외란·측정 잡음 열을 세 에이전트에 동시 적용
- 정책 주기 10 Hz lockstep 진행, 결정론적 행동
- 왼쪽: 비교군별 드론·UGV·패드·카메라 FOV·궤적 (FOV 초록=검출, 빨강=미검출)
- 오른쪽: 수평 오차·패드 상대 고도·드론/UGV 수평 속도 시계열 (주황=UGV 가속 구간, 빨강=dropout)
- 종료 후 전체 궤적 보기로 전환, 결과 표는 workspace 변수 `landingLive`
- 옵션: `playbackSpeed`(기본 1, `Inf`=대기 없음), `viewHalfWidth`(기본 15 m), `videoFile`, `checkpointDir`, `showFullTrajectoryAtEnd`

산출물 위치: `ugv_landing_2d_workspace/results/`

- `ppo_{baseline,context_flat,context_rgat}_planar_visibility_v2.mat`: 최종 checkpoint 3개
- `planar_visibility_full_summary.csv`: test 성능·파라미터·추론 시간 요약 (smoke 모드: `planar_visibility_smoke_summary.csv`)
- `planar_visibility_full.mat`: 비교 구조체·요약 표·설정 (smoke 모드: `planar_visibility_smoke.mat`)
- `reward_audit_v2.csv`: 공통 보상 감사
- `planar_visibility_monte_carlo.png`: Monte Carlo 요약 그림

`results/paper/`:

- `paper_trajectories.png`: 대표 시나리오 궤적
- `paper_stability.png`: 안정성 지표
- `paper_feasibility.png`: 물리 가능성·하강 금지 원인
- `paper_ontology.png`: 온톨로지 신호·관계 residual 감사
- `paper_stability_metrics.csv`: 안정성 수치 원본
- `paper_scenario_feasibility.csv`: 시나리오 authority margin
- `paper_runtime_profile.csv`: 정책·Actor/Critic 추론 프로파일
- `paper_architecture_audit.csv`: 관계 경로 활성 여부
- `paper_validation.mat`: 논문 검증 구조체

문서용 사본: `ugv_landing_2d_workspace/docs/assets/paper/` (PNG), `ugv_landing_2d_workspace/docs/assets/paper/data/` (CSV·`latest_document_summary.csv`)

## 최종 문서

- [최종 구현·결과 보고](ugv_landing_2d_workspace/docs/refactor/FINAL_REPORT.md)
- [시스템 명세](ugv_landing_2d_workspace/docs/refactor/SYSTEM_SPEC.md)
- [온톨로지·R-GAT 상태 설계](ugv_landing_2d_workspace/docs/ONTOLOGY_GRAPH_STATE_KO.md)
- [보상 함수 근거](ugv_landing_2d_workspace/docs/refactor/REWARD_RATIONALE.md)
- [설정·데이터 계약](ugv_landing_2d_workspace/docs/refactor/CONFIGURATION.md)
- [검증 범위와 결과](ugv_landing_2d_workspace/docs/VALIDATION_KO.md)
- [모듈 지도](ugv_landing_2d_workspace/docs/MODULE_MAP_KO.md)
- [온톨로지 시각화 안내](ugv_landing_2d_workspace/docs/ONTOLOGY_VIEW_KO.md)
- [문서 색인](ugv_landing_2d_workspace/docs/README.md)

## 제한

- 2차원 연구용 시뮬레이터
- 이상적 own-state 관측 사용
- 바람·돌풍·지면효과 외란 미적용
- 패드 검출 오검출·측정 지연 미모델링
- 실제 비행 안전성 인증 제외
- 단일 학습 seed 최종 결과
- R-GAT 관계 residual의 작은 신뢰구간
- 보편적 우월성 주장 제외
