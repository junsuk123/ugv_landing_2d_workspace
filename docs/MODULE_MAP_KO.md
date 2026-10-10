# 모듈 구성

## 실행 흐름

`run.m` → `runPipeline` → self-test → train/load → validation checkpoint 선택 → held-out test → 결과·그림 저장.

정책 결정 흐름:

`sensor → PnP/KF + navigation → 12-D o_t → PPO 또는 ontology graph/R-GAT → [a_x,a_z] → dynamics → mechanical termination`

## 소스 책임

| 영역 | 경로 | 책임 |
|---|---|---|
| orchestration | `src/orchestration/+landing2d` | 설정, 실행, 검증, 결과 저장, 시각화 |
| simulations | `src/simulations/+landing2d` | 동역학, 센서, 추정, 관측, 환경, 종료 |
| algorithms | `src/algorithms/+landing2d` | PPO, ontology, graph state, R-GAT, RL Toolbox 변환 |

## 주요 단일 정의

- 비교군: `landing2d.config.methodRegistry`
- 공통 관측: `landing2d.observation.vectorSchema`
- 7노드 그래프: `landing2d.graphstate.contextSchema`
- 그래프 특징: `landing2d.graphstate.observationVectorGraph`
- reward: `landing2d.rl.computeReward`
- 종료: `landing2d.environment.evaluateTermination`
- Simulink 신호: `landing2d.simulink.signalCodec`

## 진입점

```matlab
run
run(struct('executionMode','smoke','generatePaper',false, ...
    'figureVisible',false,'saveResults',false,'showLiveDashboard',false))
run_scenario('S1')
run_live('S1')
```

최신 결과만 보기:

```matlab
run(struct('latestOntology',true,'figureVisible',true))
```
