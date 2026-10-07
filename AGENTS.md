# 최종 코드 유지 가이드

## 적용 범위

- 기본 실험: `planar_visibility_v2`
- 단일 진입점: `run.m`
- 단일 시나리오 진입점: `run_scenario.m`
- 실시간 비교 진입점: `run_live.m`
- 비교군: baseline, semantic-flat, ontology R-GAT PPO
- 공통 계약: 동일 환경·센서·보상·행동·종료·안전 감독기
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
- Simulink 모델 파일: 생성물, `results/.../models` 저장
- 루트 MATLAB 파일 추가 금지
- 예외: 사용자 진입점 `run.m`, `run_scenario.m`, `run_live.m`

## 유지 계약

- 행동 출력: 수평·수직 가속도 `[a_x,a_z]`, 3차원 옵션 `[a_x,a_y,a_z]` (수직 성분 마지막)
- 2차원 기본 계약의 수치·task fingerprint·학습 서명 불변: 3차원 항목(`experiment.spatial`, `graphState.spatialDimension`)은 3차원 옵션에서만 생성
- 3차원 설정의 단일 정의: `landing2d.config.defaultSpatialConfig`, 적용 `landing2d.config.applySpatialDimension`
- 3차원 체크포인트: `results/spatial3d` 분리 저장
- 3차원 계약 보완(3차원 전용, 세 비교군 공통): 최종 하강 단계(`experiment.spatial.finalDescent*`), 행동 변화량 보상 비용(`reward.actionChangeWeight`), 학습 에피소드 한정 커리큘럼(`rl.trackAuthorizationCurriculumScale`, `rl.touchdownAttitudeCurriculumScale`)과 탐색 잡음(`rl.initialLogStd`, `rl.lateralInitialLogStd`)
- 정책 입력: causal sensor packet과 해당 packet 기반 graph만 허용
- 비가시 시점 hidden pad truth·미래 상태·보상·결과 라벨 입력 금지
- 공통 reward·environment·action·termination 변경 금지
- baseline·semantic-flat·R-GAT의 task fingerprint 동일성 유지
- R-GAT의 raw semantic bypass와 relation residual 분리 유지
- 실시간 역전파 금지
- test seed의 checkpoint 선택 사용 금지
- 결과 생성 없는 수치·그림 작성 금지
- Simulink 환경 블록의 기존 환경 함수 직접 호출 유지, 환경·보상·종료 로직 복제 금지
- Simulink 블록 신호 형식의 `landing2d.simulink.signalCodec` 단일 정의
- Simulink 실행 설정(`c.simulink`)의 학습 서명 제외 유지

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

실시간 세 비교군 테스트:

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

- `landing2d.orchestration.selfTest`: 최종 계약 9개 검사 (`contract`, `causal-boundary`, `scenario-dynamics`, `termination`, `context-graph`, `ppo-smoke`, `relation-guard`, `paper-scenarios`, `spatial-3d`)
- 3차원 구조 변경 후 3차원 smoke pipeline 실행, 2차원 기본 경로의 수치 불변 확인
- `run.m`: self-test 후 학습·validation·held-out test·시각화 순서
- 구조 변경 후 smoke pipeline과 S1~S3 중 1개 이상 실행
- Simulink 구조 변경 후 `landing2d.simulink.verifyEquivalence` 실행: 재생 보상·관측 차이 0, 폐루프 종료 사유 동일
- 실제 MATLAB 미실행 시 통과 주장 금지
