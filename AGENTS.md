# 최종 코드 유지 가이드

## 적용 범위

- 기본 실험: `planar_visibility_v2`
- 단일 진입점: `run.m`
- 단일 시나리오 진입점: `run_scenario.m`
- 실시간 비교 진입점: `run_live.m`
- 비교군(2차원): 일반 PPO(`ppo`), 온톨로지-RGAT PPO(`onto_rgat_ppo`), 단일 정의 `landing2d.config.methodRegistry`
- 관계 교란 RGAT PPO(`shuffled_rgat_ppo`): 2026-10-08 공식 비교군 제외, `registry.ablations`의 절제 실험으로만 유지(id 명시 시 `applyMethod`·`trainCampaign`·`evaluateRuns`·`closedLoopJerk` 사용 가능, 기본 학습·평가·그림 제외)
- 비교군(3차원 옵션): 기존 baseline, semantic-flat, ontology R-GAT PPO 유지
- 공통 계약: 동일 환경·센서·보상·행동·종료. 평면 direct-policy에는 안전 감독기·착륙 승인·SAFE_ABORT 가드 없음(3차원 옵션은 기존 감독기 유지)
- 핵심 차이: Actor/Critic 상태 표현
- 학습 백엔드: MATLAB PPO 기본, Simulink 모델 + RL Toolbox PPO 선택 (`trainingBackend='simulink'`)
- 공간 차원: 2차원 x–z 기본, 측방 y축·roll 축 3차원 옵션 선택 (`spatialDimension=3`, MATLAB 백엔드 한정)

## 소스 구조

- `src/orchestration`: 실행 흐름·설정·저장·검증·최소 시각화
- `src/simulations`: 환경·동역학·센서·시나리오·안전 제어
- `src/algorithms`: PPO·그래프 상태·온톨로지·R-GAT
- 세 소스 루트의 `+landing2d` 네임스페이스 공동 사용
- `+landing2d/+simulink`: Simulink 환경 블록·신호 형식(simulations), 모델 생성·등가성 검증(orchestration)
- `+landing2d/+rlsim`: RL Toolbox 정책 망·Simulink PPO 학습(algorithms)
- `+landing2d/+observation`: 최소 공통 관측 `o_t`(12차원)·부가 정보 `Gamma`·UGV 상태추정(평면 PnP·등속 KF)·벡터화(simulations)
- `+landing2d/+probe`: 고정 probe 기준 궤적 구동기·기록·측정 재생(simulations), probe 은행 생성(orchestration)
- Simulink 모델 파일: 생성물, `results/.../models` 저장
- 루트 MATLAB 파일 추가 금지
- 예외: 사용자 진입점 `run.m`, `run_scenario.m`, `run_live.m`

## 유지 계약

- 행동 출력: 수평·수직 가속도 `[a_x,a_z]`, 3차원 옵션 `[a_x,a_y,a_z]` (수직 성분 마지막)
- 3차원 옵션의 수치·task fingerprint·학습 서명 불변: 3차원 항목(`experiment.spatial`, `graphState.spatialDimension`)은 3차원 옵션에서만 생성, 3차원은 공통 관측 제거·하향 원뿔 카메라(`defaultSpatialConfig.cameraFov`, `cameraPitchOffset`)·tracker 기반 감독기 유지
- 평면 계약(리팩토링): 마커 카메라 단일 기하, 광축 기준 시작 위치, 공통 관측 기반 감독기·착륙 승인으로 변경, 변경 전 2차원 체크포인트·결과 재사용 금지
- 3차원 설정의 단일 정의: `landing2d.config.defaultSpatialConfig`, 적용 `landing2d.config.applySpatialDimension`
- 3차원 체크포인트: `results/spatial3d` 분리 저장
- 3차원 계약 보완(3차원 전용, 세 비교군 공통): 최종 하강 단계(`experiment.spatial.finalDescent*`), 행동 변화량 보상 비용(`reward.actionChangeWeight`), 학습 에피소드 한정 커리큘럼(`rl.trackAuthorizationCurriculumScale`, `rl.touchdownAttitudeCurriculumScale`)과 탐색 잡음(`rl.initialLogStd`, `rl.lateralInitialLogStd`)
- 정책 입력(2차원): 12차원 공통 관측(`experiment.observationSchema` = `landing2d.observation.vectorSchema`)과 공통 관측 기반 graph(`landing2d.graphstate.observationGraph`)만 허용, 관측 차원·필드명은 스키마에서 읽기, 26차원 packet으로 되돌리기 금지
- 정책 입력(3차원 옵션): causal sensor packet과 해당 packet 기반 graph
- 2차원 graph: 7개 노드·4개 관계·6채널, 노드별 정보보존 grouped readout. 12차원 공통 관측 외 입력 금지
- 2차원 graph 노드 특징 버전 `graphState.observationFeatures = 'forward_camera_v2'`(그래프 비교군 학습 서명 포함, 3차원 옵션은 필드 제거): 수평 오프셋·상대 수평 속도는 $o_t$와 같은 연성 척도 x/(|x|+3)(전방 하향 카메라의 패드 시야 지점 약 0.58h 앞에서 포화 금지), 영상 경과시간은 Γ 고정 척도(커리큘럼 중단 기준과 무관), 착륙 억제·하강 근거에 감독기 최종 하강 규칙(`experiment.commonObservation.finalDescent`) 반영
- 비가시 시점 hidden pad truth·미래 상태·보상·결과 라벨 입력 금지
- 공통 reward·environment·action·termination 변경 금지 (예외: 2026-10-08 사용자 요청의 평면 reward_v3 개정, 이후 변경도 비교군 공통·`docs/refactor/REWARD_RATIONALE.md` 근거·측정 결과 필수)
- 평면 보상 reward_v4: goal 기준점 $h\tan30^\circ$, 접근 곡면 속도 목표 $v_x^*=\tan30^\circ v_z-0.35(e_x-h\tan30^\circ)$, 수직 목표 $v_z^*=-\min(0.4,0.8h)$, potential 가중치 goal/수평/수직=4/4/4. 3차원 옵션은 reward_v2 유지
- PPO 입력 표준화(평면, 비교군 공통): `rl.inputNormalization`, Actor/Critic MLP 입력의 running 평균·분산 표준화(`landing2d.rl.mlpInput`·`updateInputNorm`, 공유 통계 `agent.inputNorm`), 정책 입력 자체(24차원 $o_t$·그래프 특징) 불변, 수집 정책 입력으로만 갱신, raw 경로 보존 단계(관계 적응) 동결, 관계 residual·하강 gate는 비표준화 입력 사용, Simulink 변환은 고정 `landing2d.rlsim.InputNormLayer`(RL Toolbox 학습 중 통계 갱신 없음), 3차원 옵션 필드 제거
- 커리큘럼 재생 계약(평면, 비교군 공통): `rl.curriculumReplayContract='current'`, 쉬운·중간 재생 에피소드는 시작 고도·UGV 운동만 재생 수준, 접지 속도 한계·실패 보상·장기 손실 시간은 현재 커리큘럼 수준(`trainingEpisodeConfig` 4번째 인자), 3차원 옵션 필드 제거
- 비교군 간 task fingerprint 동일성 유지
- 비교군 설정: `landing2d.config.applyMethod`(method·학습 시드·그래프 시드), 실행 목록 `landing2d.config.comparisonArms`, 학습·평가·실시간 비교 공용
- 체크포인트(2차원): `checkpoints/<method_id>_s<train_seed>[_g<graph_seed>].mat`, 학습 서명에 파일명·`rl.seed`·관계 교란 포함, 실행 식별 `run` 저장 (`landing2d.rl.runIdentity`)
- 관계 교란: `graphState.relationPerturbation`(graph_seed) 고정 순열 `landing2d.rgat.applyRelationPerturbation`, 자기 간선 보호, 원 배치·전역 이름 치환 배치 거부, 사전학습부터 추론까지 `encoderSpec.graph`(src/dst/rel/graph_hash) 단일 사용, 로드 시 `landing2d.rl.verifyCheckpointGraph`
- 관계 교란 절제 실험: 처음부터 교란 그래프로 학습, 추론 시 재순열 금지, 온톨로지-RGAT와 초기화·사전학습·동결·PPO 예산·관계 경로 가드 동일
- 평면 R-GAT은 raw semantic bypass·relation residual 없이 노드별 정보를 보존하는 direct grouped embedding만 사용
- 실시간 역전파 금지
- test seed의 checkpoint 선택 사용 금지
- 결과 생성 없는 수치·그림 작성 금지
- Simulink 환경 블록의 기존 환경 함수 직접 호출 유지, 환경·보상·종료 로직 복제 금지
- Simulink 블록 신호 형식의 `landing2d.simulink.signalCodec` 단일 정의
- Simulink 실행 설정(`c.simulink`)의 학습 서명 제외 유지
- 공통 관측(평면 전용, `docs/COMMON_OBSERVATION_KO.md`): 생성 `landing2d.observation.capture` 단일 경로, 설정 `landing2d.config.defaultCommonObservationConfig` 단일 정의
- 공통 관측 내용: UGV 추정 위치·속도와 영상 보정 여부·경과시간(`G_t`), 융합 측위와 측위 유효·경과시간(`D_t`), 직전 결정 시점 UGV·드론 위치·속도와 기록 유효(`H_t`)만 허용, tracker 추정·결정 문맥 플래그·의미 판단 특징 입력 금지
- UGV 상태추정: 마커 코너 → 평면 PnP → `WT_G = WT_B BT_C CT_P PT_G` → 등속 KF, 미검출 시 예측만, 참값·논문 RMSE 잡음 주입 금지
- `capture` 입력: 검출 결과·융합 측위·기억·`Gamma`만 허용, 참값은 시뮬레이션 센서 모델(`landing2d.sensing.detectMarkers`, `landing2d.sensing.navigationEstimate`) 내부 한정
- 부가 정보 `Gamma`(`landing2d.observation.staticContext`): 카메라 `K`·왜곡계수·`BT_C`, 마커 ID 대응·기하, UGV 장착 관계, 추정기·좌표계·정규화·이력 설정, 관측 벡터 포함 금지, 비교군 동일 제공
- 경과시간: 원본 timestamp에서 결정 시각 기준 계산, 별도 상태 변수 관리 금지
- 공통 관측 잡음(마커 코너·융합 측위·평면 tracker): 시간 기준 잡음표(`landing2d.sensing.exogenousNoise`, `time_indexed_v1`)만 사용, reset에서 전용 난수열로 1회 생성, 결정 시점 `k`·물리 스텝 `j` 색인, 검출 여부·정책·조기 종료에 따른 난수 소비 금지, 기존 sensor 난수열은 외생 사건 표본 전용
- 관측오차 배율: `reset` 옵션 `sensorNoiseScale`(평면 전용, 기본 1), 같은 표준정규 표본 × 배율, 추정기 잡음 가정·검출 조건·dropout 일정 불변, 학습은 배율 1 고정
- 외생 manifest: `landing2d.environment.exogenousManifest`(reset 직후, 초기 상태·UGV 일정·외생 사건·난수열 시드·잡음표 해시), 평가 전용, 정책 입력 금지
- 정책 일관성 설정: 최상위 `c.consistency`(`landing2d.config.defaultConsistencyConfig`), 학습 서명·task fingerprint 제외 유지
- 고정 probe: 비교군과 무관한 인과적 구동기(`landing2d.probe.referenceDriver`)의 실제 환경 궤적 기록(`recordReference`) → 측정 단계부터 배율별 재계산(`replaySensing`) → 은행(`landing2d.probe.buildBank`), 명목 배율 재생 = 환경 관측 비트 일치 필수, 정책 행동의 궤적 되먹임 금지, 정책 입력·문맥·참값 분리 저장, 기준 배율 대비 관측 신뢰도·안전 판단 경계 변경 probe 구분(`sameConfidence`·`sameSafety`·`sameContext`)
- probe 정책 평가: `landing2d.rl.probeActions`(결정론, tanh 이전 평균·감독기 이전 요청 명령), 재귀 정책 거부, test 분할 은행의 임계값·체크포인트·대표 사례 선택 사용 금지
- 독립 유효 판정기: `landing2d.metrics.behaviorValidity`(기존 `stepPlanar`·`evaluateTermination`으로 복사 상태에서 짧은 고정 명령 예측, 감독기 미적용), 허용 집합(`admissibleActions`) = 안전 접촉·제동 여유·시야 유지(영상 최근·최종 하강 고도 위) + 과업 후퇴 규칙(`taskRules`, 최선 + kappa × 도달 범위), 온톨로지 노드·attention·보상·감독기 모드 사용 금지, 정답 명령 하나·고정 방향 강제 금지, 감독기 복구 비행·안전 명령 부재는 적용 제외와 사유
- 판정기 동결: horizon·kappa를 validation 은행만으로 선택(`landing2d.consistency.calibrateValidity`, 적용률·잡음 없는 기준 구동기 유효율 하한 아래 판별력 최대), `results/consistency/validity_frozen.json`, test 은행은 동결값만 사용(`prepareProbes`)
- 일관성 지표(`+landing2d/+consistency`): `C_valid`(문맥별 후 문맥 동일 가중, 최소 표본), `D_obs`(동일 문맥 probe 평균·P95), `D_seed`(시드쌍 평균, 시드 삭제 잭나이프, 관계 교란 절제 실험은 그래프 시드별), `J_policy`(외생 일정 정상 구간 안에서만 차분, 에피소드 통합은 차분 구간 길이 가중), `C_valid` 단독 보고 금지(임무 지표 병기)
- 학습된 실행 평가: 고정 probe `landing2d.consistency.evaluateRuns`, 폐루프 J_policy·종료 결과 `closedLoopJerk`(probe 은행과 같은 분할 시드), 체크포인트 적재 `loadRun`(학습 서명 불일치 시 `missing`)
- 명령 로그: `rolloutEpisodeV2`·`evaluateV2`의 `commandLog` 옵션, 구역 분리(`identity`·`policy`·`decision`·`physics`·`truth`·`exogenous`·`outcome`), 물리 스텝 적용 명령·감독기 사유 코드(`landing2d.control.supervisorReasonCode`)·실제 기체 가속도(참값) 별도 기록, 결정 구간 평균은 `appliedAccelerationIntervalMean`으로만 표기
- 추정 오차 기록: `landing2d.metrics.perceptionError` 평가 전용, 정책 입력 금지
- 관측 벡터 정규화: `x`는 현재 드론 `x` 기준 상대값(`drone_x` = 0), 구조체 `o_t`는 로컬 좌표 보존
- 평면 카메라 단일 정의: `sensor.fov`·`sensor.cameraPitchOffset` = `landing2d.sensing.planarCameraGeometry(마커 카메라 보정)`, tracker·보상 시야 항·시각화 공용
- 시작 위치: `x_D = x_P + h*tan(cameraPitchOffset)` (패드 중심이 수평 자세 광축 위)
- 평면 학습 커리큘럼 시작 고도: 0.45–0.6 m(`rl.initialHeightRange(1)` 0.1125, `rl.curriculumStartHeight` 0.075, 전방 카메라 사각지대 0.35 m 이하 회피), 3차원 옵션은 기존 0.1–0.4 m 유지(`defaultSpatialConfig`)
- 평면 학습 에피소드 난수 흐름 분리: 에피소드별 환경 시드·사례는 `rl.seed + rl.episodeStreamSeedOffset` 전용 흐름(`ppoTrain`), 같은 학습 시드의 비교군은 같은 학습 에피소드 순서, 미니배치 순열은 기존 흐름, 3차원 옵션은 필드 제거
- 평면 성능 커리큘럼(비교군 공통): 현재 단계 착륙률 30% 이상 3개 구간이면 승급(`rl.curriculumLandingThreshold`), 10% 미만 2개 구간 연속이면 한 단계 강등(`rl.curriculumDemotionThreshold`·`curriculumDemotionWindows`, `advanceCurriculumLevel`), 예정 하한(`curriculumFloor`) 유지, 3차원 옵션은 10% 승급·강등 없음 유지(`defaultSpatialConfig`)
- 평면 구동기 인계 커리큘럼(학습 에피소드 전용, 비교군 공통): 확률 max(`rl.descentPrefixProbability`×(1−커리큘럼 수준), `rl.descentPrefixMinProbability` 0.3)로 기준 구동기가 `rl.descentPrefixHandoverRange`(0.1–0.3 m) 또는 무작위 시각 `rl.descentPrefixMaxTimeRange`(2–15 s) 중 먼저 오는 쪽까지 비행 후 정책 인계(`rolloutEpisodeV2`의 `descentPrefix`), 구동기 구간은 학습 전이 제외, 평가·보상·환경·감독기 불변, 3차원 옵션은 필드 제거
- 마커 검출 판정: 잡음이 더해진 관측 코너로 영상 경계·최소 변 길이 판정, PnP 퇴화(야코비안 랭크 부족) 시 자세 기각
- 학습 기록: `info.history`의 누적 `environmentSteps`·`episodes`·`wallSeconds`, `info.snapshots`(학습 진행 정책, `c.consistency.trainingSnapshots`), `info.pretrainingSeconds`·`ppoSeconds`, `info.relationActivation.seconds`
- 학습 실행: `landing2d.orchestration.trainCampaign`(비교군·학습 시드·그래프 시드별 체크포인트, 동시 실행 시 실행별 파일 분리)
- Simulink 평면 인지 경로: `PerceptionUpdateBlock`(결정 구간 끝 검출·측위·`capture`·결정 문맥), 감독기 입력은 `perceptionView` 값, tracker 잡음은 시간 기준 잡음표 색인, 신호 `perception`·status 최종 하강 필드는 `signalCodec` 단일 정의, `verifyEquivalence`에 기준 구동기 재생(착륙 경로) 포함
- 평면 direct-policy: 감독기·착륙 승인·SAFE_ABORT 가드 미적용, 접촉은 footprint·상대속도·자세의 기계적 조건만 판정. 3차원 옵션은 기존 감독기·승인 유지
- `experiment.commonObservation`: task fingerprint·학습 서명 포함 (정책 입력·감독기·승인 구동)
- 추정기 파라미터 조정: 검증 시드 한정, 시험 시드 사용 금지

## 실행 계약

기본 전체 실행:

```matlab
run
```

빠른 통합 검사:

```matlab
run(struct('executionMode','smoke','generatePaper',false, ...
    'figureVisible',false,'saveResults',false,'showLiveDashboard',false))
```

단일 시나리오:

```matlab
run_scenario('S3')
```

실시간 비교군 테스트:

```matlab
run_live('S3')
```

Simulink 학습·평가 (체크포인트 `results/simulink`):

```matlab
run(struct('trainingBackend','simulink'))
run(struct('executionMode','smoke','trainingBackend','simulink','runSelfTest',false, ...
    'generatePaper',false,'figureVisible',false,'saveResults',false,'showLiveDashboard',false))
run_scenario('S3',struct('backend','simulink'))
```

3차원 옵션 (체크포인트 `results/spatial3d`):

```matlab
run(struct('spatialDimension',3))
run(struct('executionMode','smoke','spatialDimension',3,'runSelfTest',false, ...
    'generatePaper',false,'figureVisible',false,'saveResults',false,'showLiveDashboard',false))
run_scenario('S3',struct('spatialDimension',3))
run_live('S3',struct('spatialDimension',3))
```

## 검증 계약

- `landing2d.orchestration.selfTest`: 최종 계약 13개 검사 (`contract`, `causal-boundary`, `scenario-dynamics`, `termination`, `context-graph`, `ppo-smoke`, `relation-guard`, `paper-scenarios`, `spatial-3d`, `common-observation`, `relation-shuffle`, `probe-replay`, `behavior-validity`)
- 3차원 구조 변경 후 3차원 smoke pipeline 실행, 2차원 기본 경로의 수치 불변 확인
- `run.m`: self-test 후 학습·validation·held-out test·시각화 순서
- 구조 변경 후 smoke pipeline과 S1~S3 중 1개 이상 실행
- Simulink 구조 변경 후 `landing2d.simulink.verifyEquivalence` 실행: 재생 보상·관측 차이 0, 폐루프 종료 사유 동일
- 실제 MATLAB 미실행 시 통과 주장 금지
