# UGV 착륙 2D 연구 개요

## 요약

- 연구 문제: 가속 UGV 이동 패드에 대한 2차원 드론 착륙의 부분관측 강화학습
- 비교 원리: 환경·센서·추정기·보상·안전 감독기 $\Pi_s$ 동일, Actor/Critic 상태 표현만 변경
- 비교군: 저수준 관측 $o_t$ MLP, semantic-flat $s_t$ MLP, ontology R-GAT($s_t$ + $c_t$) PPO
- 관계 경로: Actor·Critic 양쪽 그룹 readout $W_c$ 비영 활성
- 관계 readout 축소 배율: $\nu_{rel}=0.001$
- 시험 결과: 성공률 72–75%의 유사 수준, R-GAT 우월성 미확인
- 결과 기준: 시험 seed 집합 $\mathcal S_{te}=\{3001,\dots,3100\}$ 100개

## 문제 정의

- 결론: 시나리오 분포 $\mathcal D$ 위의 가변 시간 할인 POMDP

| 요소 | 정의 |
|---|---|
| 은닉 상태 | 드론 상태 $\xi$, 패드 운동 $(x_p,v_p,a_p)$, 시나리오 $\sigma=(v_1,a_2,T_1,T_2,T_3,h_0)$, 센서·외란 일정 |
| 관측 | 하향 카메라 측정 $(d_k,\tilde e_{x,k},\tilde\beta_k,c_k)$ + 이상적 자기 상태 |
| 정책 입력 | 추정 $\hat\chi$ 경유 인과 관측 패킷 $o_t\in\mathbb R^{26}$, 또는 그래프 상태 $X_t\in\mathbb R^{12\times9}$ |
| 행동 | $u_t\in\mathbb R^2$, $a_t=\mathrm{diag}(a_{x,\max},a_{z,\max})\tanh(u_t)$ |
| 전이 | $\Delta t_p=0.10$ s zero-order hold, $\Delta t_s=0.01$ s 단위 감독기·동역학·인지 갱신 |
| 보상·할인 | 세 비교군 공통 $r_t$, $\gamma_{\Delta t}=\exp(-\Delta t/\tau_\gamma)$ |
| 종료 | SUCCESS, SAFE_ABORT, TASK_TIMEOUT, UNSAFE_CONTACT, UNAUTHORIZED_CONTACT, MISSED_PAD_CONTACT, SAFETY_ENVELOPE_VIOLATION |

- 정보 경계: 패드 참값의 정책·그래프·감독기 입력 제외, 보상·평가에만 사용

## 방법 개요

- 결론: 인지→추정→그래프→정책→감독기→동역학의 폐루프, R-GAT는 gate 적용 관계 residual만 추가

**Algorithm 1. 결정 1회**

1. 인지: 하향 카메라 기하 투영 검출, dropout $\delta_k$ 적용
2. 추정: 등가속도 예측 + innovation 이득 $k_p,k_v,k_a$ 보정으로 $\hat\chi$ 갱신
3. 관측 구성: $o_t\in\mathbb R^{26}$
4. 그래프 구성: 9노드·26간선·5관계 유형 $\mathcal G$, $s_t=\mathrm{vec}(X_t)$
5. 관계 문맥: R-GAT attention $\alpha^{(r)}_{ij}$·그룹 readout으로 $c_t\in\mathbb R^4$
6. 정책: $\mu_t=f_\pi(s_t)+\tilde\delta_t$, 하강 방향 residual에 하강 허용 gate $g_t$ 적용
7. 감독기: $\tilde a_k=\Pi_s(a_t,\xi_k,o_k)$, 하강 차단·제동·복구 상승
8. 동역학: pitch·추력 setpoint $(\theta^{sp},F^{sp})$ 변환 후 적분, 종료 판정

**Algorithm 2. 학습**

1. 그래프 사전학습 (R-GAT 한정): $\mathcal S_{tr}$ 인과 그래프의 masked 노드 특징 재구성
2. PPO 2,500 iteration × 6 에피소드, 성능 기반 커리큘럼 난이도 $\ell$
3. 마지막 10%: raw semantic MLP 고정, 관계 파라미터만 적응
4. 25 iteration마다 $\mathcal S_{val}=\{2001,\dots,2100\}$ 평가, $\ell\ge1$ 정책 중 최고 선택 점수 $J$ 보존
5. 관계 경로 성능 가드: $\nu_{rel}$ 내림차순 탐색, 검증 결과율 비악화 최대 배율 채택
6. 최종 평가: $\mathcal S_{te}$ 결정론적 rollout

## 결과

- 결론: 세 비교군 시험 성공률 3%p 이내, R-GAT는 대표 시나리오 S1~S3 전 성공

| 모델 | 성공 $p_s$ | 위험 $p_u$ | 안전 중단 $p_a$ | 시간 초과 $p_\tau$ | 평균 return $\bar G$ |
|---|---:|---:|---:|---:|---:|
| Low-level MLP | 74% | 2% | 23% | 1% | 19.139 |
| Semantic-flat MLP | 75% | 9% | 13% | 3% | 18.496 |
| Ontology R-GAT | 72% | 9% | 14% | 5% | 17.930 |

- 단일 학습 seed 결과
- 다중 학습 seed 평균·분산 검증 필요

![Monte Carlo 평가](docs/assets/paper/planar_visibility_monte_carlo.png)

![대표 시나리오](docs/assets/paper/paper_trajectories.png)

![온톨로지 관계 경로](docs/assets/paper/paper_ontology.png)

## 문서

- [전체 README](README.md)
- [연구 결과 보고](docs/refactor/FINAL_REPORT.md)
- [시스템 모델](docs/refactor/SYSTEM_SPEC.md)
- [온톨로지 상태 설계](docs/ONTOLOGY_GRAPH_STATE_KO.md)
- [보상 설계](docs/refactor/REWARD_RATIONALE.md)
- [평가 프로토콜·결과](docs/VALIDATION_KO.md)
- [알고리즘 구성](docs/MODULE_MAP_KO.md)
- [관계 해석 지표](docs/ONTOLOGY_VIEW_KO.md)
- [기호 정의](docs/NOTATION_KO.md)
- [문서 색인](docs/README.md)
