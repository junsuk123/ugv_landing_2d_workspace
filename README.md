# UGV 착륙용 Causal Ontology R-GAT PPO

## 최종 결론

- 연구 대상: 가속 중인 이동 패드에 대한 2차원 드론 착륙
- 공통 조건: 환경·센서·보상·행동·안전 감독기·종료 조건 동일
- 비교 변수: Actor/Critic 상태 표현만 변경
- 비교군: 저수준 관측 MLP, semantic-flat MLP, ontology R-GAT PPO
- 최신 코드: `planar_visibility_v2`, 알고리즘 `planar-visibility-ppo-v2.8`
- 최신 회귀 검증: MATLAB R2025b 비그래픽 27/27·그래픽 포함 32/32 통과
- 논문용 진입점: `run_paper.m`
- 핵심 제한: 최종 선택 R-GAT 체크포인트의 관계 readout `Wg=0`
- 해석 범위: 현재 궤적 차이에 대한 활성 R-GAT 관계 추론 기여 주장 제외

## 최신 결과

### 100개 fresh test seed 평가

| 모델 | 성공률 | 위험 접촉률 | 안전 중단률 | 시간 초과율 | 평균 return | 파라미터 | 추론 시간 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Low-level MLP PPO | 74% | 2% | 23% | 1% | 19.139 | 7,445 | 0.320 ms |
| Semantic-flat MLP PPO | 75% | 9% | 13% | 3% | 18.496 | 15,317 | 0.149 ms |
| Ontology R-GAT PPO | 72% | 9% | 14% | 5% | 17.873 | 17,001 | 0.196 ms |

- 단일 학습 seed의 최종 체크포인트 평가
- 모델 선택에 사용하지 않은 test seed `3001:3100` 사용
- R-GAT 우월성 미확인
- 다중 학습 seed 평균·분산 검증 필요

### 고정 대표 시나리오 평가

| 시나리오 | Low-level | Semantic-flat | Ontology R-GAT | 안정성 지수 비교 |
|---|---|---|---|---|
| S1 정상 정렬 | 성공 | 비허가 접촉 | 성공 | 88.7 / 85.0 / **93.5** |
| S2 급가속 | 안전 중단 | 성공 | 성공 | 37.9 / **75.9** / 74.5 |
| S3 가시성 손실 | 안전 중단 | 성공 | 성공 | 47.6 / 70.8 / **80.7** |

- 사전 선언 시나리오 사용
- 모델별 동일 물리 조건·센서 이벤트·노이즈 seed 사용
- S1~S3 모두 양의 속도·가속도 authority margin 확인
- S3의 일시적 `LandingInhibit` 원인: sensor dropout

![대표 시나리오 착륙 궤적](ugv_landing_2d_workspace/docs/assets/paper/paper_trajectories.png)

![안정성 지표](ugv_landing_2d_workspace/docs/assets/paper/paper_stability.png)

## 시스템 구조

![전체 파이프라인](ugv_landing_2d_workspace/docs/assets/pipeline.svg)

| 비교군 | Actor/Critic 입력 | 그래프 관계 사용 |
|---|---|---|
| Low-level MLP | 26필드 causal packet | 제외 |
| Semantic-flat MLP | 9노드 × 12특징 평탄화 벡터 | 제외 |
| Ontology R-GAT | 동일한 9노드 × 12특징 + typed relation context | 포함 설계 |

- 행동: 정규화 전 Gaussian 명령 $u_t\in\mathbb{R}^2$
- 환경 명령: $a_t=[a_x,a_z]^\top=\operatorname{diag}(a_{x,\max},a_{z,\max})\tanh(u_t)$
- 정책 주기: 0.10 s
- 물리 주기: 0.01 s
- 실시간 역전파: 제외
- 배포 시 계산: packet 구성, graph 구성, R-GAT 순전파, Actor/Critic 순전파

## 온톨로지 설계

![온톨로지 상황 그래프](ugv_landing_2d_workspace/docs/assets/ontology_graph.svg)

### 노드

| 그룹 | 노드 | 핵심 의미 |
|---|---|---|
| Perception | `PadVisibility` | 검출·bearing·FOV margin·confidence |
| Perception | `ViewRecovery` | 미관측 시간·예측 bearing·복구 긴급도 |
| Tracking | `PadMotion` | 패드 속도·가속도 추정·불확실성 |
| Tracking | `RelativeTracking` | 상대 위치·상대속도·추정 불확실성 |
| Tracking | `TrackingCorrection` | 방향 보존 수평 복구 문맥 |
| Vehicle | `DroneTranslation` | 고도·수평속도·수직속도 |
| Vehicle | `DroneAttitude` | pitch·pitch rate |
| Safety | `DescentEligibility` | 정렬·속도·자세·신뢰도 기반 하강 허용도 |
| Safety | `LandingInhibit` | 일시적 하강 금지·abort 상태 |

### 관계

- 의미 간선 17개
- 자기 간선 9개
- 전체 간선 26개
- 관계 유형: `informs`, `affects_visibility`, `supports`, `inhibits`, `self`
- 임의 역방향 간선 추가 제외
- 고립 노드 제외
- 보상·행동·성공 여부·미래 상태 노드 제외

### 노드 특징

각 노드 특징 $x_i\in\mathbb{R}^{12}$ 구성:

$$
x_i=[p_i,\tilde p_i,s_i,\tilde s_i,m_i,c_i,u_i,\tau_i,q_i,T_i,1,\kappa_i]^\top
$$

- $p_i,s_i$: 주요·보조 의미 크기
- $\tilde p_i,\tilde s_i$: 방향 보존 부호 특징
- $m_i$: 유효성 mask
- $c_i$: 신뢰도
- $u_i$: 불확실성
- $\tau_i$: 변화 추세
- $q_i$: 긴급도
- $T_i$: 잔여 임무시간
- $\kappa_i$: 노드 유형 식별자

## 온톨로지의 강화학습 입력 방식

### Typed R-GAT message passing

관계 $r$을 갖는 간선 $i\rightarrow j$의 attention logit:

$$
e_{ij}^{(r)}=\operatorname{LeakyReLU}\!\left(
{a_r}^{\top}[W_r x_i\,\Vert\,W_r x_j\,\Vert\,E_r]
\right)
$$

관계별 정규화와 노드 갱신:

$$
\alpha_{ij}^{(r)}=
\frac{\exp(e_{ij}^{(r)})}
{\sum_{(k,r')\in\mathcal{N}(j)}\exp(e_{kj}^{(r')})},
\qquad
h_j=\tanh\!\left(\sum_{(i,r)\in\mathcal{N}(j)}
\alpha_{ij}^{(r)}W_r x_i+W_0x_j+b_0\right)
$$

4개 의미 그룹 readout:

$$
c_t=\tanh\!\left(W_g\,
[\bar h_{\mathrm{perception}}\Vert
\bar h_{\mathrm{tracking}}\Vert
\bar h_{\mathrm{vehicle}}\Vert
\bar h_{\mathrm{safety}}]+b_g\right)
$$

### Actor/Critic 결합

Raw semantic bypass $s_t=\operatorname{vec}(X_t)\in\mathbb{R}^{108}$ 보존:

$$
\mu_t=f_{\pi}(s_t)+\delta_t,
\qquad
\delta_t=W_{\pi}c_t
$$

추가 하강 residual의 의미 제약:

$$
\delta_{z,t}^{\mathrm{gate}}=
\begin{cases}
\delta_{z,t}, & \delta_{z,t}\ge 0,\\
E_t\delta_{z,t}, & \delta_{z,t}<0,
\end{cases}
\qquad E_t\in[0,1]
$$

Critic 결합:

$$
V_t=f_V(s_t)+w_V^{\top}c_t
$$

- $E_t$: `DescentEligibility` 첫 번째 특징
- `LandingInhibit=1` 조건의 추가 하강 residual 차단
- 상승·제동·수평 복구 residual 유지
- Actor와 Critic의 독립 encoder·head 적용

## 사전학습과 PPO 학습

- 사전학습 데이터: train seed의 현재 시점 causal graph
- 목표: masked same-time node feature reconstruction
- 입력 제외: 행동, 보상, 성공/실패, 미래 상태, 교사 명령, hidden pad truth
- PPO 초기 90%: raw semantic base 정책 학습
- PPO 마지막 10%: base 고정 후 관계 residual 미세조정
- checkpoint 선택: 100 validation seed와 안전 가중 점수 사용
- test split: checkpoint 선택에서 제외

## 최종 체크포인트 구조 감사

| 항목 | Policy | Value |
|---|---:|---:|
| Graph readout norm $\lVert W_g\rVert_F$ | **0** | **0** |
| Relation head norm | 0.1145 | 0.1026 |
| Relation context | 0 | 0 |
| 활성 관계 residual | 없음 | 없음 |

- 원인: validation 개선 margin을 넘지 못한 관계 단계 대신 flat-equivalent anchor 선택
- 결과: 최종 `context_rgat` 체크포인트의 실제 행동·가치 계산에서 관계 context 미사용
- 허용 주장: 구조 구현·학습 경로·감사 기능 검증
- 제외 주장: 최신 성능 차이가 활성 R-GAT 관계 추론에서 발생했다는 주장
- 재검증 조건: 비영 readout 체크포인트의 다중 seed 학습과 fresh held-out 평가

![온톨로지 정책 추적 및 관계 경로 감사](ugv_landing_2d_workspace/docs/assets/paper/paper_ontology.png)

## 착륙 가능성과 LandingInhibit

- 물리적 착륙 가능성: 정책 독립 authority margin 평가
- 속도 margin: $m_v=(v_{\mathrm{drone,sustain}}-m_{\mathrm{reserve}})-v_{\mathrm{pad,peak}}$
- 가속도 margin: $m_a=a_{x,\max}-a_{\mathrm{pad}}$
- 시간 margin: $m_T=T_{\max}-T_{\mathrm{deadline}}$
- 물리 가능 조건: $m_v\ge0$, $m_a>0$, $m_T\ge0$
- `LandingInhibit`: 영구적 착륙 불가능 판정이 아닌 현재 시점 하강 금지
- 원인 분해: sensor dropout, trajectory/FOV, relative speed, uncertainty/gate

![착륙 가능성과 하강 금지 원인](ugv_landing_2d_workspace/docs/assets/paper/paper_feasibility.png)

## 실행

```matlab
cd('C:\Users\user\Downloads\ugv_landing_2d_workspace_refactor')
run_tests(false)
run_paper
```

창 없이 논문 산출물 저장:

```matlab
run_paper(struct('figureVisible',false))
```

전체 재학습:

```matlab
run_all(struct('executionMode','full','rlRetrain',true))
```

산출물 위치: `results/paper/`

- `paper_trajectories.*`: 대표 시나리오 궤적
- `paper_stability.*`: 안정성 지표
- `paper_feasibility.*`: 물리 가능성·하강 금지 원인
- `paper_ontology.*`: 온톨로지 신호·관계 residual 감사
- `paper_stability_metrics.csv`: 수치 원본
- `paper_architecture_audit.csv`: 관계 경로 활성 여부

## 최종 문서

- [최종 구현·결과 보고](ugv_landing_2d_workspace/docs/refactor/FINAL_REPORT.md)
- [시스템 명세](ugv_landing_2d_workspace/docs/refactor/SYSTEM_SPEC.md)
- [온톨로지·R-GAT 상태 설계](ugv_landing_2d_workspace/docs/ONTOLOGY_GRAPH_STATE_KO.md)
- [보상 함수 근거](ugv_landing_2d_workspace/docs/refactor/REWARD_RATIONALE.md)
- [설정·데이터 계약](ugv_landing_2d_workspace/docs/refactor/CONFIGURATION.md)
- [검증 범위와 결과](ugv_landing_2d_workspace/docs/VALIDATION_KO.md)
- [모듈 지도](ugv_landing_2d_workspace/docs/MODULE_MAP_KO.md)

## 제한

- 2차원 연구용 시뮬레이터
- 이상적 own-state 관측 사용
- 실제 비행 안전성 인증 제외
- 단일 학습 seed 최종 결과
- R-GAT 관계 경로 비활성 최종 체크포인트
- 보편적 우월성 주장 제외
