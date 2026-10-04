# 최종 코드 유지 가이드

## 적용 범위

- 기본 실험: `planar_visibility_v2`
- 단일 진입점: `run.m`
- 단일 시나리오 진입점: `run_scenario.m`
- 비교군: baseline, semantic-flat, ontology R-GAT PPO
- 공통 계약: 동일 환경·센서·보상·행동·종료·안전 감독기
- 핵심 차이: Actor/Critic 상태 표현

## 소스 구조

- `src/orchestration`: 실행 흐름·설정·저장·검증·최소 시각화
- `src/simulations`: 환경·동역학·센서·시나리오·안전 제어
- `src/algorithms`: PPO·그래프 상태·온톨로지·R-GAT
- 세 소스 루트의 `+landing2d` 네임스페이스 공동 사용
- 루트 MATLAB 파일 추가 금지
- 예외: 사용자 진입점 `run.m`, `run_scenario.m`

## 유지 계약

- 행동 출력: 수평·수직 가속도 `[a_x,a_z]`
- 정책 입력: causal sensor packet과 해당 packet 기반 graph만 허용
- 비가시 시점 hidden pad truth·미래 상태·보상·결과 라벨 입력 금지
- 공통 reward·environment·action·termination 변경 금지
- baseline·semantic-flat·R-GAT의 task fingerprint 동일성 유지
- R-GAT의 raw semantic bypass와 relation residual 분리 유지
- 실시간 역전파 금지
- test seed의 checkpoint 선택 사용 금지
- 결과 생성 없는 수치·그림 작성 금지

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

## 검증 계약

- `landing2d.orchestration.selfTest`: 최종 계약 8개 검사
- `run.m`: self-test 후 학습·validation·held-out test·시각화 순서
- 구조 변경 후 smoke pipeline과 S1~S3 중 1개 이상 실행
- 실제 MATLAB 미실행 시 통과 주장 금지
