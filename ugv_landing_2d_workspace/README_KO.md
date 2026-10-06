# UGV 착륙 2D 최종 실행 안내

## 핵심 상태

- 기본 실험: `planar_visibility_v2`
- 최종 알고리즘: `planar-visibility-ppo-v2.8`
- 비교군: baseline·semantic-flat·ontology R-GAT PPO
- 기본 실행: self-test→scratch 학습→validation→held-out test→시각화
- 진입점: `run.m`·`run_scenario.m`·`run_live.m`
- 최종 계약 검사: 8/8 통과
- 관계 경로: Policy/Value readout 비영점·`ACTIVE`
- 결과 기준: test seed `3001:3100` 100개

## 기본 실행

```matlab
cd ugv_landing_2d_workspace   % 이 폴더(run.m 위치)로 이동
run
```

- 기본값: `full`
- scratch 재학습: 활성
- 세 모델 순차 학습: 활성
- validation·test: 활성
- 논문 그림 생성: 활성
- 실시간 학습 대시보드: 활성
- 옵션: `executionMode`(`'full'`·`'smoke'`), `retrain`, `runSelfTest`, `generatePaper`, `figureVisible`, `saveResults`, `showLiveDashboard`, `profileRepetitions`(기본 500), `trainingOptions`
- 산출물: `results/` checkpoint·요약 CSV·Monte Carlo PNG, `results/paper/` 논문 그림·CSV

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

- 옵션: `figureVisible`(기본 `true`), `saveResults`(기본 `false`, 활성 시 `results/scenario/`), `profileRepetitions`(기본 100)

## 실시간 세 비교군 테스트

```matlab
run_live            % S3, 실제 시간 재생
run_live('S2')      % 고정 대표 시나리오
run_live(3001)      % held-out test seed
run_live('S1',struct('playbackSpeed',4,'videoFile','results/live_s1.mp4'))
```

- 세 checkpoint를 같은 시나리오·센서 이벤트·잡음으로 10 Hz lockstep 실행
- 비교군별 드론·UGV·FOV·궤적과 수평 오차·고도·속도 시계열 표시
- 옵션: `playbackSpeed`(기본 1, `Inf`=대기 없음), `viewHalfWidth`(기본 15 m), `videoFile`, `checkpointDir`(기본 `results/`), `showFullTrajectoryAtEnd`(기본 `true`)
- 결과 표: workspace 변수 `landingLive`

## 온톨로지·R-GAT 전체 시각화

```matlab
addpath(fullfile(pwd,'src','orchestration'), ...
    fullfile(pwd,'src','simulations'),fullfile(pwd,'src','algorithms'))
view = landing2d.viz.ontologyRgatExplorer();
```

- 단일 코드: `src/orchestration/+landing2d/+viz/ontologyRgatExplorer.m`
- 탭 1: 의미 그룹 카드·typed relation 행렬·causal provenance·26개 간선 전체 목록
- 탭 2: 저장 체크포인트 기반 Actor/Critic 관계별 attention 누적 막대와 원본 행렬
- 탭 3: 대표 상태의 12×9 특징 텐서·4개 그룹 readout·관계별 사용량
- 탭 4: 전체 간선 score·attention·message와 학습 파라미터 목록
- 기본 스냅샷: S3 가시성 복구 구간의 최대 복구 필요 시점

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
- [온톨로지 시각화 안내](docs/ONTOLOGY_VIEW_KO.md)
- [문서 색인](docs/README.md)
