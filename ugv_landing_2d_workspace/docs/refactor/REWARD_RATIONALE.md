# 공통 보상 함수 최종 명세

## 결론

- 세 PPO 모델의 보상 완전 동일
- 온톨로지 기반 보상 가중치 변경 제외
- 실제 truth 사용 범위: 보상·접촉·평가
- 정책 입력 truth 누수 제외
- dense progress와 terminal outcome 분리
- terminal bonus 1회 지급

## 전체 보상

코드 기준 한 decision step 보상:

$$
r_t=B_t-C_t+w_r(q_t-q_{t-1})+gamma_{\Delta t}\Phi_t-\Phi_{t-1}
$$

여기서:

$$
C_t=\frac{\Delta t}{T_{ref}}
\left(w_gc_{goal,t}+w_vc_{view,t}+w_uc_{control,t}\right)
$$

$$
\gamma_{\Delta t}=\exp\left(-\frac{\Delta t}{\tau_\gamma}\right)
$$

$$
\Phi_t=-w_pc_{goal,t}
$$

Terminal 시점:

$$
\Phi_t=0
$$

## Goal cost

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
& \text{valid detection},\\
1,&\text{otherwise}
\end{cases}
$$

의도:

- 광축 중심 유지 유도
- 비가시 상태 최대 비용
- FOV 경계 접근의 연속 penalty

## Control cost

$$
c_{control}=\frac12\lVert\bar a_t\rVert_2^2
$$

- $\bar a_t=\tanh(u_t)$
- supervisor 적용 전 정책 행동 기준
- 과도한 가속도 명령 억제

## Landing-readiness progress

Safe target:

$$
v_{x,des}=-\mathrm{sgn}(e_x)
\min(v_{x,td},0.6|e_x|)
$$

$$
v_{z,des}=-\min(0.8v_{z,td},0.5h)
$$

Risk:

$$
\eta=left(\frac{e_x}{L_{pad}}ight)^2
+\left(\frac{h}{h_r}\right)^2
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
r_{ready}=w_r(q_t-q_{t-1})
$$

특징:

- 절대 readiness 누적 제외
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

| 항목 | 값 |
|---|---:|
| $T_{ref}$ | 70 s |
| $\tau_\gamma$ | 70 s |
| $w_g$ | 2.0 |
| $w_v$ | 1.0 |
| $w_u$ | 0.25 |
| $w_r$ | 8.0 |
| $w_p$ | 2.0 |

## Terminal bonus

| 사건 | 값 |
|---|---:|
| `SUCCESS` | +25 |
| `SAFE_ABORT` | -15 |
| `TASK_TIMEOUT` | -12 |
| `UNSAFE_CONTACT` | -40 |
| `UNAUTHORIZED_CONTACT` | -40 |
| `MISSED_PAD_CONTACT` | -40 |
| `SAFETY_ENVELOPE_VIOLATION` | -40 |

## 세 모델 동일성

공통 항목:

- $c_{goal}$
- $c_{view}$
- $c_{control}$
- readiness progress
- potential shaping
- terminal bonus
- discount
- termination rule

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
- curriculum 완료 checkpoint만 최종 후보
- timeout·abort·unsafe 순위 분리
- nominal task 강제 노출
- easy·bridge replay 유지

## 정보경계

Truth 사용 허용:

- $e_x,h,\Delta v_x$ 기반 보상 계산
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
- `src/simulations/+landing2d/+environment/evaluateTermination.m`
- `src/algorithms/+landing2d/+rl/rewardAudit.m`
- `src/orchestration/+landing2d/+orchestration/selfTest.m`
