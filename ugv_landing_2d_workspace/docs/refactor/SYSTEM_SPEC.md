# 시스템 모델

## 요약

- 문제 정의: 이동 UGV 패드 위 2차원 드론 착륙의 부분관측 마르코프 결정 과정(POMDP)
- 은닉 요소: 패드 운동 시나리오 $\sigma$, 센서 사건, 측정 잡음, 실제 패드 상태
- 정책 입력: causal 관측 패킷 $o_t\in\mathbb{R}^{26}$ 또는 동일 패킷 기반 의미 그래프 상태
- 정책 출력: 정규화 수평·수직 가속도 $\bar a_t\in[-1,1]^2$
- 시간 구조: 정책 결정 주기 $\Delta t_p=0.10$ s, 물리·센서·추정·안전 감독 주기 $\Delta t_s=0.01$ s
- 기체 모델: 가속도 명령 → pitch·추력 setpoint → 2차 pitch 루프·1차 추력 지연 → 병진 운동
- 센서 모델: 기체 고정 하향 카메라의 시야각·거리 제한 투영, 잡음·dropout·신뢰도 포함
- 추정기: 등가속도 예측 + 고정 이득 $k_p,k_v,k_a$ innovation 보정 + gate·포화·감쇠
- 안전 감독기 $\Pi_s$: causal 정보 기반 하강 차단·정지 높이 제동·복구 backup 결정 규칙
- 자기 상태(own-state): 잡음 없는 이상 측정 가정
- 비교 대상 간 공통 요소: 동역학·센서·추정기·보상·안전 감독기·종료 판정, 상태 표현만 상이

![시스템 파이프라인](../assets/pipeline.svg)

## 1. POMDP 정식화

- 핵심: 실제 패드 운동은 은닉 상태, 정책은 과거 측정의 causal 요약만 관측

| 요소 | 정의 |
|---|---|
| 은닉 상태 $\Xi_t$ | $(\xi_k,\;x_p,v_p,a_p,\;\sigma,\;\mathcal{W},\;\hat\chi_k,\;I^{inh}_k,I^{ab}_k)$ |
| 관측 | $o_t\in\mathbb{R}^{26}$: own-state + 추정기 출력 + 가시성 + 임무 기억 |
| 행동 | $u_t\in\mathbb{R}^2$ (Gaussian 원시 행동), $\bar a_t=\tanh(u_t)$ |
| 전이 | $\Delta t_p$ 동안 $\bar a_t$ 유지, $\Delta t_s$ 단위 감독기·동역학·센서·추정기 갱신 반복 |
| 보상 | $r_t$: 실제 상태 기반 공통 보상 (정책 입력에는 미포함) |
| 할인 | $\gamma_{\Delta t}=\exp(-\Delta t/\tau_\gamma)$, $\tau_\gamma=70$ s |
| 시나리오 분포 | $\sigma\sim\mathcal{D}$ (기각 표본추출) |

- $\mathcal{W}$: 에피소드 시작 시 사전 표본추출된 외생 센서·외란 일정(dropout 구간, pitch rate 외란 구간)
- $I^{inh}_k\in\{0,1\}$: 착륙 금지 플래그, $I^{ab}_k\in\{0,1\}$: abort(복구) 요청 플래그 — 신규 기호
- 정책 likelihood: 감독기 적용 전 원시 행동 $u_t$ 기준
- 실제 패드 상태 $x_p,v_p,a_p$: 보상·접촉 판정·평가에만 사용, 관측 제외

## 2. 좌표계와 상태

- 핵심: 진행 방향 $x$·연직 $z$의 평면 모델, 7차원 기체 상태

- world $x$: 패드 진행 방향, world $z$: 위쪽 방향
- 패드 면 높이 $z_p=0.6$ m, 패드 반길이 $L_{pad}=0.5$ m
- 기체 상태: $\xi=[x,z,v_x,v_z,\theta,\omega,F]^\top\in\mathbb{R}^7$
- 상대량: $e_x=x_p-x$, $h=z-z_p$, $\Delta v_x=v_p-v_x$
- 초기 상태: $x(0)=x_p(0)=x_0=0$, $z(0)=z_p+h_0$, $v_x(0)=v_p(0)=v_1$, $v_z(0)=0$, $\theta(0)=\omega(0)=0$, $F(0)=mg$
- 초기 착륙 금지 $I^{inh}_0=1$, 초기 abort 요청 $I^{ab}_0=0$
- 모델 제외 요소: $y$축 운동, roll·yaw, 6자유도 공력, 실제 비행 제어기 내부 상태

## 3. 행동 사상과 평면 동역학

### 3.1 행동 → 가속도 명령

- 핵심: 유계 정규화 행동의 축별 선형 배율

$$
\bar a_t=\tanh(u_t),\qquad
a_t=\mathrm{diag}(a_{x,\max},a_{z,\max})\,\bar a_t
$$

- $a_{x,\max}=2.5$ m/s², $a_{z,\max}=2.0$ m/s²
- 한 결정 구간(최대 10 물리 step) 동안 $a_t$ 유지
- 매 물리 step 감독기 적용 가속도: $\tilde a_k=\Pi_s(a_t,\xi_k,o_k)$

### 3.2 가속도 → pitch·추력 setpoint

- 핵심: 중력 보상 합력 방향과 크기로 setpoint 결정, 자세·추력 한계 포화

$$
\theta^{sp}_k=\mathrm{sat}_{\theta_{\max}}\!\left(\mathrm{atan2}\big(\tilde a_{x,k},\,g+\tilde a_{z,k}\big)\right)
$$

$$
F^{sp}_k=\mathrm{clip}\!\left(m\sqrt{\tilde a_{x,k}^2+(g+\tilde a_{z,k})^2},\;0,\;\kappa_F mg\right)
$$

- $\mathrm{sat}_b(y)=\min(\max(y,-b),b)$, $\mathrm{clip}(y,l,u)=\min(\max(y,l),u)$ — 신규 기호
- $\theta_{\max}=20^\circ$, $\kappa_F=1.6$, $m=1.5$ kg, $g=9.81$ m/s²

### 3.3 내부 루프 동역학

- 핵심: pitch는 임계감쇠 2차 응답, 추력은 1차 지연 응답

$$
\dot\omega=\omega_n^2(\theta^{sp}-\theta)-2\zeta\omega_n\,\omega,\qquad
\dot F=\frac{F^{sp}-F}{\tau_F}
$$

- $\omega_n=10$ rad/s, $\zeta=1$, $\tau_F=0.05$ s
- pitch rate 한계 $\lvert\omega\rvert\le\omega_{\max}=90^\circ$/s
- pitch rate 외란 $w_\theta$: 사건 구간 내 $\theta$에 직접 가산

### 3.4 병진 동역학

- 핵심: 실제 자세·추력에 의한 평면 병진 가속도

$$
\ddot x=\frac{F\sin\theta}{m},\qquad
\ddot z=\frac{F\cos\theta}{m}-g
$$

### 3.5 이산 적분 ($\Delta t_s$ 단위)

- 핵심: pitch 루프는 semi-implicit Euler, 병진은 갱신 후 자세·추력 기반 등가속 적분

$$
\omega_{k+1}=\mathrm{sat}_{\omega_{\max}}\!\left(\omega_k+\Delta t_s\,\dot\omega_k\right),\qquad
\theta_{k+1}=\theta_k+\Delta t_s\,\omega_{k+1}+\Delta t_s\,w_{\theta,k}
$$

$$
F_{k+1}=\mathrm{clip}\!\left(F_k+\Delta t_s\frac{F^{sp}_k-F_k}{\tau_F},\;0,\;\kappa_F mg\right)
$$

$$
\ddot x_k=\frac{F_{k+1}\sin\theta_{k+1}}{m},\qquad
\ddot z_k=\frac{F_{k+1}\cos\theta_{k+1}}{m}-g
$$

$$
x_{k+1}=x_k+\Delta t_s v_{x,k}+\tfrac12\Delta t_s^2\ddot x_k,\qquad
v_{x,k+1}=v_{x,k}+\Delta t_s\ddot x_k
$$

$$
z_{k+1}=z_k+\Delta t_s v_{z,k}+\tfrac12\Delta t_s^2\ddot z_k,\qquad
v_{z,k+1}=v_{z,k}+\Delta t_s\ddot z_k
$$

- $w_{\theta,k}$: $t_k\in[t^w_0,t^w_1)$일 때 사건 크기, 그 외 0
- 결정 구간 말미·임무 마감 직전 step: $\Delta t_s$ 대신 잔여 시간 적용
- 속도 상한 포화 미적용 (속도 배율은 관측 정규화 전용)

## 4. UGV 패드 궤적과 시나리오 분포

### 4.1 CV–CA–CV 궤적

- 핵심: 위치·속도 연속인 3구간 등속–등가속–등속 운동

| 구간 | 시간 범위 | 패드 위치 $x_p(t)$ | 속도 $v_p$ | 가속도 $a_p$ |
|---|---|---|---|---|
| CV1 | $0\le t<T_1$ | $x_0+v_1t$ | $v_1$ | 0 |
| CA | $T_1\le t<T_1+T_2$ | $x_1+v_1\tau+\tfrac12a_2\tau^2$, $\tau=t-T_1$ | $v_1+a_2\tau$ | $a_2$ |
| CV3 | $T_1+T_2\le t\le T_d$ | $x_2+v_3\tau$, $\tau=t-T_1-T_2$ | $v_3$ | 0 |

- 구간 경계 위치: $x_1=x_0+v_1T_1$, $x_2=x_1+v_1T_2+\tfrac12a_2T_2^2$ — 신규 기호
- 종속 변수: $v_3=v_1+a_2T_2$, $T_d=T_1+T_2+T_3$
- 연속성: $x_p,v_p$의 구간 경계 연속, $a_p$만 계단 변화
- 패드 높이: 전 구간 $z_p$ 고정

### 4.2 시나리오 분포 $\mathcal{D}$

- 핵심: 독립 변수 균등 표본 + 속도·시간 가능성 조건 기각

$$
v_1\sim\mathcal{U}[0.5,2.5],\;
a_2\sim\mathcal{U}[0.3,1.5],\;
T_1,T_2\sim\mathcal{U}[0.5,4],\;
T_3\sim\mathcal{U}[15,55],\;
h_0\sim\mathcal{U}[4,8]
$$

- 허용 조건: $v_3\le \bar v_d-v_{res}=9.5$ m/s 및 $T_d\le T_{\max}=70$ s
- $\bar v_d=10$ m/s: 기체 지속 가능 수평 속도, $v_{res}=0.5$ m/s: 속도 예비 margin
- 기각 시 재표본, 최대 $N_{rej}=1000$회 — 신규 기호
- 공칭 범위에서 두 조건 상시 충족 ($v_3\le8.5$ m/s, $T_d\le63$ s) → 실질적 기각 없음

### 4.3 외생 센서 사건 $\mathcal{W}$

- 핵심: 정책 실행 전 사건 일정 확정, 정책 행동과 독립

| 사건 | 확률 | 시작 시각 | 지속 시간 | 크기 |
|---|---:|---|---|---|
| 무사건(clean) | 0.50 | — | — | — |
| 단기 dropout | 0.25 | $\mathcal{U}[0.5,\max(0.5,T_d-5)]$ | $\mathcal{U}[0.2,0.5]$ s | 검출 강제 소실 |
| 지속 dropout | 0.25 | $\mathcal{U}[0.5,\max(0.5,T_d-5)]$ | $\mathcal{U}[3.5,5.0]$ s | 검출 강제 소실 |
| pitch rate 외란 | 0.25 (dropout과 독립) | $\mathcal{U}[0.5,\max(0.5,T_d-1)]$ | $\mathcal{U}[0.15,0.4]$ s | $w_\theta\sim\mathcal{U}[-2,2]^\circ$/s |

- dropout 구간 $[t^\delta_0,t^\delta_1)$, 외란 구간 $[t^w_0,t^w_1)$ — 신규 기호, 두 구간 종료 시각 상한 $T_d$
- dropout 지시자: $\delta_k=\mathbb{1}[t_k\in[t^\delta_0,t^\delta_1)]$

## 5. 카메라 투영과 가시성

- 핵심: 기체 고정 하향 카메라의 평면 투영, 깊이·거리·시야각 동시 조건

$$
d=\begin{bmatrix}e_x\\-h\end{bmatrix},\quad
b_{cam}=\begin{bmatrix}-\sin\theta\\-\cos\theta\end{bmatrix},\quad
b_{right}=\begin{bmatrix}\cos\theta\\-\sin\theta\end{bmatrix}
$$

$$
d_{cam}=d^\top b_{cam},\qquad
d_{lat}=d^\top b_{right},\qquad
\beta=\mathrm{atan2}(d_{lat},d_{cam})
$$

$$
\mathrm{vis}_k=\mathbb{1}\!\left[d_{cam}>0\;\wedge\;\lVert d\rVert\le R_{\max}\;\wedge\;\lvert\beta\rvert<\tfrac{\varphi}{2}\right]
$$

- $d_{cam}$: 광축 깊이, $d_{lat}$: 영상 우측 성분, $\mathrm{vis}_k$: 기하 가시 여부 — 신규 기호
- 시야 여유: $m_\beta=\varphi/2-\lvert\beta\rvert$ — 신규 기호
- $\varphi=50^\circ$, $R_{\max}=50$ m, 카메라 장착 pitch 오프셋 0
- pitch 증가 시 광축 회전 → 동일 상대 위치에서도 시야 이탈 가능

## 6. 측정 모델

- 핵심: 가시성·dropout 결합 검출, 가산 Gaussian 잡음, bearing 기반 신뢰도

$$
d_k=\mathrm{vis}_k\wedge\neg\delta_k
$$

$$
\tilde e_{x,k}=e_{x,k}+\sigma_e n_{1,k},\qquad
\tilde\beta_k=\beta_k+\sigma_\beta n_{2,k},\qquad
n_{1,k},n_{2,k}\sim\mathcal{N}(0,1)
$$

$$
c_k=\max\!\left(c_{fl},\;1-\min\!\left(1,\left(\frac{\tilde\beta_k}{\varphi/2}\right)^2\right)\right)
$$

- $\sigma_e=0.02$ m, $\sigma_\beta=0.15^\circ$, 신뢰도 하한 $c_{fl}=0.05$ — 신규 기호 $c_{fl}$
- 미검출($d_k=0$): $\tilde e_{x,k}=\tilde\beta_k=0$, $c_k=0$, bearing 유효 표시 0
- 측정 시각: 매 물리 step 종료 시점 $t_{k+1}$
- 접촉·종료 사건 발생 step: 사건 이후 정보 유입 방지 목적의 측정 생략

## 7. Causal 패드 운동 추정기

- 핵심: 등가속도 예측 + 고정 이득 $k_p,k_v,k_a$ 보정의 상태 $\hat\chi=[\hat x_p,\hat v_p,\hat a_p]^\top$, 실제 패드 상태 미참조
- 실행 주기: 매 물리 step ($\Delta t_s$)

### 7.1 패드 위치 측정

$$
y_k=x_k+\tilde e_{x,k}
$$

- $y_k$: 자기 위치 기준 world 패드 위치 측정 — 신규 기호

### 7.2 예측 (초기화 이후, 경과 시간 $\Delta=t_k-t_{k-1}$)

$$
\hat x_p\leftarrow\hat x_p+\hat v_p\Delta+\tfrac12\hat a_p\Delta^2,\qquad
\hat v_p\leftarrow\hat v_p+\hat a_p\Delta,\qquad
\hat a_p\leftarrow\hat a_p\,e^{-\Delta/\tau_a}
$$

- $\tau_a=1.5$ s: 무측정 시 가속도 추정의 0 방향 감쇠

### 7.3 불확실성 전파

$$
\hat\sigma_p\leftarrow\sqrt{\hat\sigma_p^2+\left(\tfrac12\sigma_q\Delta^2\right)^2},\quad
\hat\sigma_v\leftarrow\sqrt{\hat\sigma_v^2+(\sigma_q\Delta)^2},\quad
\hat\sigma_a\leftarrow\sqrt{\hat\sigma_a^2+\sigma_q^2\Delta}
$$

- $\sigma_q=1.5$ m/s²: 공정 가속도 표준편차 — 신규 기호
- 초기값: $\hat\sigma_p=2$ m, $\hat\sigma_v=3$ m/s, $\hat\sigma_a=2$ m/s²

### 7.4 초기화 (첫 유효 검출)

- $\hat x_p=y_k$, $\hat v_p=v_{x,k}$ (자기 수평 속도를 유일한 causal 사전값으로 사용), $\hat a_p=0$
- 초기화 플래그 $\mathbb{1}^{trk}=1$ 설정 — 신규 기호
- 초기화 시 불확실성 값 유지

### 7.5 Innovation gate

$$
\nu_k=y_k-\hat x_p,\qquad
\text{수용}\iff\lvert\nu_k\rvert\le\max\!\big(\nu_{\min},\;n_g\max(\hat\sigma_p,\sigma_e)\big)
$$

- $n_g=4$: gate 배수, $\nu_{\min}=0.25$ m: gate 하한 — 신규 기호
- 기각 측정: 추정·마지막 검출 시각 갱신 제외 → $\Delta t_{\mathrm{loss}}$ 계속 증가

### 7.6 수용 시 갱신

$$
\hat x_p\leftarrow\hat x_p+k_p\nu_k,\qquad
\hat v_p\leftarrow\hat v_p+\frac{k_v\,\nu_k}{\Delta t_m},\qquad
\hat a_p\leftarrow\mathrm{sat}_{\hat a_{\max}}\!\left(\hat a_p+\frac{2k_a\,\nu_k}{\Delta t_m^2}\right)
$$

$$
\hat\sigma_p\leftarrow\max(\sigma_e,\;0.5\,\hat\sigma_p),\quad
\hat\sigma_v\leftarrow\max\!\left(\frac{k_v\sigma_e}{\Delta t_m},\;0.8\,\hat\sigma_v\right),\quad
\hat\sigma_a\leftarrow\max(0.25\,\sigma_q,\;0.85\,\hat\sigma_a)
$$

- $\Delta t_m$: 직전 수용 측정 이후 경과 시간
- $k_p=0.20$, $k_v=0.02$, $k_a=0.00005$: 100 Hz 측정의 2 cm 잡음 미분 증폭 억제 목적의 작은 속도·가속도 이득
- $\hat a_{\max}=3.0$ m/s²: 가속도 추정 포화 — 신규 기호
- 수용 시 기억: 마지막 검출 시각 $t^{det}$, 마지막 신뢰도 $c^{last}$ — 신규 기호

### 7.7 검출 경과 시간

$$
\Delta t_{\mathrm{loss},k}=\begin{cases}t_k-t^{det}, & \text{수용 측정 존재}\\ \infty, & \text{그 외}\end{cases}
$$

- 관측 패킷 내 $\infty$ 대체값: $T_{\max}$

## 8. 관측 패킷 구성 ($26=6+8+7+5$)

- 핵심: 현재 own-state·causal 추정·가시성·임무 기억의 4개 의미 그룹, 미래·은닉 truth 제외

| 그룹 | 차원 | 구성 요소 | 의미 |
|---|---:|---|---|
| 자기 운동 | 6 | $h,\;v_x,\;v_z,\;\sin\theta,\;\cos\theta,\;\omega$ | 이상 own-state, 패드 상대 고도 포함 |
| 패드 추적 | 8 | $\hat e_x,\;\widehat{\Delta v_x},\;\hat v_p,\;\hat a_p,\;\hat\sigma_p,\;\hat\sigma_v,\;\hat\sigma_a,\;\mathbb{1}^{trk}$ | causal 상대 운동 추정과 불확실성 |
| 가시성 | 7 | $d_k,\;\tilde\beta_k,\;d_k^{\beta},\;c_k,\;\Delta t_{\mathrm{loss}},\;\hat\beta^+,\;\hat m_\beta^+$ | 현재 검출·시야 여유·예측 시야 |
| 임무 기억 | 5 | $T_d-t,\;\bar a_{t-1,x},\;\bar a_{t-1,z},\;I^{inh},\;I^{ab}$ | 잔여 시간·직전 행동·감독기 공개 상태 |

- $\hat e_x=\hat x_p-x$, $\widehat{\Delta v_x}=\hat v_p-v_x$ (추정기 미초기화 시 0)
- $d_k^\beta$: bearing 유효 표시 ($=d_k$) — 신규 기호
- 예측 시야 (예측 지평 $T_h=0.5$ s, 신규 기호):

$$
\hat e_x^+=\hat e_x+\widehat{\Delta v_x}\,T_h+\tfrac12\hat a_pT_h^2,\qquad
\theta^+=\theta+\omega T_h
$$

- $\hat\beta^+,\hat m_\beta^+$: $(\hat e_x^+,h,\theta^+)$에 5절 투영 적용 결과의 bearing·시야 여유 — 신규 기호
- 비유한 값(투영 불가·미검출): 0 대체 + 유효 표시 동반
- 정규화 (부호 보존 연속 포화, 신규 기호 $\mathrm{sn},\mathrm{un}$):

$$
\mathrm{sn}(y;\bar y)=\frac{y}{\lvert y\rvert+\bar y},\qquad
\mathrm{un}(y;\bar y)=\min\!\left(\frac{y^+}{y^++\bar y},1\right),\;y^+=\max(y,0)
$$

| 성분 | 정규화 | 기준값 $\bar y$ |
|---|---|---|
| $h$ | $\mathrm{sn}$ | 8 m |
| $v_x,\;v_z$ | $\mathrm{sn}$ | 10 m/s, 1.5 m/s |
| $\omega$ | $\mathrm{sn}$ | $\omega_{\max}$ |
| $\hat e_x,\;\widehat{\Delta v_x}$ | $\mathrm{sn}$ | 3 m, 3 m/s |
| $\hat v_p,\;\hat a_p$ | $\mathrm{sn}$ | 10 m/s, 2 m/s² |
| $\hat\sigma_p,\;\hat\sigma_v,\;\hat\sigma_a$ | $\mathrm{un}$ | 5 m, 5 m/s, 3 m/s² |
| $\tilde\beta_k,\;\hat\beta^+,\;\hat m_\beta^+$ | $\mathrm{sn}$ | $\varphi/2$ |
| $\Delta t_{\mathrm{loss}}$ | $\mathrm{un}$ | $T_{loss}=3.0$ s |
| $T_d-t$ | $\mathrm{clip}(\cdot/T_{\max},0,1)$ | $T_{\max}$ |
| $\sin\theta,\cos\theta$, 이진 표시, $c_k$, 직전 행동 | 미적용 | — |

## 9. 결정 문맥 갱신 (착륙 금지·abort 요청)

- 핵심: 최근성·신뢰도 기반 착륙 허가, 장기 소실 시 abort 요청, 재포착 시 해제

$$
\mathrm{reacq}_k=\mathbb{1}^{trk}\wedge\big(\Delta t_{\mathrm{loss},k}\le T_{gr}\big)\wedge\big(c^{last}\ge c_{th}\big)
$$

- $T_{gr}=0.5$ s: 최근 검출 허용 시간, $c_{th}=0.25$: 최소 추적 신뢰도, $\mathrm{reacq}_k$: 재포착 판정 — 신규 기호
- abort 해제: $I^{ab}=1\wedge\mathrm{reacq}_k$ → $I^{ab}\leftarrow0$
- abort 요청: $I^{ab}=0\wedge\Delta t_{\mathrm{loss},k}\ge T_{loss}$ → $I^{ab}\leftarrow1$, 요청 시각 $t^{ab}$ 기록 — 신규 기호 $T_{loss}=3.0$ s, $t^{ab}$
- 착륙 금지: $I^{inh}_k=\neg\mathrm{reacq}_k\vee I^{ab}_k$

## 10. 안전 감독기 $\Pi_s$

- 핵심: causal 정보(own-state·패킷)만 사용하는 우선순위 3분기 결정 규칙, 실제 패드 상태 미사용
- 실행 주기: 매 물리 step, 모든 비교 대상 공통

### 10.1 정지 높이

$$
v_{down}=\max(0,-v_z),\qquad
a_{brake}=\max\!\big(10^{-6},(\kappa_F-1)g\big),\qquad
h_{stop}=v_{down}t_{resp}+\frac{v_{down}^2}{2a_{brake}}
$$

- $v_{down}$: 하강 속력, $a_{brake}$: 가용 수직 제동 가속도($\approx5.89$ m/s²), $t_{resp}=0.15$ s: 반응 지연, $h_{stop}$: 수직 정지 소요 고도
- 실제 제동 명령은 $a_{z,\max}=2.0$ m/s²로 포화 → $h_{stop}$은 낙관적 추정치

### 10.2 분기 규칙 (위에서부터 첫 충족 분기 적용)

| 우선순위 | 조건 | $\tilde a_x$ | $\tilde a_z$ | 의미 |
|---:|---|---|---|---|
| 1 | $I^{ab}=1$ | $\mathbb{1}^{trk}=1$: $0.35\,\hat e_x+0.8\,\widehat{\Delta v_x}$; 그 외: $-1.5\,v_x$ | $h<h_{hold}\vee v_z<-v_{tol}$: $a_{z,\max}$; 그 외: $\mathrm{sat}_{a_{z,\max}}(-1.5\,v_z)$ | 복구 backup: causal 추적 기반 수평 추종 + 상승·고도 유지 |
| 2 | $I^{inh}=1\wedge(v_z<0\vee h\le h_{stop})$ | $a_x$ | $\max\!\big(a_z,\min(a_{z,\max},a_{brake})\big)$ | 하강 차단·제동 |
| 3 | $h\le h_{stop}\wedge v_z<-v_{z,td}$ | $a_x$ | $\max\!\big(a_z,\min(a_{z,\max},a_{brake})\big)$ | 수직 정지 여유 확보 |
| — | 그 외 | $a_x$ | $a_z$ | 통과 |

- 최종 포화: $\tilde a_x\leftarrow\mathrm{sat}_{a_{x,\max}}(\tilde a_x)$, $\tilde a_z\leftarrow\mathrm{sat}_{a_{z,\max}}(\tilde a_z)$
- $h_{hold}=1.0$ m: abort 유지 고도, $v_{tol}=0.10$ m/s: abort 수직 속도 허용치, $v_{z,td}=0.30$ m/s: 착지 수직 속도 한계 — 신규 기호
- backup 중 수평 추종 목적: 이동 패드 시야 재확보, 관성 정지 시의 영구 이탈 방지
- 감독기 개입 기록: 요청 $a_t$ 대비 적용 $\tilde a_k$ 차이 발생 여부

## 11. 종료 조건

- 핵심: 매 물리 step 최초 사건으로 종료, 접촉은 보간 시점의 접촉 직전 상태로 판정
- 판정 순서: 접촉 → 안전 범위 위반 → 안전 중단 → 시간 초과

### 11.1 접촉 판정

- 접촉 발생: $h_k>h_{td}\ge h_{k+1}$ 또는 $h_k>0\ge h_{k+1}$, $h_{td}=0.04$ m (신규 기호)
- 접촉 시점 보간 비율: $\upsilon=\mathrm{clip}\big((h_k-h_{td})/(h_k-h_{k+1}),0,1\big)$ (패드면 통과 시 $h_{td}\to0$), 기체·패드 상태 선형 보간 — 신규 기호 $\upsilon$
- 허가 여부: 접촉 step 시작 시점의 $I^{inh}=0\wedge I^{ab}=0$
- 기계적 안전: $\lvert e_x\rvert\le L_{pad}\wedge\lvert\Delta v_x\rvert\le v_{x,td}\wedge\lvert v_z\rvert\le v_{z,td}\wedge\lvert\theta\rvert\le\theta_{td}\wedge\lvert\omega\rvert\le\omega_{td}$
- $v_{x,td}=0.35$ m/s, $\theta_{td}=5^\circ$, $\omega_{td}=10^\circ$/s — 신규 기호

| 결과 | 조건 (위에서부터 적용) |
|---|---|
| MISSED_PAD_CONTACT | $\lvert e_x\rvert>L_{pad}$ |
| UNAUTHORIZED_CONTACT | 패드 내 접촉, 미허가 |
| UNSAFE_CONTACT | 패드 내 허가 접촉, 기계적 안전 조건 위반 |
| SUCCESS | 패드 내 허가 접촉, 기계적 안전 조건 충족 |

### 11.2 비접촉 종료

| 결과 | 조건 |
|---|---|
| SAFETY_ENVELOPE_VIOLATION | $\lvert\theta\rvert>\theta_{\max}+1^\circ$, $\lvert\omega\rvert>\omega_{\max}$, $z>z_{ceil}$, $z<0$, 비유한 상태 중 하나 |
| SAFE_ABORT | $I^{ab}=1\wedge t-t^{ab}\ge T_{bk}\wedge h\ge h_{hold}\wedge\lvert v_z\rvert\le v_{tol}$ |
| TASK_TIMEOUT | $t\ge T_d$ |

- $z_{ceil}=25$ m: world 기준 천장 고도, $T_{bk}=8$ s: backup 최소 지속 시간 — 신규 기호
- 모든 결과: 종료 상태, 종료 이후 bootstrap 가치 0
- 외부 수집 길이 한계만 절단(truncation) 처리
- 종료 보너스: 결정 단위 보상에 1회 반영

## 12. 결정 단위 실행 알고리즘

- 핵심: 결정 1회 = 정책 순전파 1회 + 최대 10회 물리 step, 감독·적분·종료·측정·추정의 고정 순서

**알고리즘 1. 에피소드 실행**

1. 시나리오 $\sigma\sim\mathcal{D}$, 센서 사건 $\mathcal{W}$ 표본추출 (정책과 독립)
2. 초기 상태 $\xi_0$ 설정, $t\leftarrow0$, 초기 측정·추정기 갱신·결정 문맥 갱신
3. 초기 관측 $o_0$ 구성·정규화
4. 정책 결정 시점 $t$마다 반복:
   1. 상태 표현 구성 (패킷 직접 사용 또는 의미 그래프 상태)
   2. Actor 순전파 → $u_t$ 표본(평가 시 평균), $\bar a_t=\tanh(u_t)$, $a_t=\mathrm{diag}(a_{x,\max},a_{z,\max})\bar a_t$
   3. 실제 경과 시간 $\Delta t\leftarrow0$, 물리 step 반복 ($\Delta t<\Delta t_p$ 및 무사건 동안):
      1. step 길이 $\Delta=\min(\Delta t_s,\;\Delta t_p-\Delta t,\;T_d-t_k)$
      2. 현재 추정기·측정·결정 문맥 기반 패킷 $o_k$ 구성
      3. 감독기 적용 $\tilde a_k=\Pi_s(a_t,\xi_k,o_k)$
      4. 외란 $w_{\theta,k}$ 결정 ($t_k\in[t^w_0,t^w_1)$)
      5. 동역학 적분 $\xi_{k+1}$, 패드 상태 $(x_p,v_p,a_p)(t_{k+1})$ 계산
      6. 접촉 판정 (step 시작 시점 결정 문맥 사용) → 접촉 시 보간·종료
      7. 무접촉 시: $t_{k+1}$ 시점 $\delta_{k+1}$ 적용 측정 생성 → 추정기 예측·gate·갱신 → 결정 문맥 갱신 → 비접촉 종료 판정
      8. $\Delta t\leftarrow\Delta t+\Delta$ (사건 발생 시 사건 시각까지 단축)
   4. 직전 행동 $\bar a_{t}$ 기억, 다음 관측 $o_{t+1}$ 구성
   5. 결정 시작·종료 시점 실제 상태 기반 보상 $r_t$ 계산, 할인 $\gamma_{\Delta t}$
   6. 종료 시 반복 중단

## 13. 실시간 계산 범위

- 핵심: 실시간 경로는 순전파·감독기·추정기만 포함, 학습 계열 연산은 비실시간

| 구분 | 포함 연산 |
|---|---|
| 실시간 (결정·물리 주기 내) | 관측 구성, 상태 표현 순전파, 행동 사상, 안전 감독기, 추정기 갱신 |
| 비실시간 | PPO 역전파, 의미 그래프 masked 재구성 사전학습, 검증 기반 checkpoint 선택, Monte Carlo 평가 |

## 14. 모델 한계

- 핵심: 연구용 평면 시뮬레이션, 실기체 인증 범위 외

- 2차원 평면 운동 한정
- 실제 통신 지연·패킷 손실 미검증
- 감독기는 시뮬레이션 안전 장치이며 실비행 안전성 인증 제외
- 기체·센서 파라미터는 식별값이 아닌 시뮬레이션 기준값
