# 최종 코드 모듈 지도

## 결론

- 기본 진입점: `run_all.m`
- 논문 진입점: `run_paper.m`
- 고정 시나리오 검증: `run_paper_validation.m`
- 공통 환경: `+environment`
- causal sensing: `+sensing`
- 온톨로지 상태: `+graphstate`
- 관계 연산: `+rgat`
- PPO: `+rl`
- 논문 metric·plot: `+paper`

## 실행 파일

| 파일 | 역할 |
|---|---|
| `setup_project.m` | root와 `src` 경로 등록 |
| `run_all.m` | 기본 full A/B/C 학습·평가 |
| `run_planar_visibility.m` | `planar_visibility_v2` 실행 |
| `run_finalTest.m` | 최종 checkpoint 실시간 비교 |
| `run_paper.m` | 논문 figure·CSV·MAT 생성 |
| `run_paper_validation.m` | 고정 3시나리오 공정 비교 |
| `run_multiseed_study.m` | 다중 PPO seed 연구 |
| `run_graph_ablation.m` | node-pool·GAT·R-GAT 제거 실험 |
| `run_tests.m` | 회귀 테스트 통합 실행 |

## 설정

| 코드 | 역할 |
|---|---|
| `+config/primaryConfig.m` | 최종 실험 설정 조립 |
| `+config/defaultPlanarVisibilityConfig.m` | 환경·센서·안전·보상 기본값 |
| `+rl/defaultRlConfig.m` | PPO 기본값 |
| `+rl/applyScratchSettings.m` | 2,500회 scratch 설정 |
| `+graphstate/defaultGraphStateConfig.m` | R-GAT·readout·사전학습 설정 |

## 환경·시나리오

| 코드 | 역할 |
|---|---|
| `+environment/reset.m` | scenario·sensor event·초기 packet 생성 |
| `+environment/step.m` | 정책 action hold·물리 적분·reward·terminal |
| `+environment/updateDecisionContext.m` | `LandingInhibit`·abort 요청 갱신 |
| `+environment/evaluateTermination.m` | 접촉·timeout·safety 사건 판정 |
| `+environment/taskFingerprint.m` | A/B/C 공통 문제 계약 지문 |
| `+scenario/sampleParameters.m` | CV–CA–CV parameter sampling |
| `+scenario/evaluateTrajectory.m` | 연속 위치·속도·가속도 계산 |

## 동역학·제어

| 코드 | 역할 |
|---|---|
| `+dynamics/stepPlanar.m` | pitch/thrust planar dynamics |
| `+control/safetySupervisor.m` | causal recovery·descent veto |
| `+control/pnGuidanceV2.m` | V2 PN 기준 유도 |

## 센서·관측 기억

| 코드 | 역할 |
|---|---|
| `+sensing/observationSchema.m` | 26필드 single source of truth |
| `+sensing/projectPad.m` | body-fixed camera projection |
| `+sensing/generateMeasurement.m` | noisy bearing·relative position 생성 |
| `+sensing/initialPadTrack.m` | causal memory 초기화 |
| `+sensing/updatePadTrack.m` | 위치·속도·가속도 추정 갱신 |
| `+sensing/buildPacket.m` | Actor/Critic용 causal packet 구성 |
| `+sensing/normalizePacket.m` | finite signed normalization |
| `+sensing/sampleEvents.m` | dropout·pitch event 사전 결정 |

## 온톨로지 그래프 상태

| 코드 | 역할 |
|---|---|
| `+graphstate/contextSchema.m` | 9노드·17관계·9 self-edge 정의 |
| `+graphstate/contextGraph.m` | packet → $12\times9$ 특징 텐서 |
| `+graphstate/applyStateRepresentation.m` | baseline·flat·R-GAT 분기 |
| `+graphstate/encoderInit.m` | graph encoder·group readout 초기화 |
| `+graphstate/encoderForward.m` | message passing·raw bypass 순전파 |
| `+graphstate/encoderBackward.m` | PPO gradient 역전파 |
| `+graphstate/pretrainCausalEncoder.m` | masked same-time reconstruction |
| `+graphstate/assertSameProblem.m` | 보상·행동·환경 동일성 검사 |

## R-GAT

| 코드 | 역할 |
|---|---|
| `+rgat/topology.m` | typed edge topology 구성 |
| `+rgat/relationForward.m` | relation attention 순전파 |
| `+rgat/relationBackward.m` | relation attention 역전파 |

## PPO

| 코드 | 역할 |
|---|---|
| `+rl/agentInit.m` | Actor·Critic·encoder 생성 |
| `+rl/policyAction.m` | base mean + relation residual 계산 |
| `+rl/relationPolicyResidual.m` | `DescentEligibility` gate 적용 |
| `+rl/valueForward.m` | base value + relation value 계산 |
| `+rl/rolloutEpisodeV2.m` | 공통 V2 rollout |
| `+rl/computeReward.m` | 공통 reward 계산 |
| `+rl/computeAdvantage.m` | variable-time GAE |
| `+rl/ppoTrain.m` | scratch PPO·checkpoint 선택 |
| `+rl/evaluateV2.m` | validation·test 평가 |
| `+rl/profileAgent.m` | inference time·parameter count |
| `+rl/loadCheckpoint.m` | signature 검증 후 load |

## 논문 평가·시각화

| 코드 | 역할 |
|---|---|
| `+paper/representativeScenarios.m` | S1~S3 고정 정의 |
| `+paper/scenarioFeasibility.m` | speed·acceleration·time margin |
| `+paper/trajectoryMetrics.m` | 안정성·FOV·inhibit 원인 계산 |
| `+paper/plotStudy.m` | 4종 논문 figure 생성 |

산출물:

- `paper_trajectories.png/pdf/fig`
- `paper_stability.png/pdf/fig`
- `paper_feasibility.png/pdf/fig`
- `paper_ontology.png/pdf/fig`
- `paper_stability_metrics.csv`
- `paper_architecture_audit.csv`
- `paper_validation.mat`

## 최종 데이터 흐름

```text
environment.reset
→ sensing.generateMeasurement
→ sensing.updatePadTrack
→ sensing.buildPacket
→ baseline: normalizePacket
  또는 contextGraph
→ policyAction / valueForward
→ safetySupervisor
→ dynamics.stepPlanar
→ computeReward / evaluateTermination
```

## 변경 위치 선택

| 변경 목적 | 우선 파일 |
|---|---|
| 센서 필드 추가 | `observationSchema.m`, `buildPacket.m`, `normalizePacket.m` |
| 온톨로지 노드 추가 | `contextSchema.m`, `contextGraph.m` |
| 관계 추가 | `contextSchema.m` |
| Actor graph 결합 변경 | `encoderForward.m`, `policyAction.m` |
| Critic graph 결합 변경 | `encoderForward.m`, `valueForward.m` |
| 하강 제약 변경 | `relationPolicyResidual.m` |
| 보상 변경 | `computeReward.m`, algorithm version·signature |
| 시나리오 변경 | `sampleParameters.m`, `evaluateTrajectory.m` |
| 논문 metric 변경 | `trajectoryMetrics.m` |
| 논문 plot 변경 | `plotStudy.m` |

## 레거시 경로

- 호출: `run_all(struct('experimentVersion','legacy_v1'))`
- 기본 연구 결론 사용 제외
- 11차원 관측·온톨로지 보상 가중치 문서 사용 제외
- 회귀 보존 목적 한정
