# UGV 착륙 2D 최종 실행 안내

## 핵심 상태

- 기본 실험: `planar_visibility_v2`
- 최종 알고리즘: `planar-visibility-ppo-v2.8`
- 비교군: baseline·semantic-flat·ontology R-GAT PPO
- 기본 실행: self-test→scratch 학습→validation→held-out test→시각화
- 최종 계약 검사: 8/8 통과
- 관계 경로: Policy/Value readout 비영점·`ACTIVE`
- 결과 기준: test seed `3001:3100` 100개

## 기본 실행

```matlab
cd('C:\Users\user\Downloads\ugv_landing_2d_workspace_refactor')
run
```

- 기본값: `full`
- scratch 재학습: 활성
- 세 모델 순차 학습: 활성
- validation·test: 활성
- 논문 그림 생성: 활성
- 실시간 학습 대시보드: 활성

빠른 구조 검사:

```matlab
run(struct('executionMode','smoke','generatePaper',false, ...
    'figureVisible',false,'saveResults',false,'showLiveDashboard',false))
```

저장 checkpoint 재사용:

```matlab
run(struct('retrain',false))
```

## 특정 시나리오

```matlab
run_scenario('S1')  % 정상 정렬
run_scenario('S2')  % 급가속
run_scenario('S3')  % 가시성 손실·재포착
```

## 소스 구조

```text
src/
├─ orchestration/  실행·설정·검증·시각화
├─ simulations/    환경·동역학·센서·시나리오
└─ algorithms/     PPO·온톨로지·R-GAT
```

상세 구조: [최종 코드 구조](docs/MODULE_MAP_KO.md)

## 최신 결과

| 모델 | 성공 | 위험 | 안전 중단 | 시간 초과 | 평균 return |
|---|---:|---:|---:|---:|---:|
| Baseline | 74% | 2% | 23% | 1% | 19.139 |
| Semantic-flat | 75% | 9% | 13% | 3% | 18.496 |
| Ontology R-GAT | 72% | 9% | 14% | 5% | 17.930 |

![Monte Carlo 평가](docs/assets/paper/planar_visibility_monte_carlo.png)

![대표 시나리오](docs/assets/paper/paper_trajectories.png)

![온톨로지 관계 경로](docs/assets/paper/paper_ontology.png)

## 문서

- [전체 README](../README.md)
- [최종 보고](docs/refactor/FINAL_REPORT.md)
- [온톨로지 상태 설계](docs/ONTOLOGY_GRAPH_STATE_KO.md)
- [검증 결과](docs/VALIDATION_KO.md)
- [최종 코드 구조](docs/MODULE_MAP_KO.md)
