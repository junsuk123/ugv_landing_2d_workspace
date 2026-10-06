# 기호 정의

## 요약

- 전 문서 공통 기호 체계
- 시간 첨자 $t$: 정책 결정 시점, 첨자 $k$: 물리 적분 시점
- 벡터 굵게 표기 생략, 차원은 $\in\mathbb{R}^n$으로 명시
- 하위 문서 고유 기호: 해당 문서 첫 등장 위치에서 정의

## 시간·주기

| 기호 | 의미 | 값 |
|---|---|---|
| $t$ | 정책 결정 시점 첨자 | — |
| $k$ | 물리 적분 시점 첨자 | — |
| $\Delta t_p$ | 정책 결정 주기 | 0.10 s |
| $\Delta t_s$ | 물리 적분·센서 주기 | 0.01 s |
| $\Delta t$ | 실제 결정 경과 시간 (종료 사건 시 단축) | $\le\Delta t_p$ |
| $T_{\max}$ | 최대 임무 시간 | 70 s |
| $T_d$ | 시나리오 마감 시간 $T_1+T_2+T_3$ | $\le T_{\max}$ |

## 드론·패드 상태

| 기호 | 의미 |
|---|---|
| $\xi=[x,z,v_x,v_z,\theta,\omega,F]^\top$ | 드론 물리 상태 (위치·속도·pitch·pitch rate·추력) |
| $m,\;g$ | 질량, 중력가속도 |
| $\theta_{\max},\;\omega_{\max}$ | pitch·pitch rate 한계 |
| $\omega_n,\;\zeta$ | pitch 내부 루프 고유진동수·감쇠비 |
| $\tau_F$ | 추력 1차 지연 시정수 |
| $\kappa_F$ | 최대 추력중량비 |
| $x_p,\;v_p,\;a_p$ | 패드 위치·속도·가속도 |
| $z_p$ | 패드 면 높이 |
| $L_{pad}$ | 패드 반길이 |
| $e_x=x_p-x$ | 수평 상대 오차 |
| $h=z-z_p$ | 패드 상대 고도 |
| $\Delta v_x=v_p-v_x$ | 수평 상대 속도 |

## 시나리오

| 기호 | 의미 |
|---|---|
| $\sigma=(v_1,a_2,T_1,T_2,T_3,h_0)$ | 시나리오 파라미터 |
| $v_1$ | 1구간 등속 속도 |
| $a_2$ | 2구간 등가속도 |
| $T_1,T_2,T_3$ | 구간 지속시간 |
| $v_3=v_1+a_2T_2$ | 3구간 등속 속도 |
| $h_0$ | 초기 상대 고도 |
| $\mathcal{D}$ | 시나리오 분포 |
| $\bar v_d,\;v_{res}$ | 드론 지속 비행속도(10 m/s)·속도 예비 margin(0.5 m/s) |
| $\Xi_t$ | POMDP 은닉 환경 상태 |
| $\mathcal{W}$ | 에피소드 시작 전 추출 센서·외란 일정 |

## 행동·안전 감독기

| 기호 | 의미 |
|---|---|
| $u_t\in\mathbb{R}^2$ | Gaussian 정책 원시 행동 |
| $\bar a_t=\tanh(u_t)\in[-1,1]^2$ | 정규화 행동 |
| $a_t=\mathrm{diag}(a_{x,\max},a_{z,\max})\,\bar a_t$ | 요청 가속도 명령 |
| $\tilde a_k=\Pi_s(a_t,\xi_k,o_k)$ | 안전 감독기 적용 가속도 |
| $\theta^{sp},\;F^{sp}$ | pitch·추력 setpoint |
| $h_{stop}$ | 수직 정지 소요 고도 |
| $v_{down}=\max(0,-v_z)$ | 하강 속도 |
| $a_{brake}=(\kappa_F-1)g$ | 가용 수직 제동 가속도 |
| $t_{resp}$ | 감독기 응답 지연 가정 |

## 센서·추정

| 기호 | 의미 |
|---|---|
| $\varphi$ | 카메라 전체 시야각 (FOV) |
| $R_{\max}$ | 최대 검출 거리 |
| $\beta$ | 카메라 광축 기준 패드 bearing |
| $d_k\in\{0,1\}$ | 검출 여부 |
| $\tilde e_{x,k},\;\tilde\beta_k$ | 잡음 포함 상대 위치·bearing 측정 |
| $\sigma_e,\;\sigma_\beta$ | 측정 잡음 표준편차 |
| $c_k$ | 검출 신뢰도 |
| $\delta_k\in\{0,1\}$ | 센서 dropout 지시자 |
| $w_\theta$ | pitch rate 외란 |
| $\hat\chi=[\hat x_p,\hat v_p,\hat a_p]^\top$ | 패드 운동 추정 상태 |
| $k_p,\;k_v,\;k_a$ | 위치·속도·가속도 innovation 이득 |
| $\hat\sigma_p,\hat\sigma_v,\hat\sigma_a$ | 추정 불확실성 |
| $\nu_k$ | innovation |
| $\tau_a$ | 가속도 추정 감쇠 시정수 |
| $\Delta t_{\mathrm{loss}}$ | 마지막 검출 이후 경과 시간 |
| $\Delta,\;\Delta t_m$ | 직전 추정 갱신·직전 채택 측정 이후 경과 시간 |

## 관측·그래프 상태

| 기호 | 의미 |
|---|---|
| $o_t\in\mathbb{R}^{26}$ | causal 관측 패킷 |
| $\mathcal{G}=(\mathcal{V},\mathcal{E},\mathcal{R})$ | 온톨로지 상황 그래프 |
| $\lvert\mathcal{V}\rvert=9,\;\lvert\mathcal{E}\rvert=26,\;\lvert\mathcal{R}\rvert=5$ | 노드·간선·관계 유형 수 |
| $X_t\in\mathbb{R}^{12\times9}$ | 노드 특징 행렬, 열 $x_i\in\mathbb{R}^{12}$ |
| $X_t=\mathcal{F}(o_t)$ | 학습 파라미터 없는 노드 특징 사상 |
| $s_t=\mathrm{vec}(X_t)\in\mathbb{R}^{108}$ | raw semantic 상태 |
| $x_i=[p_i,\tilde p_i,s_i,\tilde s_i,m_i,c_i,u_i,\tau_i,q_i,T_i,1,\kappa_i]^\top$ | 노드 특징 12채널 (주요·부호 주요·보조·부호 보조·유효 mask·신뢰도·불확실성·추세·긴급도·잔여시간·bias·유형) |
| $\kappa_i$ | 노드 유형 식별 특징 |
| $\mathcal{N}(j)$ | 노드 $j$로 들어오는 간선 집합 (자기 간선 포함) |
| $W_r,\;a_r,\;\rho_r$ | 관계 $r$의 사영 행렬·attention 벡터·관계 임베딩 |
| $e^{(r)}_{ij},\;\alpha^{(r)}_{ij}$ | attention logit·계수 |
| $W_0,\;b_0$ | 자기 노드 갱신 파라미터 |
| $h_j\in\mathbb{R}^{8}$ | 갱신 노드 임베딩 |
| $\bar h_g$ | 의미 그룹 $g$ 평균 임베딩 |
| $W_c,\;b_c$ | 그룹 readout 파라미터 |
| $c_t\in\mathbb{R}^{4}$ | 관계 문맥 벡터 |

## 정책·학습

| 기호 | 의미 |
|---|---|
| $\pi_\theta(u\mid s)$ | Gaussian Actor, 평균 $\mu_t$·표준편차 $\sigma_\pi$ |
| $V_\phi(s)$ | Critic |
| $f_\pi,\;f_V$ | raw semantic MLP |
| $\delta_t=W_\pi c_t\in\mathbb{R}^2$ | 관계 residual |
| $g_t\in[0,1]$ | 하강 허용 gate (DescentEligibility 노드 primary 특징) |
| $\tilde\delta_t$ | gate 적용 관계 residual |
| $w_V\in\mathbb{R}^4$ | Critic 관계 가중치 |
| $\nu_{rel}$ | 관계 readout 축소 배율 |
| $r_t$ | 결정 단위 보상 |
| $B_t$ | 종료 보상 (비종료 시 0) |
| $c_{goal},c_{view},c_{ctrl}$ | 목표·시야·제어 비용 |
| $w_g,w_v,w_u,w_r,w_p$ | 보상 항 가중치 |
| $T_{ref}$ | 비용 시간 정규화 기준 |
| $\psi_t$ | 착륙 준비도 |
| $\varpi$ | 목표 비용 수평 비중 |
| $h_{td},v_{x,td},v_{z,td},\theta_{td},\omega_{td}$ | 접촉 높이·안전 접촉 속도·자세 한계 |
| $\Phi_t$ | shaping potential |
| $\eta_t$ | TD 오차 |
| $\varrho_t$ | PPO 확률비 |
| $\gamma_{\Delta t}=\exp(-\Delta t/\tau_\gamma)$ | 시간 기반 할인율 |
| $\lambda$ | GAE 계수 |
| $\epsilon$ | PPO clip 비율 |
| $\hat A_t$ | 정규화 advantage |
| $\ell\in[0,1]$ | 커리큘럼 난이도 |
| $J$ | checkpoint 선택 점수 |

## 평가

| 기호 | 의미 |
|---|---|
| $p_s,\;p_u,\;p_a,\;p_\tau$ | 성공·위험 접촉·안전 중단·시간 초과율 |
| $\bar G$ | 비할인 평균 return |
| $SI=\frac{100}{6}(Q_x+Q_v+Q_{fov}+Q_{sup}+Q_\theta+Q_j)$ | 안정성 지수, $Q_\ast\in[0,1]$ 6개 성분 |
| $m_v,\;m_a,\;m_T$ | 속도·가속도·시간 authority margin |
| $\mathcal{S}_{tr},\;\mathcal{S}_{val},\;\mathcal{S}_{te}$ | 학습·검증·시험 seed 집합 |
