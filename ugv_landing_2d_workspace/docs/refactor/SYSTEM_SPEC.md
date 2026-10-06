# Planar Visibility PPO v2 최종 시스템 명세

## 결론

- 연구 환경: CV–CA–CV 이동 패드와 pitch/thrust 기반 2차원 드론
- 정책 입력: causal 26필드 packet 또는 동일 packet 기반 9노드 그래프
- 정책 출력: 수평·수직 가속도 2개
- 공통 계층: 동역학·센서·추정기·보상·안전 감독기·종료 판정
- 비교 계층: Actor/Critic 상태 표현
- 정책 주기 0.10 s, 물리 주기 0.01 s
- 패드 검출·track 갱신·안전 감독기: 매 물리 step(100 Hz)
- 자기 상태(own-state): 잡음 없는 이상 측정

![시스템 파이프라인](../assets/pipeline.svg)

## 좌표계와 상태

- world $x$: 패드 진행 방향
- world $z$: 위쪽 방향
- 패드 표면 고도: $z_p$ (0.6 m)
- 상대 수평 오차: $e_x=x_p-x_d$
- 패드 기준 고도: $h=z_d-z_p$

물리 상태:

$$
q_t=[x_d,z_d,v_{x,d},v_{z,d},\theta,\dot\theta,T]^\top
$$

초기 상태:

- $h_0$: 시나리오 표본 고도
- $v_{x,d}(0)=v_p(0)=v_1$, $v_{z,d}(0)=0$
- $\theta=\dot\theta=0$, $T=mg$

제외 상태:

- $y$ 위치·속도
- roll·yaw
- 6자유도 공력
- 실제 비행 제어기 내부 상태

## 패드 궤적

세 구간:

1. CV1: 초기 속도 $v_1$, 지속시간 $T_1$
2. CA: 일정 가속도 $a_2$, 지속시간 $T_2$
3. CV3: 최종 속도 $v_3=v_1+a_2T_2$, 지속시간 $T_3$

- 에피소드 deadline: $T_1+T_2+T_3\le70$ s

연속성:

$$
x_p(t_1^-)=x_p(t_1^+),\qquad
x_p(t_2^-)=x_p(t_2^+)
$$

$$
v_p(t_1^-)=v_p(t_1^+),\qquad
v_p(t_2^-)=v_p(t_2^+)
$$

## 행동과 동역학

정책의 raw Gaussian 명령:

$$
u_t\sim\mathcal{N}(\mu_t,\mathrm{diag}(\sigma_t^2))
$$

정규화 행동:

$$
\bar a_t=\tanh(u_t)
$$

요청 가속도:

$$
a_x=a_{x,\max}\bar a_{t,1},\qquad
a_z=a_{z,\max}\bar a_{t,2}
$$

- $a_{x,\max}=2.5$ m/s², $a_{z,\max}=2.0$ m/s²
- 한 정책 주기(물리 10 step) 동안 동일 행동 유지

자세·추력 setpoint:

$$
\theta_{sp}=\mathrm{atan2}(a_x,g+a_z)
$$

$$
T_{sp}=m\sqrt{a_x^2+(g+a_z)^2}
$$

- $|\theta_{sp}|\le20^\circ$, $0\le T_{sp}\le1.6\,mg$

실제 병진 동역학:

$$
\ddot x=\frac{T\sin\theta}{m},\qquad
\ddot z=\frac{T\cos\theta}{m}-g
$$

- pitch: 감쇠 2차 응답 ($\omega_n=10$ rad/s, $\zeta=1$, $|\dot\theta|\le90^\circ$/s)
- thrust: 1차 지연 응답 ($\tau=0.05$ s)
- pitch-rate 외란 사건: $\theta$에 직접 가산
- PPO likelihood: supervisor 적용 전 raw $u_t$ 기준

## 카메라와 가시성

상대 벡터:

$$
d=[e_x,-h]^\top
$$

Body-fixed 카메라 축:

$$
b_{cam}=[-\sin\theta,-\cos\theta]^\top
$$

Image-right 축:

$$
b_{right}=[\cos\theta,-\sin\theta]^\top
$$

투영:

$$
d_{cam}=d^\top b_{cam},\qquad
\ell=d^\top b_{right},\qquad
\beta=\mathrm{atan2}(\ell,d_{cam})
$$

가시 조건:

$$
d_{cam}>0,\qquad \lVert d\rVert\le R_{max},\qquad
|\beta|<\frac{\mathrm{FOV}}{2}
$$

- FOV 50°, $R_{max}=50$ m
- 검출 주기: 매 물리 step(100 Hz)
- 검출 출력: 상대위치 $e_x$ (잡음 σ 0.02 m), bearing $\beta$ (잡음 σ 0.15°)
- 검출 신뢰도: $\max(0.05,\ 1-\min(1,(\beta/(\mathrm{FOV}/2))^2))$
- dropout 구간: 가시 여부와 무관하게 미검출

## Causal observation memory

- 패드 위치·속도·가속도 추정 유지
- 갱신: 등가속도 예측 + alpha-beta-gamma innovation 보정
- 이득: $\alpha=0.20$, $\beta=0.02$, $\gamma=0.00005$
- 가속도 추정: 감쇠 시정수 1.5 s, 포화 ±3.0 m/s²
- 마지막 검출 시각 유지
- 위치·속도·가속도 불확실성 유지 (process acceleration σ 1.5 m/s²)
- 비가시 구간 예측만 사용
- 현재 hidden pad truth 참조 제외
- 재검출 innovation gate: $4\sigma_{pos}$ (최소 0.25 m)
- 첫 검출 시 패드 속도 초기값: own $v_x$
- 예측 bearing·FOV margin: 0.5 s 앞 상대 위치·자세 기준

## 상태 표현 비교

| 모델 | Actor/Critic 입력 | 차원 |
|---|---|---:|
| Baseline | normalized causal packet → MLP | 26 |
| Semantic-flat | $\mathrm{vec}(X_t)$ → MLP | 108 |
| Ontology R-GAT | $\mathrm{vec}(X_t)$ → MLP + relation context 선형 residual | 108+4 |

- 공통 MLP: 은닉층 48×2
- R-GAT residual: $\mu_t=\mathrm{MLP}(\mathrm{vec}(X_t))+W_\pi c_t$, $V_t=\mathrm{MLP}_V(\mathrm{vec}(X_t))+W_V c_t$
- 하강 방향 수직 residual: `DescentEligibility` 노드 값으로 gate
- relation context $c_t$: 4개 readout 그룹 (Perception·Tracking·Vehicle·Safety)

## 안전 감독기

입력:

- own-state
- causal packet
- 요청 가속도

기능:

- 최근 검출 0.5 s 초과 또는 신뢰도 0.25 미만: `landingInhibited`, 하강 차단·제동
- 연속 미검출 3.0 s 이상: `abortRequested`, 복구 backup
- backup: causal track 기반 수평 추종 + 패드 기준 1.0 m 이상 상승·고도 유지
- 정지거리 기반 수직 제동 (반응 지연 0.15 s)
- 재포착(최근 검출 + 신뢰도 충족) 시 abort 요청 해제
- backup 8 s 경과 + 고도 1.0 m 이상 + $|v_z|\le0.10$ m/s 시 `SAFE_ABORT`
- hidden pad truth 사용 제외

## 종료 사건

| 사건 | 의미 | terminal bonus |
|---|---|---:|
| `SUCCESS` | 허가·기계적 안전 접촉 | +25 |
| `SAFE_ABORT` | 복구 실패 후 안전 중단 | -15 |
| `TASK_TIMEOUT` | 시나리오 deadline $T_1+T_2+T_3$ 도달 | -12 |
| `UNSAFE_CONTACT` | 허가 접촉, 속도·자세 한계 초과 | -40 |
| `UNAUTHORIZED_CONTACT` | 착륙 금지·abort 중 접촉 | -40 |
| `MISSED_PAD_CONTACT` | 패드 반길이 0.5 m 밖 접촉 | -40 |
| `SAFETY_ENVELOPE_VIOLATION` | pitch·pitch-rate 한계, 천장 world z 25 m, 지면 아래, 비유한 상태 | -40 |

- 접촉 판정 높이: 패드 기준 0.04 m
- 안전 접촉: $|v_{x,rel}|\le0.35$, $|v_z|\le0.30$ m/s, $|\theta|\le5^\circ$, $|\dot\theta|\le10^\circ$/s
- 모든 named outcome: `terminated=true`
- terminal bootstrap: 0
- 외부 수집 한계만 `truncated=true`
- 접촉 시점 interpolation 적용

## 보상

$$
r_t=b_{term}-\frac{\Delta t}{70}\left(2\,c_{goal}+c_{view}+0.25\,c_{ctrl}\right)
+8\,(\rho_{t+1}-\rho_t)+\left(\gamma_{\Delta t}\Phi_{t+1}-\Phi_t\right)
$$

- $c_{goal}=0.65\,\frac{(e_x/3)^2}{1+(e_x/3)^2}+0.35\,\frac{(h/4)^2}{1+(h/4)^2}$
- $c_{view}=\min(1,(\beta/(\mathrm{FOV}/2))^2)$, 미검출 시 1
- $c_{ctrl}=\tfrac12\lVert\bar a_t\rVert^2$
- $\rho$: 착륙 준비도 $\exp(-\tfrac12\,\mathrm{risk})$
- $\Phi=-2\,c_{goal}$, 종료 시 $\Phi_{t+1}=0$, $\gamma_{\Delta t}=e^{-\Delta t/70}$
- 보상 계산: 시뮬레이터 truth 사용, 정책 입력에는 미포함

## 실행 흐름

```text
reset
→ scenario·sensor event 사전 결정
→ causal packet 구성
→ 상태 표현 분기
→ Actor/Critic 순전파
→ tanh·가속도 scaling
→ [0.01 s 물리 step × 10]
    → 공통 안전 감독기
    → 물리 적분
    → 접촉·종료 판정
    → 패드 검출·track 갱신
→ 보상 계산
→ 다음 0.10 s 정책 결정
```

## 실행 진입점

- `run`: scratch PPO 학습 → validation 선택 → test 평가 → 논문 시각화
- `run_scenario('S1'|'S2'|'S3')`: 저장 checkpoint로 단일 대표 시나리오 평가
- `run_live`: 세 checkpoint 실시간 lockstep 비교 (`landing2d.orchestration.runLive`)

## 비실시간 작업

- PPO 역전파
- R-GAT masked reconstruction 사전학습
- validation checkpoint 선택
- Monte Carlo 평가
- 논문용 시각화

## 제한

- 연구용 2D 시뮬레이션
- 실제 로봇 메시지 형식 모사 수준
- 실제 통신 지연·패킷 손실 미검증
- 실제 비행 안전성 인증 제외
