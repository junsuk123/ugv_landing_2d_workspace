# T01: 비교군 registry·고정 관계 교란·체크포인트 분리

## 요약

- 범위: 2차원 계약 한정, 3차원 옵션은 기존 비교군·체크포인트·수치 유지 (3차원 fingerprint·학습 서명·관측·보상 비트 동일 확인)
- 정책 입력 전환: 2차원 세 비교군의 입력을 24차원 공통 관측 $o_t$로 통일, RGAT 그래프는 같은 $o_t$에서 생성
- 공식 비교군: 일반 PPO(`ppo`), 온톨로지-RGAT PPO(`onto_rgat_ppo`), 관계 교란 RGAT PPO(`shuffled_rgat_ppo`), context_flat 제외 (코드 경로 유지)
- 변경 (2026-10-08, 사용자 결정): 관계 교란 RGAT PPO를 공식 비교군에서 제외하고 절제 실험(`registry.ablations`)으로만 유지, 공식 비교군은 두 개 (T03 문서 7.5절)
- 변경 (2026-10-08): RGAT 그래프 노드 특징 척도 수정 `forward_camera_v2` (T03 문서 7절)
- 성능 수치: 없음 (학습 미실행, smoke 1회 반복 결과는 실행 확인 전용)

## 1. 정책 입력

| 비교군 | 상태 | 차원 |
|---|---|---:|
| 일반 PPO | `toVector(o_t, Gamma)` | 24 |
| 온톨로지-RGAT PPO | `observationGraph(o_t)`: 9노드 × 12채널 | 108 |
| 관계 교란 RGAT PPO | 같은 노드 특징, 관계 type_id 배치만 교란 | 108 |

- 스키마: `experiment.observationSchema` = `landing2d.observation.vectorSchema` (`common_observation_v2`), `rl.observationDim`은 스키마에서 계산
- 그래프: `contextSchema(mode,2,'commonObservation')`, 노드·관계·간선 26개·readout 그룹·12채널 형식은 packet 그래프와 동일, 정적 채널 `remainingTime` → `visionAge` (남은 임무 시간은 $o_t$에 없음), 변형 `compact_context_graph_v4_common_observation`
- 노드 특징 원천: UGV 추정 위치·속도·영상 보정 여부·경과시간, 융합 측위, 직전 UGV 속도(가속 추세), $\Gamma$의 패드 장착 오프셋, 공개 설정(카메라 기하·동역학 한계·안전 임계값)
- 결정 문맥 플래그: 정책 입력에서 제외, 착륙 금지 근거는 영상 경과시간과 공개 승인 규칙(최근 0.5 s, 손실 3 s)으로 그래프에서 구성
- 입력 경계: `observationGraph`는 등록된 $o_t$ 필드 외 입력 거부
- packet: 환경 내부 기록·3차원 정책 입력으로 유지

## 2. 비교군 registry

- 단일 정의: `landing2d.config.methodRegistry` (method_id, 한글 표시 이름, stateRepresentation, 교란 종류, 색·선 스타일·marker, 시드 계획)
- 시드 계획: 학습 시드 예비 1–5·본 1–10, 그래프 시드 1–3 (표본 수 계획, 통계적 충분성 보장 아님)
- 실행 설정: `landing2d.config.applyMethod(cfg, method_id, train_seed, graph_seed)`
- 실행 목록: `landing2d.config.comparisonArms`, `trainEvaluate`·`validateStudy`·`runLive` 공용
- 학습 시드: `rl.seed` = 기준 시드 + train_seed − 1 (train_seed 1 = 기존 기준 시드)
- 교란군: 별도 비교군 여러 개가 아닌 `shuffled_rgat_ppo` 내부의 graph_seed 반복

## 3. 고정 관계 교란

- 구현: `landing2d.rgat.applyRelationPerturbation`, `encoderInit`에서 1회 적용 후 `encoderSpec.schema`·`encoderSpec.T`·`encoderSpec.graph`에 저장
- 대상: 의미 간선 17개의 관계 type_id, 자기 간선 9개 보호
- 유지: 노드 특징·노드 순서·src/dst·노드 수·간선 수·관계별 간선 수(informs 13, affects_visibility 2, supports 1, inhibits 1, self 9)·네트워크 구조·초기 가중치
- 거부: 원 배치, 관계 이름 전역 치환으로 같은 배치 (supports↔inhibits 교환)
- 고정: graph_seed 난수열로 결정, 사전학습·PPO·검증·시험·추론 동일, 매 프레임·에피소드 재순열 없음
- 해시: `encoderSpec.graph.hash` = SHA-256 (노드 이름·관계 이름·src·dst·rel의 JSON)
- 학습 서명: `graphState.relationPerturbation` 포함, 교란 비교군에만 존재
- 로드 검증: `landing2d.rl.verifyCheckpointGraph`가 설정 그래프와 저장 그래프 해시·type_id 불일치 거부

## 4. 체크포인트·실행 식별

- 파일: `<outputDir>/checkpoints/<method_id>_s<train_seed>[_g<graph_seed>].mat`
- 내용: `agent`(실제 그래프 포함), `info`, `signature`, `run`
- `run` (`landing2d.rl.runIdentity`): method_id, 표시 이름, stateRepresentation, 교란 종류, train_seed, graph_seed, 학습 난수 시드, graph_hash, type_id 배열, 체크포인트 파일·SHA-256, 관계 경로 필요·활성 여부
- 학습 요약표(2차원): MethodId, TrainSeed, GraphSeed, GraphHash, RelationalPathActive 열 추가
- 진단: `evaluateV2`의 그래프 스키마는 에이전트 저장 그래프 사용

## 5. 함께 바뀐 항목

- 롤아웃 기록: `traj.landingInhibited`(결정 중 착륙 금지), 측정 가시성 `visible` = 마커 카메라 영상 보정 여부 (3차원은 tracker 검출)
- 지표·그림: 착륙 금지율을 정책 관측 채널 대신 롤아웃 기록에서 계산 (`landing2d.paper.inhibitedRecord`)
- S3: 0.8 s dropout 유지, 대표 시나리오 주석을 사실대로 수정 (short 범위 0.2–0.5 s 밖, 최근 영상 0.5 s 유예를 넘겨 LandingInhibit 발생, 3 s 복구 미발생)

## 6. 검증

- self-test 11개 통과: `contract`(24차원·세 비교군·fingerprint 동일·체크포인트·서명 분리), `causal-boundary`, `context-graph`(packet 없이 생성, 교란 무관 노드 특징), `ppo-smoke`, `spatial-3d`, `common-observation`, `relation-shuffle` 등
- `relation-shuffle`: src/dst·관계별 개수·자기 간선 보호, 원 배치·supports↔inhibits 교환 배치 미생성(graph_seed 1–60), 재현성, 그래프 시드별 해시 상이, 초기 가중치 동일, 같은 입력에 대한 인코더 출력 상이, 사전학습+PPO 후 그래프 유지, 체크포인트 그래프 교차 사용 거부
- 3차원: 변경 전 기준과 fingerprint·학습 서명 3개·관측·보상·종료·최종 상태 비트 동일
- 2차원 환경: 스크립트 비행(검증 시드 2001–2040) 착륙·감독기 개입·추정 RMSE 이전 라운드와 동일
- smoke 파이프라인: 세 비교군 학습·평가 실행, 비교군별 체크포인트·graph_hash 분리
- S3 실행 확인: 1회 반복 smoke 체크포인트로 `run_scenario('S3')` 실행 (수치 무의미)

## 7. 확인된 위험

- smoke에서 두 RGAT 비교군의 관계 경로 비활성(`Wg` = 0) → 두 비교군의 행동이 동일 (관계 경로가 출력에 닿지 않으면 교란이 결과에 영향 없음), 본 학습 후 비교군별 활성 진단 필수
- 학습 커리큘럼 초기 고도 0.025–1.0 m: 전방 카메라 사각지대 시작 시 첫 관측 불가
- Simulink 백엔드: 24차원 관측·인지 기반 감독기 미반영
