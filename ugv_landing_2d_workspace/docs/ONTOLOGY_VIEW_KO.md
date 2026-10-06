# 관계 해석 지표

## 요약

- 목적: R-GAT 관계 경로의 작동 여부·크기·원인의 정량 해석
- 구조 지표: 관계 유형별 attention 점유율, 간선 attention $\alpha_{ij}^{(r)}$, message 크기, 그룹 readout 기여
- 행동 지표: 관계 residual 크기 $\mathbb E\lvert\tilde\delta\rvert$, gate 활성 비율, 관계 경로 활성 판정
- 안전 지표: LandingInhibit 시간의 원인별 배타 분해
- 분포 지표: 정규화 시간축 Monte Carlo 평균 궤적과 1σ 공분산 타원
- 최종 판정: 관계 경로 활성, readout norm Actor 0.0001665·Critic 0.0006056, $\nu_{rel}=0.001$, 수직 residual $10^{-5}$ 수준
- 해석 원칙: attention 크기와 실제 행동 영향의 구분, 사후 참값 지표와 정책 입력의 구분

## 1. 지표 전용 기호

| 기호 | 정의 |
|---|---|
| $\Pi_r(j)$ | 도착 노드 $j$의 관계 유형 $r$ attention 점유율 |
| $A_{ij}$ | 출발 $i$·도착 $j$ 간선 attention 행렬 원소 |
| $\mu_{ij}^{(r)}$ | 간선 message 크기 |
| $W_c^{(g)}\in\mathbb R^{4\times8}$ | $W_c$의 그룹 $g$ 열 블록 |
| $C_g$ | 그룹 $g$ readout 기여 크기 |
| $\Gamma$ | gate 활성 비율 |
| $T_{inh}$ | LandingInhibit 누적 시간 |
| $\tilde t$ | episode 정규화 시간 $\in[0,1]$ |
| $\bar p(\tilde t),\;\Sigma(\tilde t)$ | 정규화 시간별 위치 평균·공분산 |
| $N_{ep}$ | 집계 episode 수 |
| $n$ | episode 색인 |

## 2. 관계 유형별 attention 점유율

- 핵심: 도착 노드가 어떤 관계 유형의 근거에 의존하는지의 직접 척도
- 핵심: 공동 softmax 구조로 관계 유형 간 합이 1인 비교 가능 분포

$$
\Pi_r(j)=\sum_{(i,r')\in\mathcal N(j),\;r'=r}\alpha_{ij}^{(r')},\qquad \sum_{r\in\mathcal R}\Pi_r(j)=\frac{Z_j}{Z_j+10^{-9}}\approx1
$$

- $Z_j$: $\mathcal N(j)$ 전체 $\exp(e_{kj}^{(r')})$ 합
- $\Pi_{\mathrm{self}}(j)$ 우세: 자기 노드 근거 의존, 관계 전달 약화
- $\Pi_{\mathrm{inhibits}}(\mathrm{DescentEligibility})$ 증가: 하강 금지 근거의 하강 허용도 반영 강화
- $\Pi_{\mathrm{supports}}(\mathrm{DescentEligibility})$ 증가: 시야 근거의 하강 허용도 반영 강화
- 순수 출발 노드(PadMotion·DroneTranslation·DroneAttitude): $\Pi_{\mathrm{self}}\approx1$ 구조적 고정, 학습 결과 해석 대상 제외

## 3. 간선 attention

- 핵심: 수신 노드 내 상대 가중치, 절대 영향 크기 아님

$$
A_{ij}=\alpha_{ij}^{(r)},\qquad (i,r)\in\mathcal N(j)
$$

- 간선 없는 쌍: 정의 없음, 0과 구분
- 대각 원소: self 관계 attention
- 시나리오 평균 attention:

$$
\bar A_{ij}=\frac{1}{N_{ep}}\sum_{n=1}^{N_{ep}}\alpha_{ij}^{(r)}\big(X^{(n)}_{\mathrm{end}}\big)
$$

- $X^{(n)}_{\mathrm{end}}$: episode $n$의 마지막 결정 시점 노드 특징, Actor 부호화기 기준
- 해석 범위: 종료 직전 상태의 attention 분포, 전 구간 평균 아님
- logit 해석: $e_{ij}^{(r)}$ 큰 간선의 수신 노드 내 우선, 동일 $j$ 내 비교 한정

## 4. message 크기

- 핵심: attention과 사영 특징 크기의 곱으로 실제 전달량 측정

$$
\mu_{ij}^{(r)}=\alpha_{ij}^{(r)}\,\big\lVert W_r x_i\big\rVert_2
$$

- $\alpha$ 큼·$\mu$ 작음: 가중치는 높으나 전달 내용 미약
- $\alpha$ 작음·$\mu$ 큼: 출발 특징 크기에 의한 실질 영향
- 노드 갱신 사전활성 대비 비교: $\big\lVert W_0x_j+b_0\big\rVert_2$와의 상대 크기로 관계 경로·국소 경로 우세 판정
- 관계별 요약: 관계 $r$ 간선의 $\mu$ 합, 관계 유형 간 실제 전달량 비교

## 5. 그룹 readout 기여

- 핵심: 관계 문맥 $c_t$에 대한 의미 그룹별 선형 기여 분해

$$
W_c=\big[W_c^{(1)}\;W_c^{(2)}\;W_c^{(3)}\;W_c^{(4)}\big],\qquad
c_t=\tanh\!\Big(\sum_{g=1}^{4}W_c^{(g)}\bar h_g+b_c\Big)
$$

$$
C_g=\big\lVert W_c^{(g)}\bar h_g\big\rVert_2,\qquad \tildeC_g=\frac{C_g}{\sum_{g'}C_{g'}}
$$

- $\tildeC_g$: 그룹 $g$의 상대 기여 비율
- 분해 위치: $\tanh$ 이전 사전활성, $\tanh$ 이후 비가산성 존재
- 행동 공간 사영: $W_\pi W_c^{(g)}\bar h_g$로 그룹별 residual 방향 해석
- 문맥 크기 $\lVert c_t\rVert_2$: $\nu_{rel}$ 축소 후 $W_c,b_c$에 비례한 축소

## 6. 관계 residual 크기

- 핵심: 관계 경로가 행동에 미치는 실제 크기의 최종 척도

$$
\overline{\lvert\tilde\delta_a\rvert}^{(n)}=\frac{1}{N_n}\sum_{t=1}^{N_n}\big\lvert\tilde\delta_{a,t}\big\rvert,\qquad
\mathbb E\lvert\tilde\delta_a\rvert=\frac{1}{N_{ep}}\sum_{n=1}^{N_{ep}}\overline{\lvert\tilde\delta_a\rvert}^{(n)},\qquad a\in\{x,z\}
$$

- $N_n$: episode $n$의 결정 수, 결정 단위 평균(시간 가중 아님)
- guard 척도: $\big\lVert[\mathbb E\lvert\tilde\delta_x\rvert,\mathbb E\lvert\tilde\delta_z\rvert]\big\rVert_2\in[10^{-6},0.005]$
- 최종 측정: 수평 $1.27\times10^{-5}$, 수직 $3.86\times10^{-5}$
- 해석: 정규화 행동 범위 $[-1,1]$ 대비 무시 가능 수준, 관계 경로의 활성 증거이나 행동 기여 증거 아님

## 7. gate 활성 비율

- 핵심: 관계 경로가 추가 하강을 요구했고 $g_t$가 이를 축소한 결정의 비율

$$
\Gamma=\frac{1}{N_n}\sum_{t=1}^{N_n}\mathbb 1\big[\delta_{z,t}<0\;\wedge\;g_t<1\big],\qquad
\bar g=\frac{1}{N_n}\sum_{t=1}^{N_n}g_t
$$

- $\Gamma\approx1$: 관계 residual의 지속적 하강 방향과 $g_t<1$ 동시 성립
- $\bar g$ 저하: 위치·속도·자세 위험 또는 추적 신뢰도 저하 구간의 증가
- 축소량: $(1-g_t)\lvert\delta_{z,t}\rvert$, gate가 제거한 추가 하강 크기
- $b_{inh}=1$ 구간: $g_t=0$, 관계 경로 추가 하강 완전 차단

## 8. LandingInhibit 원인 분해

- 핵심: 하강 금지 시간의 우선순위 기반 배타 분해, 원인 시간 합 $=T_{inh}$

$$
T_{inh}=\sum_t\Delta t\;\mathbb 1\big[b_{inh,t}=1\big]
$$

| 순위 | 원인 | 판정 조건 (금지 결정 중, 상위 원인 미해당) |
|---:|---|---|
| 1 | 센서 dropout | 지정 dropout 구간 내 시점 |
| 2 | 궤적·FOV | 기하 투영상 패드 비가시 |
| 3 | 상대 속도 | $\lvert\Delta v_x\rvert>v_{td}$ |
| 4 | 불확실성·gate | 1~3 미해당 잔여 시간 |

$$
T_{inh}=T_{\mathrm{drop}}+T_{\mathrm{fov}}+T_{\mathrm{spd}}+T_{\mathrm{unc}},\qquad
\text{지배 원인}=\arg\max\{T_{\mathrm{drop}},T_{\mathrm{fov}},T_{\mathrm{spd}},T_{\mathrm{unc}}\}
$$

- $v_{td}$: 접지 허용 수평 상대 속도
- $\Delta t$: 결정별 실제 경과 시간 가중
- 판정 2·3의 참값 사용: 사후 평가 전용, 정책 입력 아님
- 해석: 일시적 운영 하강 금지, 영구적 착륙 불가능 판정 아님
- 물리 가능성 구분: 속도·가속도 authority margin $m_v,m_a$의 별도 판정

## 9. Monte Carlo 평균·1σ 궤적

- 핵심: 지속시간이 다른 episode의 정규화 시간축 정렬 후 위치 분포 요약

$$
\tilde t=\frac{t-t_0}{t_{\mathrm{end}}-t_0}\in[0,1],\qquad \tilde t_q=\frac{q-1}{99},\;q=1,\dots,100
$$

$$
p^{(n)}(\tilde t_q)=\mathrm{interp}\big(\tilde t,\,[x,z]^{(n)},\,\tilde t_q\big),\qquad
\bar p(\tilde t_q)=\frac{1}{N_{ep}}\sum_n p^{(n)}(\tilde t_q)
$$

$$
\Sigma(\tilde t_q)=V\Lambda V^\top,\qquad
\mathcal C(\tilde t_q)=\Big\{\bar p(\tilde t_q)+V\Lambda^{1/2}[\cos\vartheta,\sin\vartheta]^\top:\vartheta\in[0,2\pi)\Big\}
$$

- $V,\Lambda$: $\Sigma(\tilde t_q)$의 고유벡터 행렬·고유값 대각 행렬, $\vartheta$: 타원 매개각
- 보간: 선형 보간, 구간 외 선형 외삽
- 좌표: 세계 좌표 $(x,z)$, 패드 상대 좌표 아님
- 1σ 타원 $\mathcal C$: 7개 정규화 시점 표시, 공분산 고유분해 기반
- 해석 주의: 같은 $\tilde t$의 서로 다른 물리 시간·운동 구간 혼합
- 해석 주의: 타원 크기의 시나리오 다양성 반영, 정책 불안정성과 구분

## 10. 관계 경로 활성 판정

- 핵심: readout과 관계 head가 모두 0이 아닐 때만 관계 경로의 출력 도달

$$
\mathrm{Active}=\mathbb 1\!\Big[\min\big(\lVert W_c^{\pi}\rVert_F,\lVert W_c^{V}\rVert_F,\lVert W_\pi\rVert_F,\lVert w_V\rVert_2\big)>10^{-10}\Big]
$$

- 활성: Actor·Critic 양쪽 관계 경로의 출력 도달
- 비활성: raw semantic 경로만의 선택 checkpoint

| 항목 | 값 |
|---|---:|
| Actor $\lVert W_c\rVert_F$ | 0.0001665 |
| Critic $\lVert W_c\rVert_F$ | 0.0006056 |
| 판정 | 활성 |
| 성능 보존 배율 $\nu_{rel}$ | 0.001 |

## 11. 그림 해석

### 11.1 정적 온톨로지 구조

![온톨로지 그래프](assets/ontology_graph.svg)

- 내용: 9개 노드, 그룹별 색, 17개 의미 간선, 관계 유형별 선 형식
- 억제 관계: LandingInhibit → DescentEligibility
- 자기 간선 9개: 표기 생략
- 전체 간선 목록: [온톨로지 그래프 상태와 R-GAT](ONTOLOGY_GRAPH_STATE_KO.md)

### 11.2 궤적 비교

![궤적 비교](assets/paper/paper_trajectories.png)

- 왼쪽 열: 패드 상대 수평 위치 $-e_x$–상대 고도 $h$ 궤적
- 오른쪽 열: 시간–부호 포함 수평 추종 오차
- 시작점: 빈 원, 종료점: 채운 역삼각형
- 회색 점선: 수평 카메라 기준 FOV 참고 경계
- 배경: 등속·등가속·등속 3구간
- 축 범위: 전 시나리오 공통

### 11.3 안정성 지표

![안정성 지표](assets/paper/paper_stability.png)

- 안정성 지수: 6개 정규화 점수 평균의 100배

$$
SI=\frac{100}{6}\big(Q_x+Q_v+Q_{fov}+Q_{sup}+S_\theta+Q_j\big)
$$

| 점수 | 정의 |
|---|---|
| $Q_x$ | $\exp\!\big(-(\mathrm{RMSE}_{e_x}/L_{pad})^2\big)$ |
| $Q_v$ | $\exp\!\big(-(\mathrm{RMSE}_{\Delta v_x}/v_{td})^2\big)$ |
| $Q_{fov}$ | $1-$ 측정 FOV 상실 시간 비율 |
| $Q_{sup}$ | $1-$ 안전 감독기 개입 시간 비율 |
| $S_\theta$ | $\exp\!\big(-(\mathrm{RMS}_\theta/\theta_{td})^2\big)$ |
| $Q_j$ | $1/(1+\mathrm{RMS}_{jerk}/j_{ref})$, $j_{ref}=\sqrt{a_{x,\max}^2+a_{z,\max}^2}/\Delta t_p$ |

- RMSE·RMS: 결정 경과 시간 $\Delta t$ 가중
- $\theta_{td}$: 접지 허용 pitch
- 방향: $SI$ 큰 값 우수, 구성 오차 지표 작은 값 우수
- 성공률·return 미포함, 결과율과 별도 해석

### 11.4 착륙 가능성과 하강 금지

![착륙 가능성](assets/paper/paper_feasibility.png)

- 상단: 시나리오별 속도·가속도 authority margin $m_v,m_a$, 정책 무관 물리 판정
- 하단 왼쪽: 모델별 LandingInhibit 시간 비율 $T_{inh}/\sum\Delta t$
- 하단 오른쪽: R-GAT 궤적의 8절 원인 분해 누적 막대
- 양의 margin: 해당 단일 물리 제약 통과

### 11.5 온톨로지 정책 추적

![온톨로지 추적](assets/paper/paper_ontology.png)

- 왼쪽 축: $g_t$, $b_{inh}$, 검출 $d_k$, gate 활성 지시자 $\mathbb 1[\delta_{z,t}<0\wedge g_t<1]$
- 오른쪽 축: 수직 관계 residual $\tilde\delta_{z,t}$, $10^{-5}$ 배율
- 상단 판정: 관계 경로 활성, Actor $\lVert W_c\rVert_F=0.0001665$, Critic $\lVert W_c\rVert_F=0.0006056$
- dropout 구간: 검출 0, $g_t=0$, $\tilde\delta_{z,t}\to0$ 동시 관찰
- 해석: dropout 중 관계 경로 추가 하강의 gate 차단, 재포착 후 $g_t$ 회복

### 11.6 Monte Carlo 요약

![Monte Carlo 평균·1시그마 궤적](assets/paper/planar_visibility_monte_carlo.png)

- 왼쪽 위: 9절 정의의 모델별 평균 궤적과 1σ 타원
- 오른쪽 위: 시험 seed 결과율 (성공·위험 접촉·안전 중단·포착)
- 왼쪽 아래: PPO 반복별 검증 평균 return
- 가운데 아래: 결정당 추론 시간과 파라미터 수
- 오른쪽 아래: 3절 정의의 $\bar A_{ij}$ 행렬, 행 출발·열 도착·대각 self, 회색 간선 없음
- $\bar A$ 대각 고값(PadMotion·DroneTranslation·DroneAttitude): 순수 출발 노드의 구조적 $\alpha\approx1$

## 12. 해석 제한

- 핵심: attention·readout 지표는 관계 경로의 작동 기술, 성능 인과 입증 아님
- attention 크기의 행동 영향 동일시 제외, message·residual 크기 병행 확인 필요
- 단일 궤적 결과의 일반화 제외
- 안정성 지수와 성공률의 혼합 제외
- 작은 관계 residual의 보편적 우월성 주장 제외
- 사후 참값 지표의 정책 입력 해석 제외
- 정규화 시간축 평균의 물리 시간 대응 해석 제외
