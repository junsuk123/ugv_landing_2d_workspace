# 평가 프로토콜·결과

## 요약

- 평가 설계: 선택용 $\mathcal S_{val}$과 서로소인 $\mathcal S_{te}$ 100 seed의 paired 결정론 평가
- 시험 결과: 성공률 Low-level 74%, Semantic-flat 75%, R-GAT 72%, 위험 접촉률 Low-level 2% 최저
- 통계 해석: Wilson 95% 구간 반폭 약 ±9 pp, 세 모델 결과율 차이 전부 구간 중첩, 유의한 우열 부재
- 불확실성 범위: 단일 학습 seed, 평가 episode 표본 분산만 반영, 학습 seed 간 분산 미반영
- 대표 시나리오: S1~S3 전부 물리적 착륙 가능, Low-level의 S2·S3 실패 원인은 FOV 이탈 지배 하강 금지
- 관계 경로: 활성 확인, 활성화 전후 시험 결과율 동일, 행동 residual $10^{-5}$ 수준
- 평가 산출 시각: 2026-10-06 09:31 KST

## 1. 평가 설계

- 결론: 선택·보정·보고의 seed 집합 분리와 세 모델 동일 seed 대응의 paired 비교

| 설계 요소 | 내용 |
|---|---|
| 검증 집합 $\mathcal S_{val}$ | seed 2001–2100 (100개), checkpoint 선택 점수 $J$·관계 배율 $\nu_{rel}$ 선택 전용 |
| 시험 집합 $\mathcal S_{te}$ | seed 3001–3100 (100개), 최종 보고 전용, 선택 과정 미사용 |
| paired 대응 | 동일 seed의 동일 시나리오 $\sigma$·센서 섭동, 세 모델 공통 |
| 정책 | 결정론 평균 행동 $\mu_t$, 탐색 잡음 배제 |
| 과제 조건 | 공칭 보상·종료·센서·시나리오 분포, 커리큘럼 완화 부재 |
| 모델 동일성 | 동일 환경·관측·행동·안전 감독기·보상·종료 규칙 |
| 참값 사용 | 보상·종료 판정·사후 지표 한정, 정책 입력 배제 |
| 대표 시나리오 | 고정 파라미터 S1·S2·S3, 정책 무관 사전 정의 |
| 추론 프로파일 | 동일 호스트 500회 반복 평균 |

## 2. 지표 정의

- 결론: 종료 결과율·return·안정성·가능성의 4계층 지표, 종료 결과와 안정성의 독립 보고

### 2.1 종료 결과율

- 결론: 7개 종료 결과의 4개 상호 배타 범주 분할, $p_s+p_u+p_a+p_\tau=1$

$$
p_k=\frac{1}{n}\sum_{i=1}^{n}\mathbb 1\!\left[o_i\in\mathcal O_k\right],\qquad k\in\{s,u,a,\tau\}
$$

| 비율 | 결과 집합 $\mathcal O_k$ |
|---|---|
| $p_s$ | SUCCESS |
| $p_u$ | UNSAFE_CONTACT, UNAUTHORIZED_CONTACT, MISSED_PAD_CONTACT, SAFETY_ENVELOPE_VIOLATION |
| $p_a$ | SAFE_ABORT |
| $p_\tau$ | TASK_TIMEOUT |

- $n=100$, $o_i$: episode $i$의 종료 결과, $\mathcal O_k$: 범주 $k$의 결과 집합 (신규 기호)

### 2.2 Return과 포착률

- 결론: $\bar G$는 비할인 보상 합의 평균, 포착률은 검출 결정 비율

$$
\bar G=\frac{1}{n}\sum_{i=1}^{n}\sum_{t=1}^{N_i}r_t^{(i)},
\qquad
\bar d=\frac{1}{N}\sum_{t=1}^{N}d_t
$$

- $N_i$: episode $i$의 결정 수, $\bar d$: episode 포착률 (신규 기호)
- $d_t$: 결정 종료 시점 검출 여부
- 포착률 용도: 검증 단계 감시·Monte Carlo 그림 표시, 시험 수치 표 미포함

### 2.3 안정성 지수 $SI$

- 결론: return·종료 결과를 배제한 6성분 유계 지수, 성분별 동일 가중

$$
SI=\frac{100}{6}\left(Q_x+Q_v+Q_{fov}+Q_{sup}+Q_\theta+Q_j\right)\in[0,100]
$$

| 성분 | 정의 | 기준값 |
|---|---|---|
| $Q_x$ | $\exp\!\left[-\left(x_{rms}/L_{pad}\right)^2\right]$ | $L_{pad}=0.5$ m |
| $Q_v$ | $\exp\!\left[-\left(v_{rms}/v_{x,td}\right)^2\right]$ | $v_{x,td}=0.35$ m/s |
| $Q_{fov}$ | $1-f_{fov}$ | 측정 미검출 시간 비율 |
| $Q_{sup}$ | $1-f_{sup}$ | 안전 감독기 개입 시간 비율 |
| $Q_\theta$ | $\exp\!\left[-\left(\theta_{rms}/\theta_{td}\right)^2\right]$ | $\theta_{td}=5^\circ$ |
| $Q_j$ | $1/(1+j_{rms}/j_{ref})$ | $j_{ref}=\sqrt{2.5^2+2.0^2}/0.1\approx32.0$ m/s³ |

시간 가중 정의 ($D=\sum_t\Delta t_t$):

$$
x_{rms}=\sqrt{\tfrac{1}{D}\textstyle\sum_t\Delta t_t\,e_{x,t}^2},\quad
v_{rms}=\sqrt{\tfrac{1}{D}\textstyle\sum_t\Delta t_t\,\Delta v_{x,t}^2},\quad
\theta_{rms}=\sqrt{\tfrac{1}{D}\textstyle\sum_t\Delta t_t\,\theta_t^2}
$$

$$
j_{rms}=\sqrt{\frac{1}{N-1}\sum_{t=2}^{N}\left\lVert\frac{\bar{\tilde a}_t-\bar{\tilde a}_{t-1}}{\Delta t_t}\right\rVert_2^2}
$$

- $\bar{\tilde a}_t$: 결정 구간 평균 적용 가속도 (신규 기호)
- $Q_\bullet,\;x_{rms},v_{rms},\theta_{rms},\;f_{fov},f_{sup},\;j_{rms},j_{ref},\;D$: 본 문서 신규 기호
- 지수 형태 성분: 기준값에서 $e^{-1}$, 접지 한계와 같은 척도의 정규화
- 동일 가중: 성분 간 임의 가중치 조정 배제

### 2.4 하강 금지 비율과 원인 분해

- 결론: 하강 금지 시간을 4개 원인에 우선순위 배타 배정

$$
f_{inh}=\frac{1}{D}\sum_t\Delta t_t\,\iota_t
$$

- $\iota_t\in\{0,1\}$: 정책 관측 패킷의 하강 금지 지시자, $f_{inh}$: 하강 금지 시간 비율 (신규 기호)
- 원인 배정 순서: 센서 dropout 구간 → 기하학적 FOV 이탈 → $\lvert\Delta v_x\rvert>v_{x,td}$ → 잔여분 불확실성·gate
- 해석: 현재 시점 하강 금지, 영구적 착륙 불가 판정 아님

### 2.5 물리적 착륙 가능성

- 결론: 정책과 무관한 authority margin으로 시나리오 자체의 가능성 판정

$$
m_v=(\bar v_d-v_{res})-v_3,\qquad m_a=a_{x,\max}-a_2,\qquad m_T=T_{\max}-T_d
$$

- $\bar v_d=10$ m/s 지속 비행속도, $v_{res}=0.5$ m/s 여유, $a_{x,\max}=2.5$ m/s², $T_{\max}=70$ s
- 가능 조건: $m_v\ge0\ \wedge\ m_a>0\ \wedge\ m_T\ge0$
- 불가능 원인 우선순위: 속도 → 가속도 → 임무 시간

## 3. 통계 해석

- 결론: $n=100$ 결과율의 95% 구간 반폭 최대 약 ±9.8 pp, 3 pp 수준 차이의 판별 불가

구간 추정 방법:

- 방법: Wilson score 구간, $z=1.96$
- 선택 근거: $p_\tau=1\%$ 등 경계 근처 비율에서 정규 근사 구간의 음수 하한 발생, Wilson 구간의 $[0,1]$ 내부 보장

$$
\frac{\hat p+\dfrac{z^2}{2n}\pm z\sqrt{\dfrac{\hat p(1-\hat p)}{n}+\dfrac{z^2}{4n^2}}}{1+\dfrac{z^2}{n}}
$$

- 정규 근사 참고 반폭: $z\sqrt{\hat p(1-\hat p)/n}$, $\hat p=0.5$에서 9.8 pp, $\hat p=0.74$에서 8.6 pp

시험 결과율 Wilson 95% 구간 (%):

| 모델 | $p_s$ | $p_u$ | $p_a$ | $p_\tau$ |
|---|---|---|---|---|
| Low-level | 74 [64.6, 81.6] | 2 [0.6, 7.0] | 23 [15.8, 32.2] | 1 [0.2, 5.4] |
| Semantic-flat | 75 [65.7, 82.5] | 9 [4.8, 16.2] | 13 [7.8, 21.0] | 3 [1.0, 8.5] |
| Ontology R-GAT | 72 [62.5, 79.9] | 9 [4.8, 16.2] | 14 [8.5, 22.1] | 5 [2.2, 11.2] |

모델 간 차이 판정:

| 비교 | 차이 | 참고 검정 | 판정 |
|---|---|---|---|
| $p_s$ Semantic-flat vs R-GAT | 75% vs 72% | Fisher 양측 $p\approx0.75$ | 차이 부재 |
| $p_u$ Low-level vs 의미 특징 모델 | 2% vs 9% | Fisher 양측 $p\approx0.058$ | 경계 수준, 0.05 미달 |
| $p_a$ Low-level vs Semantic-flat | 23% vs 13% | Fisher 양측 $p\approx0.097$ | 0.05 미달 |
| $p_\tau$ Low-level vs R-GAT | 1% vs 5% | Fisher 양측 $p\approx0.21$ | 차이 부재 |

- Fisher 정확 검정: 독립 표본 가정의 참고치, paired 상관 미반영
- paired 검정 (McNemar): seed별 결과 대응표 필요, 현 보고 범위 밖
- 다중 비교 보정 미적용, 보정 시 판정 추가 약화
- 단일 학습 seed: 구간이 반영하는 분산은 시나리오·센서 표본 분산 한정, 학습 무작위성 분산 제외
- 결과: 모델 간 비교의 실제 불확실성은 표 구간보다 큼

## 4. 시험 결과

- 결론: 세 모델의 성공률 근접, 의미 특징 모델의 안전 중단 감소와 위험 접촉 증가 동반

| 모델 | $\bar G$ | $p_s$ | $p_u$ | $p_a$ | $p_\tau$ | 파라미터 | 정책 추론 | Actor·Critic 전체 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Low-level MLP PPO | **19.139** | 74% | **2%** | 23% | **1%** | 7,445 | **0.105 ms** | **0.115 ms** |
| Semantic-flat MLP PPO | 18.496 | **75%** | 9% | **13%** | 3% | 15,317 | 0.115 ms | 0.209 ms |
| Ontology R-GAT PPO | 17.930 | 72% | 9% | 14% | 5% | 17,001 | 0.179 ms | 0.329 ms |

- Semantic-flat vs Low-level: $p_s$ +1 pp, $p_a$ −10 pp, $p_u$ +7 pp
- R-GAT vs Semantic-flat: $p_s$ −3 pp, $p_u$ 동일, $p_\tau$ +2 pp
- $\bar G$ 최고 Low-level: 낮은 $p_u$에 따른 −40 종료 보상 회피 효과로 추정
- 추론 시간: 500회 반복 소프트웨어 프로파일, 호스트 부하 영향 존재, 경성 실시간 보장 제외
- 학습 소요 시간: Low-level 1.14 h, Semantic-flat 1.55 h, R-GAT 1.91 h

![Monte Carlo 평균·1시그마 궤적과 최종 평가](assets/paper/planar_visibility_monte_carlo.png)

- 궤적 패널: 시간 정규화 평균과 1시그마 공분산 윤곽
- 결과율 패널: 동일 seed의 성공·위험 접촉·안전 중단·포착률 비교
- 학습 곡선 패널: 검증 return 평균 궤적
- 관계 패널: 최종 R-GAT 관계 유형별 평균 attention $\alpha^{(r)}_{ij}$

## 5. 대표 시나리오 분석

- 결론: 세 시나리오 모두 물리적 착륙 가능, 결과 차이는 정책의 가시성 유지·하강 허가 거동 차이

시나리오 조건:

| 시나리오 | 검증 대상 온톨로지 경로 | $v_1$ (m/s) | $a_2$ (m/s²) | $h_0$ (m) | $T_d$ (s) | 센서 사건 |
|---|---|---:|---:|---:|---:|---|
| S1 정상 정렬 | PadVisibility → RelativeTracking → DescentEligibility | 1.5 | 0.6 | 6.0 | 31.5 | 없음 |
| S2 급가속 | PadMotion → RelativeTracking → TrackingCorrection | 1.0 | 1.5 | 7.0 | 32.25 | 없음 |
| S3 가시성 손실 | PadVisibility → ViewRecovery → LandingInhibit | 1.0 | 1.2 | 6.5 | 34.75 | 0.8 s 검출 dropout |

물리적 가능성:

| 시나리오 | $v_3$ (m/s) | $m_v$ (m/s) | $m_a$ (m/s²) | $m_T$ (s) | 판정 |
|---|---:|---:|---:|---:|---|
| S1 | 2.4 | 7.1 | 1.9 | 38.5 | 가능 |
| S2 | 4.375 | 5.125 | 1.0 | 37.75 | 가능 |
| S3 | 4.3 | 5.2 | 1.3 | 35.25 | 가능 |

결과와 안정성:

| 시나리오 | 모델 | 종료 결과 | $SI$ | $f_{inh}$ |
|---|---|---|---:|---:|
| S1 | Low-level | SUCCESS | 88.7 | 0% |
| S1 | Semantic-flat | UNAUTHORIZED_CONTACT | 85.0 | 0% |
| S1 | R-GAT | SUCCESS | **93.5** | 0% |
| S2 | Low-level | SAFE_ABORT | 37.9 | 75.7% |
| S2 | Semantic-flat | SUCCESS | **75.9** | 0% |
| S2 | R-GAT | SUCCESS | 74.3 | 0% |
| S3 | Low-level | SAFE_ABORT | 47.6 | 73.1% |
| S3 | Semantic-flat | SUCCESS | 70.8 | 1.7% |
| S3 | R-GAT | SUCCESS | **80.6** | 1.8% |

세부 지표:

| 시나리오 | 모델 | $x_{rms}$ (m) | $v_{rms}$ (m/s) | $f_{fov}$ | $f_{sup}$ | $j_{rms}$ (m/s³) |
|---|---|---:|---:|---:|---:|---:|
| S1 | Low-level | 0.124 | 0.122 | 0% | 0% | 23.17 |
| S1 | Semantic-flat | 0.456 | 0.140 | 0% | 0.5% | 3.36 |
| S1 | R-GAT | 0.183 | 0.114 | 0% | 0% | 3.81 |
| S2 | Low-level | 3.975 | 0.954 | 51.4% | 65.2% | 8.54 |
| S2 | Semantic-flat | 0.384 | 0.325 | 0% | 0% | 3.46 |
| S2 | R-GAT | 0.421 | 0.289 | 0% | 0% | 5.64 |
| S3 | Low-level | 1.517 | 0.352 | 37.5% | 71.1% | 7.39 |
| S3 | Semantic-flat | 0.391 | 0.275 | 4.5% | 1.7% | 35.59 |
| S3 | R-GAT | 0.364 | 0.203 | 4.9% | 1.8% | 5.31 |

시나리오별 해석:

- S1: Low-level·R-GAT 성공, Semantic-flat의 접촉 시점 미허가 접촉 (수평 RMSE 0.456 m로 패드 반길이 근접)
- S1 Low-level: 최소 추적 오차, 높은 jerk (23.17 m/s³)에 의한 $SI$ 감점
- S2: Low-level의 FOV 이탈 51.4%, 하강 금지 지배 원인 궤적·FOV (7.84 s), 상대 속도 (3.7 s), 결과 SAFE_ABORT
- S2: 의미 특징 두 모델의 하강 금지 없는 착륙, $SI$ 차이 1.6
- S3: Low-level 하강 금지 원인 배정 dropout 0.8 s·궤적·FOV 4.9 s·상대 속도 0.6 s·불확실성 4.82 s, 재포착 지연 5.0 s
- S3: 의미 특징 두 모델의 재포착 지연 0.1 s, 하강 금지 원인 dropout 0.3 s 한정
- S3 R-GAT: Semantic-flat 대비 $v_{rms}$·$j_{rms}$ 감소, $SI$ +9.8
- 일반화 제한: 단일 고정 궤적, 단일 학습 seed 근거

![고정 시나리오 궤적](assets/paper/paper_trajectories.png)

![안정성 지표](assets/paper/paper_stability.png)

![물리 가능성과 하강 금지](assets/paper/paper_feasibility.png)

## 6. 관계 경로 검증

- 결론: R-GAT 관계 경로 활성, 결과율 보존 조건 아래 수용 배율 $\nu_{rel}=0.001$의 미소 기여

| 항목 | Actor | Critic |
|---|---:|---:|
| 그룹 readout $\lVert W_c\rVert_F$ | 0.0001665 | 0.0006056 |
| 관계 head ($\lVert W_\pi\rVert_F$ / $\lVert w_V\rVert_2$) | 0.1517 | 0.4792 |
| 관계 경로 | 활성 | 활성 |
| $\nu_{rel}$ | 0.001 | 0.001 |

검증 절차:

- 기준점: 선택 checkpoint의 raw Actor·Critic 고정
- 관계 전용 PPO 후 $\nu_{rel}$ 격자 내림차순 탐색
- 수용 조건 ($\mathcal S_{val}$ 100 seed): 결과율 비열화, $\bar G$·$J$ 감소 0.25 이내, 평균 절대 residual norm $[10^{-6},0.005]$, 관계 경로 활성
- $\mathcal S_{te}$: 배율 선택 미사용

시험 집합 영향:

- 결과율: 활성화 전후 72% / 9% / 14% / 5% 동일
- 평균 return: 17.873 → 17.930 (+0.058)
- 평균 절대 residual $\lvert\tilde\delta_t\rvert$: 수평 $1.27\times10^{-5}$, 수직 $3.86\times10^{-5}$
- 판정: 계산 경로 활성 확인, 관계 구조의 성능 기여 주장 제외

![온톨로지 신호와 관계 감사](assets/paper/paper_ontology.png)

## 7. 한계

- 결론: 단일 학습 seed와 모의 환경 한정, 실제 비행 안전성 미검증

| 범주 | 미검증 범위 |
|---|---|
| 통계 | 다중 학습 seed 평균·표준편차, seed별 paired 검정 |
| 표본 | 결과율 구간 반폭 약 ±9 pp, 소수 사건($p_u,p_\tau$)의 낮은 검정력 |
| 분할 | 학습 episode seed의 검증·시험 seed 명시적 배제 부재, 우연 중복 기대 확률 약 0.14% |
| 관계 구조 | residual 상한에 의한 관계 효과 검정력 부족 |
| 환경 | 2D 평면 모의, 이상적 자기 상태 |
| 센서 | 실제 센서 지연·dropout 분포 |
| 기체 | 실제 공력·제어 지연 |
| 통신 | 실제 전송 계층 지연 |
| 안전 | 실제 비행 안전성 |
| 일반화 | 보편적 온톨로지 우월성 |
