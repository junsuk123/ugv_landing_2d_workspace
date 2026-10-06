# UGV Landing 2D 최종 구현·결과 보고

## 최종 판정

- `planar_visibility_v2` 연구 파이프라인 완성
- baseline·semantic-flat·ontology R-GAT의 공통 문제 계약 확정
- 9노드·26간선 causal ontology graph 구현
- raw semantic bypass + relation residual Actor/Critic 구현
- causal masked reconstruction 사전학습 구현
- scratch PPO 2,500 iteration × 6 episode 최종 checkpoint 생성
- fresh test 100 seed 평가 완료
- 논문용 고정 3시나리오·안정성·가능성 시각화 완료
- MATLAB R2025b 최종 계약 self-test 8/8 통과
- 세 모델 smoke pipeline·S3 단일 시나리오 통과
- 최신 R-GAT checkpoint relation readout 활성 확인
- 활성화 전후 test 결과율 동일 확인
- 최종 그림·CSV 갱신: 2026-10-06 09:31 KST
- 활성 R-GAT 성능 우월성 주장 제외

## 연구 질문

핵심 질문:

- 동일 sensor data에서 상태 표현 구조만 변경한 PPO의 행동 차이
- semantic feature 추가 효과와 typed relation 효과의 분리
- 가시성 손실·패드 가속 상황의 안정성 차이
- causal ontology의 실시간 추론 가능성
- hidden truth 누수 없는 graph policy 구성 가능성

## 비교군

| 모델 | 정책 입력 | 목적 |
|---|---|---|
| Low-level MLP PPO | normalized 26-field packet | 저수준 상태 기준 |
| Semantic-flat MLP PPO | flattened $12\times9$ semantic tensor | 의미 정보 효과 |
| Ontology R-GAT PPO | 동일 tensor + typed relation context | 관계 구조 효과 |

공통 조건:

- 동일 환경
- 동일 CV–CA–CV scenario distribution
- 동일 sensor·noise·dropout contract
- 동일 action $[a_x,a_z]$
- 동일 safety supervisor
- 동일 reward
- 동일 terminal rule
- 동일 PPO budget
- 모방학습 제외

## 시스템 구조

![전체 파이프라인](../assets/pipeline.svg)

데이터 흐름:

```text
camera + own-state
→ causal observation memory
→ 26-field packet
→ baseline vector 또는 9-node ontology graph
→ Actor/Critic
→ Gaussian raw action
→ tanh·acceleration scaling
→ common safety supervisor
→ pitch/thrust dynamics
→ reward·terminal
```

## 온톨로지 설계

![온톨로지 상황 그래프](../assets/ontology_graph.svg)

### 노드

| 그룹 | 노드 |
|---|---|
| Perception | `PadVisibility`, `ViewRecovery` |
| Tracking | `PadMotion`, `RelativeTracking`, `TrackingCorrection` |
| Vehicle | `DroneTranslation`, `DroneAttitude` |
| Safety | `DescentEligibility`, `LandingInhibit` |

### 관계

- `informs`
- `affects_visibility`
- `supports`
- `inhibits`
- `self`

수량:

- 의미 노드 9개
- 의미 간선 17개
- 자기 간선 9개
- 전체 간선 26개
- 고립 노드 0개

### 특징

$$
X_t\in\mathbb{R}^{12\times9}
$$

노드당 특징:

- primary·signed primary
- secondary·signed secondary
- validity·confidence·uncertainty
- trend·urgency
- remaining time
- bias·type identifier

## 강화학습 결합

R-GAT attention:

$$
e_{ij}^{(r)}=\mathrm{LeakyReLU}
\left(a_r^\top[W_rx_i\Vert W_rx_j\Vert E_r]\right)
$$

$$
h_j=\tanh\left(\sum_{(i,r)\in\mathcal N(j)}
\alpha_{ij}^{(r)}W_rx_i+W_0x_j+b_0\right)
$$

Relation context:

$$
c_t=\tanh(W_g\mathrm{GroupReadout}(H_t)+b_g)
$$

Raw bypass:

$$
s_t=\mathrm{vec}(X_t)\in\mathbb{R}^{108}
$$

Actor:

$$
\mu_t=f_\pi(s_t)+W_\pi c_t
$$

Critic:

$$
V_t=f_V(s_t)+w_V^\top c_t
$$

안전 의미 gate:

$$
\delta_{z,t}^{gate}=\begin{cases}
\delta_{z,t},&\delta_{z,t}\ge0,\\
E_t\delta_{z,t},&\delta_{z,t}<0
\end{cases}
$$

- $\delta_t=W_\pi c_t$: relation residual, $\delta_{z,t}$: 수직 성분
- $E_t=\mathrm{clip}(x_{\mathrm{DescentEligibility},1},0,1)$: `DescentEligibility` 노드 primary 특징 (`relationPolicyResidual.m`)
- 실제 Actor 평균: $\mu_t=f_\pi(s_t)+[\delta_{x,t},\,\delta_{z,t}^{gate}]^\top$
- 추가 하강 residual만 eligibility 적용
- 상승·제동 residual 유지
- `LandingInhibit` 활성 시 추가 하강 차단

## 정보 누수 방지

정책·그래프 허용 정보:

- 현재 own-state
- 현재 camera detection
- causal track estimate
- observation age
- uncertainty
- previous normalized action
- public safety state

정책·그래프 금지 정보:

- hidden current pad truth
- future trajectory
- scenario phase label
- reward·return·advantage
- terminal outcome
- teacher action

사전학습 금지 정보:

- action target
- reward target
- outcome target
- future target
- hidden truth

## 공통 보상

$$
r_t=B_t-C_t+w_r(q_t-q_{t-1})+\gamma_{\Delta t}\Phi_t-\Phi_{t-1}
$$

$$
C_t=\frac{\Delta t}{70}\left(2c_{goal,t}+c_{view,t}+0.25c_{control,t}\right),
\quad
\gamma_{\Delta t}=e^{-\Delta t/70},
\quad
\Phi_t=-2c_{goal,t},\ \Phi_{terminal}=0,
\quad w_r=8
$$

구성:

- bounded goal cost
- camera view cost
- normalized control cost $\tfrac12\lVert\tanh(u_t)\rVert^2$
- landing-readiness progress
- potential-difference shaping
- one-time terminal bonus: `SUCCESS` +25, `SAFE_ABORT` −15, `TASK_TIMEOUT` −12, 네 실패 유형 −40
- 학습 curriculum: 실패 −20에서 −40으로 level 비례 강화, 평가는 −40
- 상세 정의: `docs/refactor/REWARD_RATIONALE.md`

모델별 reward 변경:

- 없음

## 학습 절차

| 항목 | 값 | 코드 |
|---|---|---|
| 초기화 | 세 모델 모두 random weight, 모방학습 제외 | `applyScratchSettings.m` |
| PPO budget | 2,500 iteration × 6 episode | `defaultRlConfig.m` `rl.scratch` |
| PPO 갱신 | 8 epoch, minibatch 256, clip 0.2, GAE $\lambda=0.95$ | `ppoTrain.m` |
| step discount | $\gamma_k=e^{-\Delta t_k/70}$ | `rolloutEpisodeV2.m` |
| 학습 seed | 단일 `rl.seed` 20240501, PPO stream seed $+404$ | `trainAgent.m` |
| episode seed | PPO RandStream의 `randi`, manifest `trainSeeds` 미사용 | `ppoTrain.m` |
| curriculum | performance level, easy 1·bridge 1·current 4 episode | `curriculumBatchLevels.m` |
| 평가 주기 | 25 iteration | `rl.scratch.evaluateEvery` |
| validation | seed 2001:2100, 결정론 정책 | `evaluateV2.m` |
| checkpoint 자격 | curriculum level 1.0 | `checkpointEligible.m` |
| 선택 점수 | $1000p_{succ}-2500p_{unsafe}-10p_{timeout}-100p_{abort}+\bar G$ | `selectionScoreV2.m` |
| R-GAT 사전학습 | causal masked reconstruction | `pretrainCausalEncoder.m` |
| R-GAT 관계 경로 활성화 | 관계 전용 PPO 25 iteration × 6 episode, 4 epoch | `ensureRelationalPath.m` |
| test | seed 3001:3100, 선택 과정 미사용 | `defaultPlanarVisibilityConfig.m` |

- $\bar G$: validation 비할인 episode return 평균
- R-GAT 그래프 적응 구간(iteration > 2,250): 기존 최고 대비 +5.0 초과 선택 점수 요구

## 전체 test 결과

- 평가 split: 모델 선택과 분리된 test seed `3001:3100`
- 평가 수: 모델별 100 episode
- 추론 프로파일: 동일 호스트 500회 반복

| 모델 | 성공률 | 위험률 | 안전 중단률 | 시간 초과율 | 평균 return |
|---|---:|---:|---:|---:|---:|
| Low-level | 74% | **2%** | 23% | **1%** | **19.139** |
| Semantic-flat | **75%** | 9% | **13%** | 3% | 18.496 |
| Ontology R-GAT | 72% | 9% | 14% | 5% | 17.930 |

| 모델 | Policy 추론 | Actor/Critic 전체 |
|---|---:|---:|
| Low-level | **0.105 ms** | **0.115 ms** |
| Semantic-flat | 0.115 ms | 0.209 ms |
| Ontology R-GAT | 0.179 ms | 0.329 ms |

- 실행시간: MATLAB 소프트웨어 프로파일
- 경성 실시간 보장·WCET 판정 제외

성능 판정:

- 전체 성공률 기준 semantic-flat 최고
- 안전 접촉 기준 baseline 우수
- ontology R-GAT의 전체 우월성 부재
- 단일 학습 seed 결과
- 다중 seed 통계 검증 필요

![Monte Carlo 평균·1시그마 평가](../assets/paper/planar_visibility_monte_carlo.png)

## 대표 시나리오 결과

| 시나리오 | Low-level | Semantic-flat | R-GAT | 안정성 지수 |
|---|---|---|---|---|
| S1 정상 정렬 | 성공 | 비허가 접촉 | 성공 | 88.7 / 85.0 / **93.5** |
| S2 급가속 | 안전 중단 | 성공 | 성공 | 37.9 / **75.9** / 74.3 |
| S3 dropout | 안전 중단 | 성공 | 성공 | 47.6 / 70.8 / **80.6** |

![대표 궤적](../assets/paper/paper_trajectories.png)

해석:

- low-level의 S2·S3 FOV 이탈과 recovery abort
- semantic-flat과 R-GAT의 S2·S3 착륙 성공
- S1 semantic-flat 비허가 접촉
- S3 R-GAT의 semantic-flat 대비 낮은 relative-speed RMSE
- S3 R-GAT의 semantic-flat 대비 낮은 control jerk
- 단일 대표 trajectory 기반 일반화 제외

## 안정성 결과

![안정성 지표](../assets/paper/paper_stability.png)

지표 구성 (`trajectoryMetrics.m`, decision 간격 $\Delta t_k$ 가중 시간 평균, $D=\sum_k\Delta t_k$):

| 지표 | 정의 | 점수 $S_k$ |
|---|---|---|
| tracking RMSE | $x_{rms}=\sqrt{\sum\Delta t_k e_{x,k}^2/D}$ | $S_1=\exp\left(-(x_{rms}/0.5)^2\right)$ |
| relative-speed RMSE | $v_{rms}=\sqrt{\sum\Delta t_k \Delta v_{x,k}^2/D}$ | $S_2=\exp\left(-(v_{rms}/0.35)^2\right)$ |
| measured FOV loss | 미검출 시간 비율 $f_{fov}$ | $S_3=1-f_{fov}$ |
| supervisor intervention | 개입 decision 시간 비율 $f_{sup}$ | $S_4=1-f_{sup}$ |
| pitch RMS | $\theta_{rms}=\sqrt{\sum\Delta t_k\theta_k^2/D}$ | $S_5=\exp\left(-(\theta_{rms}/5^\circ)^2\right)$ |
| control jerk RMS | 적용 가속도 차분 $j_{rms}$ | $S_6=1/\left(1+j_{rms}/j_{ref}\right)$ |

- $j_{ref}=\sqrt{a_{x,max}^2+a_{z,max}^2}/\Delta t_{policy}=\sqrt{2.5^2+2.0^2}/0.1\approx32.0$ m/s³
- 기준값: $L_{pad}=0.5$ m, $v_{x,td}=0.35$ m/s, $\theta_{td}=5^\circ$

종합 지수:

$$
S_{stability}=\frac{100}{6}\sum_{k=1}^{6}S_k\in[0,100]
$$

- return 제외
- terminal outcome 제외
- 성공률 별도 보고

## 착륙 가능성 결과

![가능성과 inhibit](../assets/paper/paper_feasibility.png)

정책 무관 authority margin (`scenarioFeasibility.m`):

$$
m_v=(v_{sus}-v_{margin})-v_3,
\quad
m_a=a_{x,max}-a_2,
\quad
m_T=T_{mission}-T_{deadline}
$$

- $v_3=v_1+a_2T_2$, $T_{deadline}=T_1+T_2+T_3$
- $v_{sus}=10$ m/s, $v_{margin}=0.5$ m/s, $a_{x,max}=2.5$ m/s², $T_{mission}=70$ s
- 물리적 가능: $m_v\ge0\wedge m_a>0\wedge m_T\ge0$
- 불가능 원인 우선순위: speed → acceleration → mission time

S1~S3 판정:

- speed margin 양수
- acceleration margin 양수
- mission-time margin 양수
- 물리적 착륙 가능

`LandingInhibit` 해석:

- 현재 하강 금지
- 영구적 착륙 불가능 판정 제외
- sensor dropout·trajectory/FOV·relative speed·uncertainty 원인 분해

## 최종 R-GAT 구조 감사

| 항목 | Policy | Value |
|---|---:|---:|
| Graph readout norm | 0.0001665 | 0.0006056 |
| Relation head norm | 0.1517 | 0.4792 |
| Relation path | 활성 | 활성 |
| Calibration scale | 0.001 | 0.001 |

![관계 경로 감사](../assets/paper/paper_ontology.png)

해결 구조:

- flat-equivalent anchor의 raw Actor/Critic 고정
- attention·readout·relation head 전용 PPO 25 iteration × 6 episode (`ensureRelationalPath.m`)
- 100 validation seed 결과율 비열화 가드 (`guardRelationalCandidate.m`)
- 평균 return·선택 점수 허용 저하 0.25
- relation residual norm $[10^{-6},0.005]$ 신뢰구간
- scale grid $\{1,0.75,\dots,0.001\}$ 내림차순 중 첫 통과 스케일 선택
- test seed의 선택 과정 사용 제외

연구 주장 영향:

- 온톨로지 입력 설계 구현 주장 가능
- causal R-GAT 학습 코드 구현 주장 가능
- 활성 R-GAT 계산 경로 주장 가능
- test 결과율 유지 주장 가능
- 작은 residual의 보편적 성능 우월성 주장 불가
- semantic-flat 이상의 통계적 관계 구조 효과 실증 미완료

## 검증

| 검증 | 결과 |
|---|---|
| 최종 계약 self-test | 8/8 통과 |
| 세 모델 smoke pipeline | 통과 |
| S3 단일 시나리오 | 통과 |
| checkpoint signature | 통과 |
| task fingerprint A/B/C 동일성 | 통과 |
| 고정 scenario 주입 | 통과 |
| 최소 PNG export | 통과 |
| relation performance guard | 결과율 비열화 차단 통과 |
| architecture audit | relation path 활성 탐지 |
| ontology R-GAT explorer | 9노드·26간선·5관계·108특징·Actor/Critic 렌더링 통과 |

## 전체 온톨로지·R-GAT 시각화

- 단일 코드: `src/orchestration/+landing2d/+viz/ontologyRgatExplorer.m`
- 방법론: semantic substrate와 typed adjacency matrix의 coordinated multiple views
- 근거 문서: `docs/ONTOLOGY_VIEW_KO.md`
- 스키마 탭: 의미 그룹 카드·typed relation 행렬·causal provenance·전체 간선
- 런타임 탭: 실제 최종 체크포인트의 Actor/Critic 관계별 attention 누적 막대와 원본 행렬
- 특징 탭: 12×9 노드 특징 텐서·그룹 readout·관계별 사용량
- 감사 탭: 26개 간선 score·attention·message와 전체 그래프 파라미터
- 기본 분석 지점: S3 최대 가시성 복구 필요 시점

## 최종 파일

실행:

- `run.m`: scratch 학습·validation·test·시각화 전체 파이프라인 → `landing2d.orchestration.runPipeline`
- `run_scenario.m`: 고정 시나리오 S1·S2·S3 단일 평가 → `landing2d.orchestration.runScenario`
- `run_live.m`: 세 최종 checkpoint의 실시간 lockstep 시험, drone·UGV·FOV 애니메이션 → `src/orchestration/+landing2d/+orchestration/runLive.m`

핵심 구현:

- `src/orchestration/+landing2d`
- `src/simulations/+landing2d`
- `src/algorithms/+landing2d`
- `src/orchestration/+landing2d/+viz/ontologyRgatExplorer.m`

문서:

- 저장소 루트 `../README.md`
- `README_KO.md`
- `docs/README.md`
- `docs/ONTOLOGY_GRAPH_STATE_KO.md`
- `docs/refactor/SYSTEM_SPEC.md`
- `docs/refactor/CONFIGURATION.md`
- `docs/refactor/REWARD_RATIONALE.md`
- `docs/VALIDATION_KO.md`
- `docs/MODULE_MAP_KO.md`

## 최종 제한

- 2D simulator 한정
- ideal own-state 사용
- 실제 ROS 2 transport 제외
- 실제 비행 안전 인증 제외
- 단일 PPO training seed 결과
- relation residual의 작은 안전 신뢰구간
- 보편적 온톨로지 우월성 주장 제외

## 다음 연구 조건

- graph selection margin·adaptation schedule의 다중 seed 재검토
- 비영 $W_g$ checkpoint 자동 감사 유지
- semantic-flat과 동일 base weight에서 relation residual만 비교
- 5개 이상 독립 학습 seed
- fresh held-out test 유지
- 성공률·위험률·안정성 지수의 평균·분산 보고
- 활성 relation scale과 residual 크기 동시 보고
