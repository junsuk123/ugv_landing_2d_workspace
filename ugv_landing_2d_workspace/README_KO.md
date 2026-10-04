# UGV 착륙 2D 최종 실행 안내

## 핵심 상태

- 기본 실험: `planar_visibility_v2`
- 최종 알고리즘: `planar-visibility-ppo-v2.8`
- 공통 행동: 수평·수직 가속도 $[a_x,a_z]$
- 공통 관측 원천: 카메라·own-state·causal observation memory
- 비교 모델: baseline, semantic-flat, ontology R-GAT
- 논문용 실행: `run_paper`
- 최신 검증: 비그래픽 28/28·그래픽 포함 33/33 통과
- 관계 경로: 성능 가드 기반 비영 readout 활성
- 중요 제한: relation scale 0.001의 작은 신뢰구간
- 문서 결과 갱신: 2026-10-04 14:52 KST

## 빠른 실행

```matlab
cd('C:\Users\user\Downloads\ugv_landing_2d_workspace_refactor')
run_paper
```

기존 비활성 R-GAT 체크포인트의 안전 활성화:

```matlab
run_activate_rgat_checkpoint
```

창 없이 결과 저장:

```matlab
run_paper(struct('figureVisible',false))
```

전체 회귀 검사:

```matlab
run_tests(false)
```

전체 A/B/C 재학습:

```matlab
run_all(struct('executionMode','full','rlRetrain',true))
```

최종 체크포인트 실시간 비교:

```matlab
run_finalTest
```

## 비교 구조

![전체 파이프라인](docs/assets/pipeline.svg)

| 모델 | 정책 상태 | 목적 |
|---|---|---|
| Baseline | 26필드 causal packet | 저수준 관측 기준군 |
| Semantic-flat | 9노드 × 12특징 평탄화 | 의미 정보 효과 분리 |
| Ontology R-GAT | 동일 특징 + typed message passing | 관계 구조 효과 검증 |

- 보상·환경·행동·종료·안전 감독기 공통
- 모방학습 제외
- 각 모델 scratch PPO 2,500회 설정
- validation 기반 checkpoint 선택
- fresh test split 기반 최종 평가

## 온톨로지 구성

![온톨로지 상황 그래프](docs/assets/ontology_graph.svg)

- 의미 노드 9개
- 관계 간선 17개
- 자기 간선 9개
- 전체 간선 26개
- 관계 유형 5개
- 특징 텐서 크기 $12\times9=108$
- readout 그룹 4개: Perception, Tracking, Vehicle, Safety
- hidden truth·미래 상태·보상·행동·성공 라벨 제외

## 강화학습 결합

Raw semantic state:

$$
s_t=\mathrm{vec}(X_t)\in\mathbb{R}^{108}
$$

R-GAT relation context:

$$
c_t=\tanh(W_g\mathrm{GroupReadout}(H_t)+b_g)
$$

Actor:

$$
\mu_t=f_{\pi}(s_t)+W_{\pi}c_t
$$

Critic:

$$
V_t=f_V(s_t)+w_V^\top c_t
$$

하강 residual 제약:

$$
\delta_{z,t}^{\mathrm{gate}}=
\begin{cases}
\delta_{z,t}, & \delta_{z,t}\ge0,\\
E_t\delta_{z,t}, & \delta_{z,t}<0
\end{cases}
$$

- $E_t$: causal `DescentEligibility`
- `LandingInhibit` 조건의 추가 하강 차단
- 상승·제동·수평 복구 유지

## 논문용 결과

![대표 시나리오 궤적](docs/assets/paper/paper_trajectories.png)

![안정성 지표](docs/assets/paper/paper_stability.png)

![착륙 가능성 분석](docs/assets/paper/paper_feasibility.png)

![온톨로지 신호와 관계 경로 감사](docs/assets/paper/paper_ontology.png)

![Monte Carlo 평균·1시그마 궤적](docs/assets/paper/planar_visibility_monte_carlo.png)

## 결과 해석

- S1: R-GAT 성공·안정성 지수 최고
- S2: semantic-flat과 R-GAT 성공
- S3: semantic-flat과 R-GAT 성공, R-GAT 안정성 지수 최고
- 전체 100 test seed: semantic-flat 75%, baseline 74%, R-GAT 72% 성공
- 단일 seed 결과 기반 우월성 주장 제외
- 최종 R-GAT Policy/Value `Wg` norm 0.0001665/0.0006056
- test 결과율 유지·평균 return 17.873→17.930
- 500회 정책 추론 프로파일: baseline 0.150 ms·semantic-flat 0.163 ms·R-GAT 0.253 ms
- 활성 관계 경로 확인·보편적 우월성 주장 제외

## 문서 연결

- [전체 README](../README.md)
- [최종 보고](docs/refactor/FINAL_REPORT.md)
- [온톨로지 상태 설계](docs/ONTOLOGY_GRAPH_STATE_KO.md)
- [시스템 명세](docs/refactor/SYSTEM_SPEC.md)
- [검증 결과](docs/VALIDATION_KO.md)
- [코드 모듈 지도](docs/MODULE_MAP_KO.md)
