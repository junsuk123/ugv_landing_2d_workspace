# 공통 보상 함수 최종 명세

## 결론

- 세 PPO 모델의 보상 함수 완전 동일
- 온톨로지 기반 보상 가중치 변경 제외
- 실제 truth 사용 범위: 보상·접촉·평가
- 정책 입력 truth 누수 제외
- dense progress와 terminal outcome 분리
- terminal bonus 1회 지급 (`step.m`의 `terminalRewardPaid` assert)
- 학습 중 차이: curriculum의 실패 penalty·touchdown 한계 완화만 존재, 평가는 공칭 계약

## 전체 보상

한 decision step 보상 (`computeReward.m`):

$$
r_t=B_t-C_t+w_r\left(q_t-q_{t-1}\right)+\gamma_{\Delta t}\Phi_t-\Phi_{t-1}
$$

- $B_t$: terminal bonus, 비종료 step에서 0
- $t-1$: decision 시작 상태, $t$: decision 종료 상태 (`step.m`의 `previousTruth`·`truth`)
- $\Delta t$: 실제 decision 경과 시간 (`elapsed`); 기본 0.1 s, 사건 발생 시 사건 시각까지로 단축

Running cost:

$$
C_t=\frac{\Delta t}{T_{ref}}
\left(w_g c_{goal,t}+w_v c_{view,t}+w_u c_{control,t}\right)
$$

Discount:

$$
\gamma_{\Delta t}=\exp\left(-\frac{\Delta t}{\tau_\gamma}\right)
$$

Potential:

$$
\Phi_t=\begin{cases}
-w_p c_{goal,t}, & \text{비종료},\\
0, & \text{terminal step}
\end{cases}
\qquad
\Phi_{t-1}=-w_p c_{goal,t-1}
$$

## Goal cost

Truth 기반 오차 (`step.m`):

- $e_x=x_{pad}-x_{drone}$
- $h=z_{drone}-z_{pad}$

정규화 제곱 오차:

$$
x_2=\left(\frac{e_x}{L_x}\right)^2,
\qquad
h_2=\left(\frac{h}{L_h}\right)^2
$$

Bounded cost:

$$
c_{goal}=\rho_x\frac{x_2}{1+x_2}
+(1-\rho_x)\frac{h_2}{1+h_2}
$$

기본값:

- $L_x=3$ m
- $L_h=4$ m
- $\rho_x=0.65$

의도:

- 수평 추종과 고도 감소의 분리
- 큰 오차의 bounded penalty
- 고도 감소만으로 수평 이탈 상쇄 방지

## View cost

$$
c_{view}=\begin{cases}
\min\left(1,\left(\dfrac{\beta}{\mathrm{FOV}/2}\right)^2\right),
& \text{detected}\wedge\text{bearingValid},\\
1,&\text{otherwise}
\end{cases}
$$

- $\beta$: decision 종료 시점 camera measurement의 bearing
- $\mathrm{FOV}=50^\circ$
- 사건 발생 step: 사건 직전 마지막 measurement 사용 (사후 측정 생성 제외)

의도:

- 광축 중심 유지 유도
- 비가시 상태 최대 비용
- FOV 경계 접근의 연속 penalty

## Control cost

$$
c_{control}=\frac12\lVert\bar a_t\rVert_2^2,
\qquad
\bar a_t=\mathrm{clip}\left(\tanh(u_t),-1,1\right)
$$

- $u_t$: Gaussian 정책 raw action (R-GAT는 relation residual·descent gate 포함)
- supervisor 적용 전 정규화 행동 기준
- 과도한 가속도 명령 억제

## Landing-readiness progress

Readiness 계산 입력 (`landingReadiness`):

- $h^+=\max(h,0)$
- $\Delta v_x=v_{x,pad}-v_{x,drone}$
- $v_z,\theta,\dot\theta$: drone 수직 속도·pitch·pitch rate

Safe target:

$$
v_{x,des}=-\mathrm{sgn}(e_x)
\min\left(v_{x,td},0.6|e_x|\right)
$$

$$
v_{z,des}=-\min\left(0.8v_{z,td},0.5h^+\right)
$$

Risk:

$$
\eta=\left(\frac{e_x}{L_{pad}}\right)^2
+\left(\frac{h^+}{h_r}\right)^2
+\left(\frac{\Delta v_x-v_{x,des}}{v_{x,td}}\right)^2
+\left(\frac{v_z-v_{z,des}}{v_{z,td}}\right)^2
+\left(\frac{\theta}{\theta_{td}}\right)^2
+\left(\frac{\dot\theta}{\dot\theta_{td}}\right)^2
$$

Readiness:

$$
q_t=\exp\left(-\frac12\min(\eta,100)\right)
$$

Progress reward:

$$
r_{ready}=w_r\left(q_t-q_{t-1}\right)
$$

기준값:

| 기호 | 값 | 출처 |
|---|---:|---|
| $L_{pad}$ | 0.5 m | `padHalfLength` |
| $h_r$ | 1.0 m | `reward.readinessHeight` |
| $v_{x,td}$ | 0.35 m/s | `safety.touchdownSpeedX` |
| $v_{z,td}$ | 0.30 m/s | `safety.touchdownSpeedZ` |
| $\theta_{td}$ | 5° | `safety.touchdownPitchTolerance` |
| $\dot\theta_{td}$ | 10°/s | `safety.touchdownPitchRateTolerance` |

- 학습 episode: $v_{x,td},v_{z,td}$에 curriculum 배율 적용 (아래 curriculum 절)

특징:

- 절대 readiness 누적 제외
- episode 합의 telescoping: hover 시 0, 이탈 시 이전 이득 반환
- hover reward farming 방지
- touchdown 조건 접근의 양의 신호
- touchdown 조건 이탈의 음의 신호

## Potential shaping

$$
r_{potential}=\gamma_{\Delta t}\Phi_t-\Phi_{t-1}
$$

특징:

- 변수 timestep discount와 일치
- terminal potential 0
- 접근 진척의 시간 재분배
- 세 모델 공통 적용

## 기본 가중치

`defaultPlanarVisibilityConfig.m`의 `v2.reward`:

| 항목 | 값 |
|---|---:|
| $T_{ref}$ (`referenceTime`) | 70 s |
| $\tau_\gamma$ (`discountTimeConstant`) | 70 s |
| $w_g$ (`goalWeight`) | 2.0 |
| $w_v$ (`viewWeight`) | 1.0 |
| $w_u$ (`controlWeight`) | 0.25 |
| $w_r$ (`readinessWeight`) | 8.0 |
| $w_p$ (`potentialWeight`) | 2.0 |

## Terminal bonus

| 사건 | 공칭값 $B$ |
|---|---:|
| `SUCCESS` | +25 |
| `SAFE_ABORT` | −15 |
| `TASK_TIMEOUT` | −12 |
| `UNSAFE_CONTACT` | −40 |
| `UNAUTHORIZED_CONTACT` | −40 |
| `MISSED_PAD_CONTACT` | −40 |
| `SAFETY_ENVELOPE_VIOLATION` | −40 |

- 미등록 terminal reason: `landing2d:TerminalReward` assert 실패

## Terminal 정의

`evaluateTermination.m`, 판정 순서 고정:

| 우선 | 사건 | 조건 |
|---:|---|---|
| 1 | 접촉 | $h$가 `touchdownHeight` 0.04 m 또는 pad 평면 0을 하향 통과; 선형 보간 시각의 pre-impact 상태로 분류 |
| 1a | `MISSED_PAD_CONTACT` | $\lvert e_x\rvert>L_{pad}$ |
| 1b | `UNAUTHORIZED_CONTACT` | footprint 내, `landingInhibited` 또는 `abortRequested` |
| 1c | `UNSAFE_CONTACT` | 허가 접촉, $\lvert\Delta v_x\rvert\le v_{x,td}$·$\lvert v_z\rvert\le v_{z,td}$·$\lvert\theta\rvert\le\theta_{td}$·$\lvert\dot\theta\rvert\le\dot\theta_{td}$ 중 하나 위반 |
| 1d | `SUCCESS` | footprint 내·허가·기계적 안전 |
| 2 | `SAFETY_ENVELOPE_VIOLATION` | dynamics hard envelope, $z>25$ m, $z<0$, 비유한 상태 |
| 3 | `SAFE_ABORT` | `abortRequested`, 요청 후 ≥ 8 s, $h\ge1.0$ m, $\lvert v_z\rvert\le0.10$ m/s |
| 4 | `TASK_TIMEOUT` | scenario deadline 도달 |

Decision context (`updateDecisionContext.m`):

- 재포착: track 초기화, 마지막 검출 후 ≤ 0.5 s, confidence ≥ 0.25
- `abortRequested` 설정: 마지막 검출 후 ≥ `prolongedLoss` (공칭 3 s)
- `abortRequested` 해제: backup 중 재포착
- `landingInhibited` $=\neg$재포착 $\vee$ `abortRequested`

## 공통 safety supervisor

`safetySupervisor.m`, 입력: own-state·causal packet (hidden pad truth 제외):

$$
h_{stop}=v_{down}\,t_{resp}+\frac{v_{down}^2}{2a_{brake}},
\quad
v_{down}=\max(0,-v_z),
\quad
a_{brake}=\max\left(10^{-6},(T/W)_{max}g-g\right)
$$

- $t_{resp}=0.15$ s, $(T/W)_{max}=1.6$, $g=9.81$ m/s²

| 우선 | 조건 | 개입 |
|---:|---|---|
| 1 | `abortRequested` | $a_x=0.35\hat e_x+0.8\Delta\hat v_x$ (track 없으면 $-1.5v_x$); $h<1.0$ m 또는 $v_z<-0.10$ m/s이면 $a_z=a_{z,max}$, 아니면 $a_z=-1.5v_z$ |
| 2 | `landingInhibited` $\wedge(v_z<0\vee h\le h_{stop})$ | $a_z\leftarrow\max(a_z,\min(a_{z,max},a_{brake}))$ |
| 3 | $h\le h_{stop}\wedge v_z<-v_{z,td}$ | $a_z\leftarrow\max(a_z,\min(a_{z,max},a_{brake}))$ |

- 최종 saturation: $a_{x,max}=2.5$, $a_{z,max}=2.0$ m/s²
- 보상의 control cost는 개입 전 $\bar a_t$ 기준

## Curriculum의 보상 영향

학습 episode 생성 전용 (`trainingEpisodeConfig.m`), validation·test는 공칭 설정:

$$
B_{fail}(\ell)=s+\left(B_{fail}^{nom}-s\right)\ell,
\qquad
s=\max\left(B_{fail}^{nom},-20\right)=-20,
\quad B_{fail}^{nom}=-40
$$

- 적용 대상: 네 실패 유형 (`UNSAFE_CONTACT`, `UNAUTHORIZED_CONTACT`, `MISSED_PAD_CONTACT`, `SAFETY_ENVELOPE_VIOLATION`)
- $\ell$: episode별 curriculum level (`performance` 모드에서 `progress.height`$=\ell$)
- $\ell=0$: −20, $\ell=1$: −40
- easy replay episode ($\ell=0$): 학습 종료까지 −20 유지
- bridge replay episode: $\ell/2$
- `SUCCESS`·`SAFE_ABORT`·`TASK_TIMEOUT`: 완화 없음
- 접촉 분류 규칙 불변

동반 완화 (같은 $\ell$):

| 항목 | $\ell=0$ | $\ell=1$ |
|---|---:|---:|
| touchdown 속도 한계 배율 | 2.0 | 1.0 |
| `prolongedLoss` | 12 s | 3 s |
| $v_1,a_2$ 범위 배율 | 0.15 | 1.0 |
| $T_1$ 범위 | 0.10–0.30 s | 0.5–4 s |
| 초기 고도 배율 | 0.025–0.05 | 1.0 |

Level 진행 (`advanceCurriculumLevel.m`, `curriculumFloor.m`, `primaryConfig.m`):

- 평가 창(25 iteration)의 현재 level 학습 착륙률 ≥ 0.10, 3창 연속 시 +0.10
- 예정 하한: iteration 750 이후 선형 증가, iteration 2000에서 1.0
- batch 6 episode 중 easy 1·bridge 1·current 4 (`curriculumBatchLevels.m`)

## Checkpoint 선택 점수

`selectionScoreV2.m`, 공칭 validation seed 2001:2100 결정론 rollout:

$$
J=1000\,p_{succ}-2500\,p_{unsafe}-10\,p_{timeout}-100\,p_{abort}+\bar G
$$

- $p$: terminal 유형 비율, $p_{unsafe}$: 네 실패 유형 합
- $\bar G$: 비할인 episode return 평균
- unsafe 1건 상쇄에 성공 2건 초과 필요
- timeout을 self-induced abort보다 상위 배치
- 후보 자격: curriculum level ≥ 1.0 (`checkpointEligible.m`)
- 그래프 적응 구간 R-GAT: 기존 최고 대비 +5.0 초과 개선 요구 (`graphSelectionMargin`)

## Reward audit

`rewardAudit.m`:

- 10개 고정 fixture의 정확한 할인 return 표 (`reward_audit_v2.csv`)
- running cost와 terminal bonus만 사용, readiness·potential 항 제외
- 할인: $\sum_k \exp(-\tau_k/\tau_\gamma)\,r_k$, $\tau_k$: step 시작 경과 시간
- 용도: 성공·지연 성공·timeout·abort·unsafe 순서 점검

## 세 모델 동일성

공통 항목:

- $c_{goal}$
- $c_{view}$
- $c_{control}$
- readiness progress
- potential shaping
- terminal bonus
- curriculum 완화 일정
- discount
- termination rule
- safety supervisor

모델별 변경 제외:

- 상황별 reward weight 조정
- ontology attention reward
- graph auxiliary reward
- R-GAT 전용 성공 bonus
- semantic-flat 전용 penalty

## 희소 보상 문제 대응

과거 문제:

- 성공 terminal의 극단적 희소성
- safe abort 고착
- partial descent 후 hover
- 쉬운 curriculum checkpoint 선택

최종 대응:

- readiness 절대값 대신 signed progress
- curriculum level 1.0 checkpoint만 최종 후보
- 선택 점수의 timeout·abort·unsafe 순위 분리
- 예정 curriculum 하한의 nominal task 강제 노출
- easy·bridge replay 유지
- 실패 penalty −20 시작의 제한 완화 (+25 성공 bonus 대비 unsafe 선호 역전 방지)

## 정보경계

Truth 사용 허용:

- $e_x,h,\Delta v_x,v_z,\theta,\dot\theta$ 기반 보상 계산
- 실제 접촉 판정
- terminal outcome
- 사후 평가 metric

Truth 사용 금지:

- Actor 입력
- Critic 입력
- ontology graph 특징
- observation memory 갱신의 hidden pad 참조
- safety supervisor의 hidden pad 참조

## 관련 코드

- `src/algorithms/+landing2d/+rl/computeReward.m`
- `src/algorithms/+landing2d/+rl/rewardAudit.m`
- `src/algorithms/+landing2d/+rl/selectionScoreV2.m`
- `src/algorithms/+landing2d/+rl/checkpointEligible.m`
- `src/algorithms/+landing2d/+rl/trainingEpisodeConfig.m`
- `src/algorithms/+landing2d/+rl/curriculumBatchLevels.m`
- `src/algorithms/+landing2d/+rl/curriculumFloor.m`
- `src/algorithms/+landing2d/+rl/advanceCurriculumLevel.m`
- `src/simulations/+landing2d/+environment/step.m`
- `src/simulations/+landing2d/+environment/evaluateTermination.m`
- `src/simulations/+landing2d/+environment/updateDecisionContext.m`
- `src/simulations/+landing2d/+control/safetySupervisor.m`
- `src/orchestration/+landing2d/+config/defaultPlanarVisibilityConfig.m`
- `src/orchestration/+landing2d/+config/primaryConfig.m`
- `src/orchestration/+landing2d/+orchestration/selfTest.m`

비사용 legacy 보상 (V2 경로 미호출):

- `captureSignal.m`, `distanceSignal.m`: legacy `rolloutEpisode.m` 전용 2항 보상
