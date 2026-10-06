# 온톨로지 그래프 상태와 R-GAT

## 요약

- 온톨로지 역할: 보상 가중치 조절이 아닌 Actor/Critic 상태 표현
- 입력 원천: 저수준 비교군과 동일한 causal 관측 패킷 $o_t\in\mathbb{R}^{26}$
- 그래프 구조: 4개 의미 그룹의 9개 노드, 17개 의미 간선, 9개 자기 간선, 5개 관계 유형
- 노드 특징: 노드당 12채널, $X_t\in\mathbb{R}^{12\times9}$, raw semantic 상태 $s_t=\mathrm{vec}(X_t)\in\mathbb{R}^{108}$
- 부호화: 단일층 R-GAT, 전체 수신 간선 공동 정규화, 그룹 평균 readout 기반 관계 문맥 $c_t\in\mathbb{R}^4$
- 정책 결합: raw semantic 경로 $f_\pi(s_t)$·$f_V(s_t)$ + 관계 residual, 수직 하강 residual의 $g_t$ gate 적용
- 학습: masked 동시점 재구성 사전학습 → raw semantic PPO → 관계 적응 PPO의 3단계
- 검증 guard: raw 경로 고정 상태의 readout 축소 배율 $\nu_{rel}$ 탐색, 검증 결과율 비악화 조건
- 최종 감사: 관계 경로 활성, $\nu_{rel}=0.001$, test 결과율 72%/9%/14%/5% 유지
- 주장 범위: 관계 경로 활성·성능 보존까지, 성능 우월성 주장 제외

![온톨로지 상황 그래프](assets/ontology_graph.svg)

## 1. 정보 경계

- 핵심: $X_t$는 결정 시점까지의 causal 관측만의 결정적 함수
- 핵심: 보상·행동 결과·미래·시뮬레이터 참값의 상태 유입 차단

$$
o_t=[o_t^{\mathrm{own}},\,o_t^{\mathrm{track}},\,o_t^{\mathrm{vis}},\,o_t^{\mathrm{mem}}]\in\mathbb{R}^{26},\qquad X_t=\mathcal{F}(o_t)
$$

| 묶음 | 차원 | 구성 |
|---|---:|---|
| 자기 운동 $o_t^{\mathrm{own}}$ | 6 | $h$, $v_x$, $v_z$, $\sin\theta$, $\cos\theta$, $\omega$ |
| 패드 추적 $o_t^{\mathrm{track}}$ | 8 | $\hat e_x$, $\widehat{\Delta v}_x$, $\hat v_p$, $\hat a_p$, $\hat\sigma_p$, $\hat\sigma_v$, $\hat\sigma_a$, 추적 초기화 지시자 $\iota$ |
| 가시성 $o_t^{\mathrm{vis}}$ | 7 | $d_k$, $\tilde\beta_k$, bearing 유효 지시자 $d_\beta$, $c_k$, $\Delta t_{\mathrm{loss}}$, 예측 bearing $\hat\beta$, 예측 FOV 여유 $\hat m$ |
| 과제 기억 $o_t^{\mathrm{mem}}$ | 5 | 잔여 시간 $T_{rem}$, 직전 정규화 행동 2개, 하강 금지 플래그 $b_{inh}$, 중단 요청 플래그 $b_{ab}$ |

- $\mathcal{F}$: 아래 3절의 노드 특징 사상, 학습 파라미터 없는 고정 함수
- 직전 정규화 행동: $o_t$ 포함, $X_t$ 미사용
- 제외 정보: 비가시 구간 실제 패드 위치·속도, 예정 구간 번호, 미래 패드 궤적, 보상·return·advantage, 종료 결과 라벨, 교사 행동, 평가용 참값 지표

## 2. 온톨로지 설계

### 2.1 설계 제약

- 핵심: 제어 결정에 직접 연결되고 관측으로 계산 가능한 의미만 노드화
- 인과성: 모든 노드 값의 동일 시점 $o_t$ 의존, 미래 참조 없음
- 비보상성: 보상항 전용 노드·행동 노드·결과 노드·빈 query 노드 제외
- 비중복성: 동일 의미 반복 노드 제외, 고립 노드 없음
- 방향성: 간선 방향 보존, 자동 대칭화 제외
- 정보 동등성: semantic-flat 비교군과 동일 $s_t$ 공유, 그래프 구조만의 차이

### 2.2 노드와 그룹

- 핵심: 4개 의미 그룹(Perception·Tracking·Vehicle·Safety)으로의 9개 노드 분할, 각 노드의 단일 그룹 소속

| $i$ | 노드 | 그룹 $\mathcal V_g$ | 핵심 관측 | 제어 의미 |
|---:|---|---|---|---|
| 1 | PadVisibility | Perception | $d_k$, $\tilde\beta_k$, $\hat\beta$, $\hat m$, $c_k$ | 현재·예측 시야 상태 |
| 2 | PadMotion | Tracking | $\hat v_p$, $\hat a_p$, $\hat\sigma_v$, $\hat\sigma_a$ | 패드 운동 추세 |
| 3 | DroneTranslation | Vehicle | $h$, $v_x$, $v_z$ | 드론 병진 상태 |
| 4 | DroneAttitude | Vehicle | $\theta$, $\omega$ | 카메라·추력 방향 상태 |
| 5 | RelativeTracking | Tracking | $\hat e_x$, $\widehat{\Delta v}_x$, $\hat\sigma_p$, $\hat\sigma_v$ | 상대 추종 오차 |
| 6 | TrackingCorrection | Tracking | $\hat e_x$, $\widehat{\Delta v}_x$, $\hat a_p$ | 수평 복구 방향·제동 요구 |
| 7 | ViewRecovery | Perception | $\Delta t_{\mathrm{loss}}$, $\hat\beta$, $\hat m$ | 재포착 필요도 |
| 8 | DescentEligibility | Safety | $c_k$, 위치·속도·자세 위험 | 추가 하강 허용도 |
| 9 | LandingInhibit | Safety | $b_{inh}$, $b_{ab}$, $\Delta t_{\mathrm{loss}}$, 불확실성 | 현재 하강 금지 |

| 그룹 $g$ | $\mathcal V_g$ | $\lvert\mathcal V_g\rvert$ |
|---|---|---:|
| 1 Perception | PadVisibility, ViewRecovery | 2 |
| 2 Tracking | PadMotion, RelativeTracking, TrackingCorrection | 3 |
| 3 Vehicle | DroneTranslation, DroneAttitude | 2 |
| 4 Safety | DescentEligibility, LandingInhibit | 2 |

### 2.3 관계와 간선

- 핵심: $\lvert\mathcal E\rvert=26$ (의미 간선 17 + 자기 간선 9), $\lvert\mathcal R\rvert=5$
- 관계 유형: informs(정보 전달), affects_visibility(시야 영향), supports(근거 제공), inhibits(억제), self(자기 유지)

| 출발 $i$ | 도착 $j$ | 관계 $r$ |
|---|---|---|
| PadMotion | RelativeTracking | informs |
| DroneTranslation | RelativeTracking | informs |
| DroneAttitude | PadVisibility | affects_visibility |
| DroneTranslation | PadVisibility | affects_visibility |
| PadMotion | TrackingCorrection | informs |
| RelativeTracking | TrackingCorrection | informs |
| PadVisibility | ViewRecovery | informs |
| DroneAttitude | ViewRecovery | informs |
| RelativeTracking | ViewRecovery | informs |
| PadVisibility | DescentEligibility | supports |
| RelativeTracking | DescentEligibility | informs |
| DroneTranslation | DescentEligibility | informs |
| DroneAttitude | DescentEligibility | informs |
| PadVisibility | LandingInhibit | informs |
| RelativeTracking | LandingInhibit | informs |
| DroneTranslation | LandingInhibit | informs |
| LandingInhibit | DescentEligibility | inhibits |
| 각 노드 $j$ | $j$ | self (9개) |

| 도착 노드 | 수신 간선 수 $\lvert\mathcal N(j)\rvert$ |
|---|---:|
| PadMotion, DroneTranslation, DroneAttitude | 1 (자기 간선만) |
| RelativeTracking, TrackingCorrection, PadVisibility | 3 |
| ViewRecovery, LandingInhibit | 4 |
| DescentEligibility | 6 |

- 순수 출발 노드: PadMotion·DroneTranslation·DroneAttitude, 의미 간선 수신 없음

## 3. 노드 특징 구성

- 핵심: 노드당 9개 동적 채널 + 3개 정적 채널, 크기·방향·신뢰·불확실성·추세·긴급도의 분리
- 핵심: 정규화 후 전체 원소 $[-1,1]$ clip

### 3.1 채널 정의

$$
x_i=[p_i,\tilde p_i,s_i,\tilde s_i,m_i,c_i,u_i,\tau_i,q_i,T_i,1,\kappa_i]^\top,\qquad X_t=[x_1,\dots,x_9]
$$

| 순번 $k$ | 기호 | 채널 | 의미 | 범위 |
|---:|---|---|---|---|
| 1 | $p_i$ | 주 크기 | 노드 주 의미의 크기 | $[0,1]$ |
| 2 | $\tilde p_i$ | 주 방향 | 주 의미의 부호 포함 값 | $[-1,1]$ |
| 3 | $s_i$ | 보조 크기 | 보조 의미의 크기 | $[-1,1]$ |
| 4 | $\tilde s_i$ | 보조 방향 | 보조 의미의 부호 포함 값 | $[-1,1]$ |
| 5 | $m_i$ | 유효성 | 측정·추정 유효 여부 | $[0,1]$ |
| 6 | $c_i$ | 신뢰도 | 검출·추적 신뢰도 | $[0,1]$ |
| 7 | $u_i$ | 불확실성 | 위치·속도·가속도·상실 불확실성 | $[0,1]$ |
| 8 | $\tau_i$ | 추세 | 변화 방향 | $[-1,1]$ |
| 9 | $q_i$ | 긴급도 | FOV·복구·금지 긴급도 | $[0,1]$ |
| 10 | $T_i$ | 잔여 시간 | $T_{rem}/T_{\max}$, 전 노드 공통 | $[0,1]$ |
| 11 | 1 | 상수 | 전 노드 공통 | 1 |
| 12 | $\kappa_i$ | 유형 식별 | $i/9$ | $(0,1]$ |

- 채널 기호의 노드 첨자 $i$: 상태 $s_t$·문맥 $c_t$의 시간 첨자 $t$와 구분
- $x_{i,k}$: $x_i$의 $k$번째 원소, 사전학습 목적식 표기 전용

### 3.2 정규화 중간량

- 핵심: 선형 비율 포화 $\min(\lvert y\rvert/y_0,1)$와 부호 비율 $y/y_0$ 적용, 부드러운 포화 $y/(\lvert y\rvert+y_0)$ 미적용
- $y$: 원 관측량, $y_0$: 기준 스케일

| 기호 | 정의 | 의미 |
|---|---|---|
| $\bar\Delta_{\mathrm{loss}}$ | $\min(\Delta t_{\mathrm{loss}}/T_{pl},1)$, $T_{pl}=3\,\mathrm{s}$ | 정규화 미검출 경과 시간 |
| $\bar\sigma_p,\bar\sigma_v,\bar\sigma_a$ | $\min(\hat\sigma_p/5,1)$, $\min(\hat\sigma_v/5,1)$, $\min(\hat\sigma_a/3,1)$ | 정규화 추정 불확실성 |
| $\bar m$ | $\max(0,-\hat m)/(\varphi/2)$ | 예측 FOV 이탈 긴급도 |
| $R_x$ | $\min(\lvert\hat e_x\rvert/3,1)$ | 수평 위치 위험 |
| $R_v$ | $\min(\lvert\widehat{\Delta v}_x\rvert/3,1)$ | 상대 속도 위험 |
| $R_\theta$ | $\min(\lvert\theta\rvert/\theta_{\max},1)$ | 자세 위험 |
| $R_\omega$ | $\min(\lvert\omega\rvert/\omega_{\max},1)$ | 자세각속도 위험 |
| $\bar c$ | $c_k\,\iota$ | 추적 신뢰도 |
| $e_D$ | $\bar c\,(1-R_x)(1-R_v)(1-R_\theta)(1-R_\omega)(1-b_{inh})$ | 하강 근거 |
| $n_R$ | $\min\!\big(1,\max(1-d_k,\bar\Delta_{\mathrm{loss}},\bar m)\big)$ | 재포착 필요도 |
| $I_{inh}$ | $\max(b_{inh},b_{ab},\bar\Delta_{\mathrm{loss}},\bar\sigma_p,\bar\sigma_v)$ | 하강 금지 수준 |
| $y_c$ | $\tanh\!\big(\hat e_x/3+0.5\,\widehat{\Delta v}_x/3\big)$ | 부호 포함 수평 보정 요구 |
| $T_{rem}$ | $\max(0,T_d-t)$ | 잔여 임무 시간 |

- 단위 기준: 위치 3 m, 상대 속도 3 m/s, 패드 속도 10 m/s, 패드 가속도 2 m/s², 고도 8 m, $v_{x,\max}=10$ m/s, $v_{z,\max}=1.5$ m/s
- $\theta=\mathrm{atan2}(\sin\theta,\cos\theta)$ 복원 후 사용

### 3.3 노드별 동적 채널

| 노드 | $p_i$ | $\tilde p_i$ | $s_i$ | $\tilde s_i$ | $m_i$ | $c_i$ | $u_i$ | $\tau_i$ | $q_i$ |
|---|---|---|---|---|---|---|---|---|---|
| PadVisibility | $d_k$ | $\tilde\beta_k$ | $\hat\beta$ | $\hat m$ | $d_\beta$ | $c_k$ | $\bar\Delta_{\mathrm{loss}}$ | $\hat\beta$ | $\bar m$ |
| PadMotion | $\min(\lvert\hat v_p\rvert/10,1)$ | $\hat v_p/10$ | $\min(\lvert\hat a_p\rvert/2,1)$ | $\hat a_p/2$ | $\iota$ | $\bar c$ | $\max(\bar\sigma_v,\bar\sigma_a)$ | $\hat a_p/2$ | $\bar\sigma_a$ |
| DroneTranslation | $\min(h/8,1)$ | $v_z/v_{z,\max}$ | $\min(\lvert v_x\rvert/v_{x,\max},1)$ | $v_x/v_{x,\max}$ | 1 | 1 | 0 | $v_z/v_{z,\max}$ | 0 |
| DroneAttitude | $R_\theta$ | $\theta/\theta_{\max}$ | $R_\omega$ | $\omega/\omega_{\max}$ | 1 | 1 | 0 | $\omega/\omega_{\max}$ | $R_\theta$ |
| RelativeTracking | $R_x$ | $\hat e_x/3$ | $R_v$ | $\widehat{\Delta v}_x/3$ | $\iota$ | $\bar c$ | $\max(\bar\sigma_p,\bar\sigma_v)$ | $\widehat{\Delta v}_x/3$ | $\bar m$ |
| TrackingCorrection | $\lvert y_c\rvert$ | $y_c$ | $R_v$ | $-\widehat{\Delta v}_x/3$ | $\iota$ | $\bar c$ | $\max(\bar\sigma_p,\bar\sigma_v)$ | $\hat a_p/2$ | $R_x$ |
| ViewRecovery | $n_R$ | $-\mathrm{sgn}(\hat\beta)\,n_R$ | $\bar m$ | $\hat m/(\varphi/2)$ | $\iota$ | $\bar c$ | $\max(\bar\Delta_{\mathrm{loss}},\bar\sigma_p)$ | $\hat\beta/(\varphi/2)$ | $n_R$ |
| DescentEligibility | $e_D$ | $e_D$ | $1-R_v$ | $-R_v$ | $\iota$ | $\bar c$ | $\max(\bar\sigma_p,\bar\sigma_v,\bar\Delta_{\mathrm{loss}})$ | $v_z/v_{z,\max}$ | $1-e_D$ |
| LandingInhibit | $I_{inh}$ | $b_{ab}$ | $\bar\Delta_{\mathrm{loss}}$ | $b_{inh}$ | 1 | 1 | $\max(\bar\sigma_p,\bar\sigma_v,\bar\Delta_{\mathrm{loss}})$ | $b_{ab}$ | $I_{inh}$ |

$$
X_t\leftarrow\mathrm{clip}(X_t,-1,1),\qquad s_t=\mathrm{vec}(X_t)\in\mathbb{R}^{108}
$$

- bearing·FOV 여유 원값 $\tilde\beta_k,\hat\beta,\hat m$: 라디안 단위, 시야각 $\varphi$ 내 $\lvert\cdot\rvert<1$
- 설계 효과: 위험 크기와 좌우 방향 분리, 신뢰도와 불확실성 분리, 현재 가시성과 예측 FOV 분리, 현재 값과 변화 추세 분리

## 4. 비교 상태 표현

- 핵심: 세 표현의 동일 원천 $o_t$, 차이는 의미 변환과 관계 구조의 유무

| 표현 | 정책 입력 | Actor 평균 | Critic | 비교 목적 |
|---|---|---|---|---|
| 저수준 | $o_t\in\mathbb{R}^{26}$ | $f_\pi(o_t)$ | $f_V(o_t)$ | 의미 변환 없는 기준 |
| semantic-flat | $s_t\in\mathbb{R}^{108}$ | $f_\pi(s_t)$ | $f_V(s_t)$ | 의미 특징 효과 분리 |
| R-GAT | $[s_t;\,c_t]\in\mathbb{R}^{112}$ | $f_\pi(s_t)+\tilde\delta_t$ | $f_V(s_t)+w_V^\top c_t$ | 관계 구조 추가 효과 분리 |

- semantic-flat과 R-GAT의 $f_\pi,f_V$: 동일 구조·동일 초기화 난수
- 초기 $c_t=0$ 조건의 R-GAT 출력: semantic-flat 출력과 정확히 동일

## 5. R-GAT 부호화

- 핵심: 단일층 관계형 attention, 관계 유형 무관 수신 노드 단위 공동 softmax, 자기 노드 선형 갱신 결합

### 5.1 attention logit

$$
z_i^{(r)}=W_r x_i,\qquad W_r\in\mathbb{R}^{8\times12},\qquad \rho_r\in\mathbb{R}^{4}
$$

$$
e_{ij}^{(r)}=\mathrm{LeakyReLU}_{0.2}\!\left(a_r^\top\big[z_i^{(r)}\,\Vert\,z_j^{(r)}\,\Vert\,\rho_r\big]\right),\qquad a_r\in\mathbb{R}^{20}
$$

$$
\mathrm{LeakyReLU}_{0.2}(y)=0.6\,y+0.4\,\lvert y\rvert
$$

- $z_i^{(r)}$: 출발 노드 사영, $z_j^{(r)}$: 도착 노드 사영, 동일 관계 행렬 $W_r$ 사용
- $a_r$ 분할: 출발 8 + 도착 8 + 관계 4, 관계 항 $a_r^\top\rho_r$의 관계별 상수 편향 역할

### 5.2 정규화

$$
\alpha_{ij}^{(r)}=\frac{\exp\!\big(e_{ij}^{(r)}\big)}{\displaystyle\sum_{(k,r')\in\mathcal N(j)}\exp\!\big(e_{kj}^{(r')}\big)+10^{-9}}
$$

- $\mathcal N(j)$: 관계 유형 무관 $j$의 전체 수신 간선, 자기 간선 $(j,\mathrm{self})$ 포함
- 관계별 분리 softmax 아님, 관계 유형 간 attention 경쟁 구조
- $\sum_{(i,r)\in\mathcal N(j)}\alpha_{ij}^{(r)}=Z_j/(Z_j+10^{-9})<1$, $Z_j$: 분모의 지수합
- 수신 간선이 자기 간선뿐인 노드: $\alpha_{jj}^{(\mathrm{self})}\approx1$ 고정

### 5.3 노드 갱신

$$
h_j=\tanh\!\left(\sum_{(i,r)\in\mathcal N(j)}\alpha_{ij}^{(r)}W_r x_i+W_0x_j+b_0\right),\qquad h_j\in\mathbb{R}^{8},\quad W_0\in\mathbb{R}^{8\times12},\quad b_0\in\mathbb{R}^{8}
$$

- message passing 1층, 1-hop 이웃 정보만 반영
- $W_0x_j+b_0$: attention과 독립인 자기 노드 국소 경로

### 5.4 그룹 readout

$$
\bar h_g=\frac{1}{\lvert\mathcal V_g\rvert}\sum_{i\in\mathcal V_g}h_i,\qquad g=1,\dots,4
$$

$$
c_t=\tanh\!\Big(W_c\big[\bar h_1;\bar h_2;\bar h_3;\bar h_4\big]+b_c\Big),\qquad W_c\in\mathbb{R}^{4\times32},\quad b_c\in\mathbb{R}^{4}
$$

- 초기화: $W_c=0$, $b_c=0$, 따라서 초기 $c_t=0$
- 기타 부호화 파라미터 초기화: 표준편차 0.12 Gaussian, $b_0=0$
- Actor·Critic 부호화기: 동일 사전학습 부호화기에서 출발한 별도 파라미터

## 6. Actor/Critic 결합

- 핵심: raw semantic 경로의 완전 보존, 관계 경로의 additive residual 한정
- 핵심: 관계 residual의 추가 하강 성분만 $g_t$로 축소

### 6.1 Actor

$$
\mu_t=f_\pi(s_t)+\tilde\delta_t,\qquad \delta_t=W_\pi c_t,\quad W_\pi\in\mathbb{R}^{2\times4}
$$

$$
u_t\sim\mathcal N\!\big(\mu_t,\mathrm{diag}(\sigma_\pi^2)\big)
$$

- $\delta_t=[\delta_{x,t},\delta_{z,t}]^\top$: 수평·수직 residual
- 수직 부호 약속: 음수 추가 하강, 양수 상승·제동

### 6.2 하강 허용 gate

$$
g_t=\mathrm{clip}\big(p_8,0,1\big)=e_D
$$

$$
\tilde\delta_{x,t}=\delta_{x,t},\qquad
\tilde\delta_{z,t}=
\begin{cases}
\delta_{z,t}, & \delta_{z,t}\ge0\\
g_t\,\delta_{z,t}, & \delta_{z,t}<0
\end{cases}
$$

- $p_8$: DescentEligibility 노드 주 크기 채널
- $b_{inh}=1$ 시 $g_t=0$, 관계 경로의 추가 하강 완전 차단
- 상승·제동 residual: 무조건 통과
- 역전파 기울기: $\partial\tilde\delta_{z,t}/\partial\delta_{z,t}=g_t$ ($\delta_{z,t}<0$), 1 (그 외), $g_t$는 입력 상수 취급
- gate 적용 범위: 관계 residual 한정, $f_\pi(s_t)$ 미적용
- gate 활성 판정: $\mathbb 1[\delta_{z,t}<0\wedge g_t<1]$

### 6.3 Critic

$$
V_\phi(s_t)=f_V(s_t)+w_V^\top c_t,\qquad w_V\in\mathbb{R}^{4}
$$

- Critic residual gate 미적용
- 관계 head 초기화: $W_\pi,w_V$ 원소 $0.05\,\mathcal N(0,1)$, 0 아닌 초기값
- 0 아닌 head 초기값 이유: $c_t=0$ 상태에서도 $W_c$로의 기울기 전달 확보

## 7. 사전학습: masked 동시점 재구성

- 핵심: 동일 시점 노드 특징 복원만의 자기지도 목적, 행동·보상·결과·미래 표적 없음

$$
\tilde X_t=X_t\odot(1-M),\qquad h_i=\mathrm{Enc}_{\Theta}(\tilde X_t)_i
$$

$$
\min_{\Theta,\,W_d,\,b_d}\;\frac{1}{\lvert M\rvert}\sum_{(k,i):\,M_{k,i}=1}\Big(\big(W_dh_i+b_d\big)_k-x_{i,k}\Big)^2
$$

- $M\in\{0,1\}^{12\times9}$: 동적 채널 $k\le9$만 $\mathrm{Bernoulli}(0.25)$, 채널 10~12 mask 제외, 표본당 최소 1개 mask
- $\Theta=\{W_r,a_r,\rho_r\}_{r\in\mathcal R}\cup\{W_0,b_0\}$, $W_c,b_c$ 제외
- 선형 decoder: $W_d\in\mathbb{R}^{9\times8}$, $b_d\in\mathbb{R}^9$
- 표본 방문 행동: $\tanh(0.5\,n_t)$, $n_t\sim\mathcal N(0,I_2)$, 최적화 전 폐기
- 학습 후 Actor·Critic 부호화기 동일 초기값 사용

| 설정 | 값 |
|---|---:|
| 학습 seed episode | 12 (학습 seed 집합 $\mathcal S_{tr}$ 한정) |
| episode당 최대 결정 수 | 80 |
| epoch | 8 |
| batch | 128 |
| mask 확률 | 0.25 |
| Adam 학습률 | $10^{-3}$ |

- $\mathcal S_{tr}\cap\mathcal S_{val}=\varnothing$, $\mathcal S_{tr}\cap\mathcal S_{te}=\varnothing$ 강제

## 8. 2단계 PPO

- 핵심: 1단계 raw semantic 정책 학습, 2단계 raw 경로 고정 상태의 관계 경로 한정 적응

| 구분 | 1단계 raw semantic | 2단계 관계 적응 |
|---|---|---|
| 반복 구간 (전체 2500회) | 1~2250 (90%) | 2251~2500 (10%) |
| $f_\pi$, $\sigma_\pi$, $f_V$ | 학습 | 고정 |
| $W_r$, $a_r$ | 고정 | 학습 |
| $W_c$, $b_c$ | 고정 ($=0$) | 학습 |
| $W_\pi$, $w_V$ | 기울기 0 ($c_t=0$) | 학습 |
| $\rho_r$, $W_0$, $b_0$ | 고정 | 고정 |
| checkpoint 교체 조건 | $J>J_{best}$ | $J>J_{best}+5.0$ |

- 1단계 등가성: $c_t=0$이므로 semantic-flat PPO와 동일한 제어 문제
- 2단계 고정 이유: 관계 경로 기여의 raw 정책 개선과의 혼입 방지
- $\rho_r,W_0,b_0$ 고정 이유: 사전학습된 관계 불변 변환 보존, 상태 의존 attention·readout만 적응
- checkpoint 선택 점수:

$$
J=1000\,p_s-2500\,p_u-10\,p_\tau-100\,p_a+\bar G
$$

- checkpoint 후보 자격: 커리큘럼 난이도 $\ell=1$ 도달 이후
- 위험 접촉 1건 상쇄 조건: 성공 2건 초과 필요

## 9. 관계 경로 활성화와 검증 guard

- 핵심: 관계 경로 비활성 checkpoint에 한해 raw 경로 고정 관계 전용 PPO 수행
- 핵심: 검증 결과율 비악화를 만족하는 최대 readout 배율 $\nu_{rel}$ 채택, 미통과 시 기준 checkpoint 유지

### 9.1 활성 판정

$$
\mathrm{Active}=\mathbb 1\!\Big[\min\big(\lVert W_c^{\pi}\rVert_F,\lVert W_c^{V}\rVert_F,\lVert W_\pi\rVert_F,\lVert w_V\rVert_2\big)>10^{-10}\Big]
$$

- $W_c^{\pi},W_c^{V}$: Actor·Critic 부호화기 readout 행렬

### 9.2 알고리즘 1: 관계 경로 활성화

1. 입력: 선택 checkpoint $\mathcal A_0$ (기준점), 활성 판정 결과
2. $\mathrm{Active}(\mathcal A_0)=1$ 시 $\mathcal A_0$ 그대로 반환 후 종료
3. 2단계 설정의 관계 전용 PPO 구성: 25회 반복, 반복당 6 episode, PPO epoch 4, value warmup 0, 커리큘럼 비적용
4. 학습 중 검증: 20 episode
5. $f_\pi,\sigma_\pi,f_V$ 불변 확인, 변경 시 중단
6. 학습 결과 후보 $\mathcal A_1$의 알고리즘 2 전달
7. 출력: 알고리즘 2 채택 결과와 활성 판정 결과

### 9.3 알고리즘 2: 성능 보존 guard

1. 입력: 기준점 $\mathcal A_0$, 후보 $\mathcal A_1$, 고정 검증 seed 집합 $\mathcal S_{val}$
2. 기준점 평가: $p_s^0,p_u^0,p_a^0,p_\tau^0,\bar G^0,J^0$
3. 배율 격자 $\nu_{rel}\in\{1,0.75,0.5,0.25,0.1,0.05,0.02,0.01,0.005,0.002,0.001\}$의 큰 값부터 순회
4. 후보 축소: Actor·Critic 공통 $W_c\leftarrow\nu_{rel}W_c$, $b_c\leftarrow\nu_{rel}b_c$, 그 외 파라미터 불변
5. 결과율 조건: $p_s\ge p_s^0$, $p_u\le p_u^0$, $p_a\le p_a^0$, $p_\tau\le p_\tau^0$, 허용오차 0
6. 점수 조건: $\bar G\ge\bar G^0-0.25$, $J\ge J^0-0.25$
7. residual 신뢰 구간 조건: $10^{-6}\le\big\lVert\big[\overline{\lvert\tilde\delta_x\rvert},\overline{\lvert\tilde\delta_z\rvert}\big]\big\rVert_2\le0.005$
8. 활성 조건: 축소 후 $\mathrm{Active}=1$
9. 5~8 동시 만족 첫 배율 채택 후 종료
10. 전 배율 미통과 시 $\mathcal A_0$ 유지
11. 시험 seed 집합 $\mathcal S_{te}$: 선택 과정 사용 제외

- $\overline{\lvert\tilde\delta_a\rvert}$: episode 내 결정 평균 절대 residual의 episode 평균, $a\in\{x,z\}$
- 배율 축소 근거: $c_t$의 크기 축소에 따른 관계 residual의 연속적 축소, raw 경로 불변

## 10. 최종 checkpoint 감사

- 핵심: 관계 경로 활성 확인, 결과율 동일 유지, 관계 영향량 $10^{-5}$ 수준

| 감사 항목 | Actor | Critic |
|---|---:|---:|
| readout norm $\lVert W_c\rVert_F$ | 0.0001665 | 0.0006056 |
| 관계 head norm ($\lVert W_\pi\rVert_F$, $\lVert w_V\rVert_2$) | 0.1517 | 0.4792 |
| 관계 경로 | 활성 | 활성 |
| 채택 배율 $\nu_{rel}$ | 0.001 | 0.001 |

- raw semantic Actor/Critic 기준점: 완전 고정
- 추가 최적화 대상: attention·readout·관계 head 한정
- test 결과율 ($p_s/p_u/p_a/p_\tau$): 72%/9%/14%/5% 유지
- 평균 return $\bar G$: 17.873→17.930
- 평균 절대 관계 residual: 수평 $1.27\times10^{-5}$, 수직 $3.86\times10^{-5}$
- 판정: 관계 경로 활성과 작은 관계 영향량의 동시 확인

![R-GAT 정책 추적](assets/paper/paper_ontology.png)

- 그림: 시나리오별 $g_t$, $b_{inh}$, $d_k$, gate 활성 지시자, 수직 관계 residual $\tilde\delta_{z,t}$ ($\times10^{-5}$ 축)의 시간 궤적

## 11. 이론적 근거

- 핵심: 초기 동등성·단조 안전성·정보 동등성에 기반한 관계 효과의 분리 측정 구조
- 초기 동등성: $W_c=0\Rightarrow c_t=0\Rightarrow\mu_t=f_\pi(s_t)$, $V_\phi=f_V(s_t)$, semantic-flat과 동일 정책 출발
- 단조 안전성: $\lvert\tilde\delta_{z,t}\rvert\le\lvert\delta_{z,t}\rvert$, 추가 하강 크기 상한 $g_t\lvert\delta_{z,t}\rvert$
- 하강 금지 일관성: $b_{inh}=1\Rightarrow e_D=0\Rightarrow g_t=0$, 관계 경로의 금지 상태 하강 유도 불가
- 정보 동등성: $c_t$는 $s_t$의 결정적 함수, 신규 정보가 아닌 관계 귀납 편향만 추가
- 인과성: $X_t=\mathcal{F}(o_t)$, 미래·참값 비의존, 실시간 순전파만으로 계산
- 관계 경쟁: 공동 softmax로 관계 유형 간 상대 중요도의 직접 비교 가능
- 국소 경로 보존: $W_0x_j+b_0$로 attention 붕괴 시에도 노드 자기 정보 유지
- 단계 분리: 2단계의 raw 경로 고정으로 성능 변화의 관계 경로 귀속
- guard 단조성: 결과율 비악화 조건의 허용오차 0, 기준점 대비 열화 없는 후보만 채택

## 12. 한계

- 핵심: 현재 결과의 범위는 관계 경로 활성과 성능 보존, 관계 구조의 성능 기여 입증 아님
- 작은 관계 영향량: $\nu_{rel}=0.001$, residual $10^{-5}$ 수준, 행동 변화의 실질 영향 미미
- 단일층 한계: 1-hop 전달만 반영, 2-hop 이상 의미 경로의 직접 합성 불가
- 순수 출발 노드: PadMotion·DroneTranslation·DroneAttitude의 attention 자유도 없음
- 선형 비율 포화: 기준 스케일 초과 구간의 크기 해상도 소실
- gate 범위: $f_\pi(s_t)$의 하강 성분 미제약, 하강 안전성은 공통 안전 감독기 $\Pi_s$ 의존
- 검증 seed 의존: guard 결과의 검증 집합 크기·구성 의존
- 비교 범위: 결과율 유지 확인까지, 관계 경로의 통계적 우월성 검정 제외
