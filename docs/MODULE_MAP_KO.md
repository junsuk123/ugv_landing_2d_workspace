# 최종 모듈 지도

## 실행 흐름

`run.m → selfTest → train/load → validation checkpoint 선택 → held-out test → 결과·그림`

정책 결정:

`marker/navigation → PnP/KF → 12-D o_t → PPO 또는 v3.19 ontology/R-GAT → [a_x,a_z] → dynamics → mechanical termination`

조건부 분산 평가:

`run_trajMC.m → same-train-seed checkpoint pair → fixed scenario/events → paired sensor noise → absolute plot + pad-relative metrics`

## 소스 책임

| 영역 | 경로 | 책임 |
|---|---|---|
| orchestration | `src/orchestration/+landing2d` | 설정, 실행, 검증, 결과 저장, 시각화 |
| simulations | `src/simulations/+landing2d` | 동역학, 센서, 추정, 관측, 환경, 종료 |
| algorithms | `src/algorithms/+landing2d` | PPO, graph state, R-GAT, RL Toolbox 변환 |

## 단일 정의

- 비교군: `landing2d.config.methodRegistry`
- 공통 관측: `landing2d.observation.vectorSchema`
- v3.19 graph: `landing2d.graphstate.observationVectorGraph`
- 그래프 스키마: `landing2d.graphstate.contextSchema`
- reward: `landing2d.rl.computeReward`
- 종료: `landing2d.environment.evaluateTermination`
- Simulink signal: `landing2d.simulink.signalCodec`
- 최종 trajectory metric: `run_trajMC.m`, `landing2d.metrics.validationTrajectoryRobustness`

## 사용자 진입점

```matlab
run
run_scenario('S3')
run_live('S3')
run_trajMC
```

루트에는 이 네 사용자 진입점 외 MATLAB 파일을 추가하지 않는다.
