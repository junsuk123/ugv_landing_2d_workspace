# 연구 결과 보고

## 요약

- 현행성: 2026-10-06 산출, 하향 카메라·reward_v2·3비교군 계약 시점 결과. 전방 아래 마커 카메라·공통 관측·reward_v3(2026-10-08) 계약의 현행 결과는 [보상 설계](REWARD_RATIONALE.md) 11절
- 연구 질문: 동일 POMDP에서 상태 표현 구조만 바꾼 PPO 정책의 착륙 성능·안정성·추론 비용 차이
- 비교: Low-level 관측 벡터, Semantic-flat 온톨로지 특징, Ontology R-GAT 관계 문맥의 3개 상태 표현
- 시험 결과 ($\mathcal S_{te}$ 100 seed, 단일 학습 seed): 성공률 Semantic-flat 75% $\approx$ Low-level 74% $\approx$ R-GAT 72%, 위험 접촉률 Low-level 2% 최저
- 통계 판정: 세 모델 간 결과율 차이 모두 95% 신뢰구간 중첩 범위, 유의한 우열 판정 불가
- 대표 시나리오: R-GAT의 S1~S3 전 성공, S1·S3 안정성 지수 $SI$ 최고, Low-level의 S2·S3 안전 중단
- 관계 경로: 활성 상태 확인, 행동 residual $10^{-5}$ 수준, 관계 구조 고유 효과의 실증 미완료
- 추론 비용: 정책 추론 0.105~0.179 ms, 결정 주기 $\Delta t_p=100$ ms 대비 0.2% 미만
- 결론: 가설 H1 부분 지지, H2 미지지, H3 지지
- 평가 산출 시각: 2026-10-06 09:31 KST

## 1. 연구 질문

- 결론: 정보량 효과와 관계 구조 효과의 분리가 핵심 질문

| 번호 | 질문 |
|---|---|
| Q1 | 동일 센서 정보에서 의미 특징 추가의 착륙 결과 영향 |
| Q2 | 동일 의미 특징에 대한 typed relation 문맥의 추가 영향 |
| Q3 | 가시성 손실·패드 급가속 상황의 안정성 차이 |
| Q4 | 인과 온톨로지 그래프 정책의 실시간 추론 가능성 |
| Q5 | 은닉 참값 누수 없는 그래프 정책 구성 가능성 |

## 2. 가설

- 결론: 정보·구조·비용의 3개 가설 설정

| 가설 | 내용 | 대응 비교 |
|---|---|---|
| H1 | 의미 특징 상태의 성공률 증가·안전 중단 감소 | Semantic-flat vs Low-level |
| H2 | typed relation 문맥의 Semantic-flat 대비 추가 개선 | R-GAT vs Semantic-flat |
| H3 | 그래프 정책 추론 시간의 결정 주기 대비 무시 가능 수준 | 세 모델 추론 시간 |

## 3. 방법

### 3.1 공통 문제 정의

- 결론: 환경·관측·행동·보상·종료·학습 예산 전부 동일, 상태 표현 사상만 상이

![전체 파이프라인](../assets/pipeline.svg)

- 문제: 이동 UGV 패드 위 2D 드론 착륙의 POMDP
- 패드 운동: 등속–등가속–등속 3구간, $\sigma=(v_1,a_2,T_1,T_2,T_3,h_0)\sim\mathcal D$
- 관측: 카메라 검출·자기 상태 기반 인과 관측 패킷 $o_t\in\mathbb R^{26}$
- 행동: $\bar a_t=\tanh(u_t)$, 요청 가속도 $a_t=\mathrm{diag}(a_{x,\max},a_{z,\max})\bar a_t$
- 안전 감독기 $\Pi_s$: 세 모델 공통, 은닉 패드 참값 미사용
- 보상: 세 모델 동일 (3.3절)
- 학습: 모방학습 배제, 무작위 초기화 PPO, 동일 예산
- 정보 경계: 현재 자기 상태·현재 검출·인과 추적 추정·관측 경과 시간·불확실성·직전 행동·공개 안전 상태만 허용
- 금지 정보: 은닉 패드 참값, 미래 궤적, 시나리오 구간 라벨, 보상·return·advantage, 종료 결과, 교사 행동

### 3.2 상태 표현 비교군

- 결론: Low-level → Semantic-flat 비교로 Q1, Semantic-flat → R-GAT 비교로 Q2 분리

| 모델 | 정책 입력 | 파라미터 수 | 비교 목적 |
|---|---|---:|---|
| Low-level PPO | 정규화 $o_t$ | 7,445 | 저수준 기준 |
| Semantic-flat PPO | $s_t=\mathrm{vec}(X_t)\in\mathbb R^{108}$ | 15,317 | 의미 정보 효과 |
| Ontology R-GAT PPO | $s_t$ + 관계 문맥 $c_t\in\mathbb R^4$ | 17,001 | 관계 구조 효과 |

![온톨로지 상황 그래프](../assets/ontology_graph.svg)

- 그래프: $\lvert\mathcal V\rvert=9$, $\lvert\mathcal E\rvert=26$ (의미 간선 17·자기 간선 9), $\lvert\mathcal R\rvert=5$
- 의미 그룹: Perception (PadVisibility, ViewRecovery), Tracking (PadMotion, RelativeTracking, TrackingCorrection), Vehicle (DroneTranslation, DroneAttitude), Safety (DescentEligibility, LandingInhibit)
- 관계 유형: informs, affects_visibility, supports, inhibits, self

R-GAT 관계 문맥:

$$
e^{(r)}_{ij}=\mathrm{LeakyReLU}\!\left(a_r^\top\left[W_rx_i\,\Vert\,W_rx_j\,\Vert\,\rho_r\right]\right),
\qquad
h_j=\tanh\!\Big(\sum_{(i,r)\in\mathcal N(j)}\alpha^{(r)}_{ij}W_rx_i+W_0x_j+b_0\Big)
$$

$$
c_t=\tanh\!\left(W_c\left[\bar h_g\right]_{g}+b_c\right)
$$

Actor·Critic 결합:

$$
\mu_t=f_\pi(s_t)+\tilde\delta_t,
\qquad
V_\phi(s_t)=f_V(s_t)+w_V^\top c_t,
\qquad
\delta_t=W_\pi c_t
$$

$$
\tilde\delta_{z,t}=\begin{cases}\delta_{z,t}, & \delta_{z,t}\ge0,\\ g_t\,\delta_{z,t}, & \delta_{z,t}<0,\end{cases}
\qquad
\tilde\delta_{x,t}=\delta_{x,t}
$$

- $\delta_{x,t},\delta_{z,t}$: 관계 residual의 수평·수직 성분 (신규 기호)
- $g_t$: DescentEligibility primary 특징의 $[0,1]$ 절단값
- gate 원리: 추가 하강 residual만 하강 허용도 비례 축소, 상승·제동 residual 무제한
- raw bypass $f_\pi(s_t),f_V(s_t)$: Semantic-flat과 동일 입력·동일 구조의 기준 경로
- 관계 readout 축소: $(W_c,b_c)\leftarrow\nu_{rel}(W_c,b_c)$

### 3.3 보상 요약

- 결론: 종료 결과 순서를 보존하는 유계 비용·shaping 결합, 세 모델 동일

$$
r_t=B_t-\frac{\Delta t}{T_{ref}}\left(w_g c_{goal,t}+w_v c_{view,t}+w_u c_{ctrl,t}\right)+w_r(\psi_t-\psi_{t-1})+\gamma_{\Delta t}\Phi_t-\Phi_{t-1}
$$

| 항목 | 값 |
|---|---|
| $T_{ref},\;\tau_\gamma$ | 70 s, 70 s |
| $w_g,w_v,w_u,w_r,w_p$ | 2.0, 1.0, 0.25, 8.0, 2.0 |
| $\Phi_t$ | $-w_p c_{goal,t}$, 종료 시 0 |
| $B$ | SUCCESS +25, SAFE_ABORT −15, TASK_TIMEOUT −12, 실패 4종 −40 |
| 학습 커리큘럼 | 실패 보상 $-20-20\ell$, 검증·시험 −40 |

- $\psi_t$: 접지 한계 정규화 위험 지수의 지수 변환 readiness
- 상세 정의·이론 근거: 보상 설계 문서

## 4. 학습 절차

- 결론: 세 모델 동일 PPO 예산 2,500 iteration × 6 episode, R-GAT만 사전학습·관계 경로 활성화 단계 추가

알고리즘 (모델별 독립 실행, 단일 학습 seed):

1. 초기화: Actor·Critic 무작위 가중치, 모방학습 배제
2. R-GAT 사전학습: 현재 시점 노드 특징의 인과 masked reconstruction (12 episode, episode당 최대 80 결정, mask 확률 0.25, 8 epoch)
   - 행동·보상·결과·미래·참값 목표 배제
   - 이후 $\rho_r,W_0,b_0$ 고정
3. 반복 $i=1,\dots,2500$:
   1. 난이도 하한 갱신: $\ell\leftarrow\max\big(\ell,\ \min(1,\max(0,(i-750)/1250))\big)$
   2. batch 난이도 배정: easy 1 ($0$), bridge 1 ($\ell/2$), current 4 ($\ell$)
   3. 확률 정책 $\pi_\theta$로 6 episode 수집, 커리큘럼 완화 조건 적용
   4. advantage: 결정별 $\gamma_{\Delta t}$의 GAE, $\lambda=0.95$, batch 정규화 $\hat A_t$
   5. 갱신: 8 epoch × minibatch 256, clipped surrogate $\min\!\big(\varrho_t\hat A_t,\ \mathrm{clip}(\varrho_t,1-\epsilon,1+\epsilon)\hat A_t\big)$, $\epsilon=0.2$, 엔트로피 가중 0.0025, Critic 제곱 오차
   6. 최적화: Adam, Actor 학습률 $5\times10^{-4}$, Critic $10^{-3}$, 그래프 부호기 $3\times10^{-4}$, gradient norm 1.0 절단, log 표준편차 하한 −2.5
   7. 첫 2 iteration: Critic만 갱신
   8. R-GAT 구간 분리: $i\le2250$ 그래프 파라미터 고정 (raw 경로만 학습), $i>2250$ raw Actor·Critic 고정·그래프 파라미터만 적응
   9. 25 iteration마다: $\mathcal S_{val}$ 결정론 평가로 $J$ 산출, $\ell\ge1$ 자격 충족 시 최고 $J$ checkpoint 보관 (R-GAT 적응 구간은 개선 $>5.0$ 요구)
   10. 25 iteration마다: 현재 난이도 학습 착륙률 $\ge0.10$의 3창 연속 시 $\ell\leftarrow\min(1,\ell+0.10)$
4. R-GAT 관계 경로 활성화 (선택 checkpoint의 관계 readout 비활성 시):
   1. 기준점: 선택 checkpoint, raw Actor·Critic 고정
   2. 관계 전용 PPO: 25 iteration × 6 episode, 4 epoch, 커리큘럼 완화 해제
   3. 배율 탐색: $\nu_{rel}\in\{1,0.75,0.5,0.25,0.1,0.05,0.02,0.01,0.005,0.002,0.001\}$ 내림차순
   4. 수용 조건 ($\mathcal S_{val}$ 100 seed): 결과율 비열화 ($p_s$ 비감소, $p_u,p_a,p_\tau$ 비증가), $\bar G$·$J$ 감소 0.25 이내, 평균 절대 residual norm $\in[10^{-6},0.005]$, 관계 경로 활성
   5. 첫 수용 배율 채택, 전부 미수용 시 기준점 유지
5. 최종 평가: $\mathcal S_{te}$ 결정론 평가, 선택·보정 과정의 $\mathcal S_{te}$ 미사용

- $\varrho_t$: PPO 확률비 $\pi_\theta(u_t\mid s_t)/\pi_{\theta_{old}}(u_t\mid s_t)$
- 학습 소요 시간: Low-level 1.14 h, Semantic-flat 1.55 h, R-GAT 1.91 h

## 5. 평가 프로토콜

- 결론: 선택과 분리된 시험 seed의 paired 결정론 평가

| 항목 | 내용 |
|---|---|
| 검증 집합 $\mathcal S_{val}$ | 100 seed, checkpoint 선택·관계 배율 선택 전용 |
| 시험 집합 $\mathcal S_{te}$ | 100 seed, $\mathcal S_{val}$과 서로소, 최종 보고 전용 |
| paired 설계 | 세 모델 동일 seed의 동일 시나리오·센서 섭동 |
| 정책 | 결정론 평균 행동 $\mu_t$ |
| 조건 | 공칭 보상·종료·센서 조건, 커리큘럼 완화 부재 |
| 지표 | $p_s,p_u,p_a,p_\tau$, $\bar G$, $SI$, $m_v,m_a,m_T$, 추론 시간 |
| 대표 시나리오 | S1 정상 정렬, S2 급가속, S3 가시성 손실 |
| 추론 프로파일 | 동일 호스트 500회 반복 평균 |
| 신뢰구간 | 결과율의 Wilson score 95% 구간 ($n=100$) |

- 지표 정의·통계 해석 상세: 평가 프로토콜·결과 문서

## 6. 결과

### 6.1 시험 결과

- 결론: 성공률 72~75%의 근접 분포, 위험 접촉 최저 Low-level, 안전 중단 최저 Semantic-flat

| 모델 | $p_s$ | $p_u$ | $p_a$ | $p_\tau$ | $\bar G$ | 파라미터 |
|---|---:|---:|---:|---:|---:|---:|
| Low-level | 74% | **2%** | 23% | **1%** | **19.139** | 7,445 |
| Semantic-flat | **75%** | 9% | **13%** | 3% | 18.496 | 15,317 |
| Ontology R-GAT | 72% | 9% | 14% | 5% | 17.930 | 17,001 |

Wilson 95% 신뢰구간 (%):

| 모델 | $p_s$ | $p_u$ | $p_a$ | $p_\tau$ |
|---|---|---|---|---|
| Low-level | 64.6–81.6 | 0.6–7.0 | 15.8–32.2 | 0.2–5.4 |
| Semantic-flat | 65.7–82.5 | 4.8–16.2 | 7.8–21.0 | 1.0–8.5 |
| Ontology R-GAT | 62.5–79.9 | 4.8–16.2 | 8.5–22.1 | 2.2–11.2 |

- 성공률 구간 폭 약 ±8~9 pp, 3 pp 이내 차이의 판별 불가
- 위험 접촉 2% vs 9%: 경계 수준 차이 (독립 표본 Fisher 정확 검정 양측 $p\approx0.058$, paired 정보 미반영 참고치)
- 안전 중단 23% vs 13%: 독립 표본 Fisher 양측 $p\approx0.097$, 유의 수준 0.05 미달

![Monte Carlo 평균·1시그마 평가](../assets/paper/planar_visibility_monte_carlo.png)

### 6.2 추론 비용

- 결론: 그래프 정책 포함 전 모델 1 ms 미만, 결정 주기 대비 무시 가능

| 모델 | 정책 추론 | Actor·Critic 전체 | $\Delta t_p$ 대비 정책 추론 |
|---|---:|---:|---:|
| Low-level | **0.105 ms** | **0.115 ms** | 0.11% |
| Semantic-flat | 0.115 ms | 0.209 ms | 0.12% |
| Ontology R-GAT | 0.179 ms | 0.329 ms | 0.18% |

- 측정: 동일 호스트 500회 반복 소프트웨어 프로파일
- 경성 실시간 보장·최악 실행 시간 판정 제외

### 6.3 대표 시나리오

- 결론: 의미 특징 모델의 S2·S3 착륙 성공, Low-level의 FOV 이탈 후 안전 중단

| 시나리오 | Low-level | Semantic-flat | R-GAT | $SI$ (L / F / R) |
|---|---|---|---|---|
| S1 정상 정렬 | SUCCESS | UNAUTHORIZED_CONTACT | SUCCESS | 88.7 / 85.0 / **93.5** |
| S2 급가속 | SAFE_ABORT | SUCCESS | SUCCESS | 37.9 / **75.9** / 74.3 |
| S3 가시성 손실 | SAFE_ABORT | SUCCESS | SUCCESS | 47.6 / 70.8 / **80.6** |

| 시나리오 | 하강 금지 시간 비율 (L / F / R) |
|---|---|
| S2 | 75.7% / 0% / 0% |
| S3 | 73.1% / 1.7% / 1.8% |

![대표 궤적](../assets/paper/paper_trajectories.png)

- Low-level S2·S3: 궤적·FOV 이탈 지배 하강 금지, 이후 SAFE_ABORT
- Semantic-flat S1: 접촉 시점의 미허가 문맥 접촉, UNAUTHORIZED_CONTACT (결정 시점 표본의 하강 금지 비율 0%, 수평 RMSE 0.456 m)
- S3 R-GAT: Semantic-flat 대비 상대 속도 RMSE 0.203 vs 0.275 m/s, control jerk RMS 5.31 vs 35.59 m/s³
- 단일 궤적 기반, 일반화 주장 제외

### 6.4 안정성 지수

- 결론: return·종료 결과와 독립인 6성분 유계 지수, 성공률과 별도 보고

$$
SI=\frac{100}{6}\left(Q_x+Q_v+Q_{fov}+Q_{sup}+Q_\theta+Q_j\right)\in[0,100]
$$

| 성분 | 정의 |
|---|---|
| $Q_x$ | $\exp\!\left[-\left(\mathrm{RMSE}(e_x)/L_{pad}\right)^2\right]$, $L_{pad}=0.5$ m |
| $Q_v$ | $\exp\!\left[-\left(\mathrm{RMSE}(\Delta v_x)/v_{x,td}\right)^2\right]$, $v_{x,td}=0.35$ m/s |
| $Q_{fov}$ | $1-f_{fov}$, $f_{fov}$: 미검출 시간 비율 |
| $Q_{sup}$ | $1-f_{sup}$, $f_{sup}$: 안전 감독기 개입 시간 비율 |
| $Q_\theta$ | $\exp\!\left[-\left(\mathrm{RMS}(\theta)/\theta_{td}\right)^2\right]$, $\theta_{td}=5^\circ$ |
| $Q_j$ | $1/(1+j_{rms}/j_{ref})$, $j_{ref}=\sqrt{a_{x,\max}^2+a_{z,\max}^2}/\Delta t_p\approx32.0$ m/s³ |

- RMSE·RMS·시간 비율: 결정 경과 시간 $\Delta t$ 가중 시간 평균
- $j_{rms}$: 적용 가속도 결정 간 차분의 RMS
- 신규 기호: $Q_\bullet$ 성분 점수, $f_{fov},f_{sup}$ 시간 비율, $j_{rms},j_{ref}$ jerk RMS·기준값
- 값: 6.3절 표

![안정성 지표](../assets/paper/paper_stability.png)

### 6.5 물리적 착륙 가능성

- 결론: S1~S3 전부 물리적 착륙 가능, 실패의 원인은 authority 부족이 아닌 정책 거동·일시적 하강 금지

$$
m_v=(\bar v_d-v_{res})-v_3,\qquad m_a=a_{x,\max}-a_2,\qquad m_T=T_{\max}-T_d
$$

- $\bar v_d=10$ m/s 지속 비행속도, $v_{res}=0.5$ m/s 여유, $a_{x,\max}=2.5$ m/s², $T_{\max}=70$ s
- 가능 조건: $m_v\ge0\ \wedge\ m_a>0\ \wedge\ m_T\ge0$
- 불가능 원인 우선순위: 속도 → 가속도 → 임무 시간

| 시나리오 | $v_3$ (m/s) | $m_v$ (m/s) | $m_a$ (m/s²) | $m_T$ (s) | 판정 |
|---|---:|---:|---:|---:|---|
| S1 | 2.4 | 7.1 | 1.9 | 38.5 | 가능 |
| S2 | 4.375 | 5.125 | 1.0 | 37.75 | 가능 |
| S3 | 4.3 | 5.2 | 1.3 | 35.25 | 가능 |

- LandingInhibit 의미: 현재 시점 하강 금지, 영구적 착륙 불가 판정 아님
- 하강 금지 원인 분해: 센서 dropout → 궤적·FOV → 상대 속도 → 불확실성·gate 순 배타 배정

![가능성과 inhibit](../assets/paper/paper_feasibility.png)

### 6.6 관계 경로 감사

- 결론: 관계 경로 활성, 수용 배율이 탐색 격자 최소값 $\nu_{rel}=0.001$인 미소 기여

| 항목 | Actor | Critic |
|---|---:|---:|
| $\lVert W_c\rVert_F$ | 0.0001665 | 0.0006056 |
| 관계 head ($\lVert W_\pi\rVert_F$ / $\lVert w_V\rVert_2$) | 0.1517 | 0.4792 |
| 관계 경로 | 활성 | 활성 |
| $\nu_{rel}$ | 0.001 | 0.001 |

- 활성화 전후 시험 결과율: 72% / 9% / 14% / 5% 동일
- 시험 평균 return: 17.873 → 17.930 (+0.058)
- 시험 평균 절대 residual $\lvert\tilde\delta_t\rvert$: 수평 $1.27\times10^{-5}$, 수직 $3.86\times10^{-5}$
- 해석: 더 큰 배율 10개 전부 가드 미통과, 결과 보존 조건 아래 관계 기여의 상한이 매우 작음

![관계 경로 감사](../assets/paper/paper_ontology.png)

## 7. 논의

- 결론: 의미 특징의 효과는 중단 감소와 위험 증가의 교환, 관계 구조 효과는 현 설계에서 관측 불가

| 쟁점 | 근거 | 판정 |
|---|---|---|
| H1 의미 특징 효과 | $p_a$ 23% → 13%, $p_s$ +1 pp, $p_u$ 2% → 9% | 부분 지지, 중단 감소의 위험 접촉 증가 교환 |
| H2 관계 구조 효과 | R-GAT vs Semantic-flat: $p_s$ −3 pp, $p_u$ 동일, $\bar G$ −0.566 | 미지지 |
| H3 실시간성 | R-GAT 정책 추론 0.179 ms $\ll\Delta t_p$ | 지지 (소프트웨어 프로파일 한정) |

- R-GAT와 Semantic-flat 차이의 출처: 관계 residual $10^{-5}$ 수준으로 행동 영향 미미, 독립 PPO 학습 경로 차이가 주된 원인으로 추정
- 활성화 전후 결과율 불변: 관계 경로가 행동 결정 경계를 바꾸지 않은 상태의 직접 증거
- 대표 시나리오의 R-GAT $SI$ 우위: 단일 궤적·단일 seed 근거, 관계 구조 효과의 증거로 불충분
- Low-level의 낮은 $p_u$: 높은 $p_a$와 동반, 보수적 중단 성향의 결과로 해석
- 선택 점수 $J$의 위험 가중(−2500)에도 의미 특징 모델의 $p_u$ 9%: 검증·시험 분포 차이 또는 단일 seed 분산 가능성

## 8. 한계

- 결론: 단일 학습 seed·2D 모의 환경·미소 관계 residual의 3중 제약

- 2D 평면 모의 환경 한정
- 이상적 자기 상태 가정
- 실제 통신 지연·전송 계층 미반영
- 실제 비행 안전 인증 제외
- 단일 PPO 학습 seed, 학습 seed 간 분산 미추정
- 결과율 신뢰구간 약 ±9 pp의 표본 크기 제약
- 결과 보존 가드에 의한 관계 residual 상한, 관계 구조 효과의 검정력 부족
- 보편적 온톨로지 우월성 주장 제외

## 9. 향후 연구

- 결론: 다중 seed 반복과 동일 기준 가중치 위 관계 residual 단독 비교가 최우선

- 모델별 5개 이상 독립 학습 seed, 성공률·위험률·$SI$의 평균·분산 보고
- seed별 paired 결과 기반 McNemar 검정
- 신규 held-out 시험 집합 유지
- Semantic-flat과 동일 기준 가중치에서 관계 residual만 추가한 통제 비교
- 그래프 선택 여유·관계 적응 시작 시점의 다중 seed 재검토
- 활성 $\nu_{rel}$과 residual 크기의 동시 보고
- 결과 보존 가드 완화 조건 아래 관계 기여 크기별 성능 곡선 산출
