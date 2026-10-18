# 코드 유지 가이드 (`relational_policy_v1`, 2026-10-17 재설계)

## 적용 범위

- 실험: `planar_visibility_v2` 계약 위의 `relational_policy_v1` 설계 (`docs/EXPERIMENT_DESIGN_KO.md`)
- 진입점: `run.m`(학습·평가·그림), `run_check.m`(self-test·smoke·learnability 사전 점검), `run_scenario.m`(통제 사례 하나). 루트에 다른 MATLAB 파일 추가 금지
- 비교군 3개 고정, 단일 정의 `landing2d.config.methodRegistry`
  - `ppo`
  - `onto_rgat_ppo`
  - `shuffled_rgat_ppo`: 관계 유형 고정 순열, self 보존, 그래프 시드 = 학습 시드
- 비교군을 추가하려면 registry 등록과 문서 근거가 필요하다. Semantic-Flat·R-GCN·PPO-LSTM은 미포함이며, 이들과의 비교는 주장하지 않는다
- 공통 계약: 동일 환경·센서·보상·행동·종료·PPO 손실·예산·검증 일정·파라미터 수(6,101). 핵심 차이는 Actor/Critic 상태 표현뿐
- direct-policy: 안전 감독기·착륙 승인·SAFE_ABORT 가드 없음. 접촉은 기계적 조건만 판정
- 공간 차원 2차원 x–z 전용, 학습 백엔드 MATLAB PPO

## 소스 구조

- `src/orchestration/+landing2d`
  - `+config`: 실험·PPO·평가 설정, 비교군, 검증
  - `+orchestration`: 파이프라인, 학습/로드, self-test
  - `+evaluation`: 평가 5종, 지표, 시드 통계
  - `+viz`: 그림
  - `+util`
- `src/simulations/+landing2d`: 환경·동역학·센서·공통 관측(`+observation`)·시나리오·기준 구동기와 측정 재생(`+probe`)
- `src/algorithms/+landing2d`: PPO(`+rl`), TOSM 그래프·부호기(`+graphstate`), R-GAT(`+rgat`)

## 유지 계약

- 행동 출력: `[a_x,a_z]`. 정책 입력은 12차원 공통 관측(`experiment.observationSchema`)과 그것의 `tosm7_v1` 그래프만 허용
- 비가시 시점 hidden truth·미래 상태·보상·결과 라벨 입력 금지
- 공통 관측: `landing2d.observation.capture` 단일 경로, 설정 `defaultCommonObservationConfig`, 잡음은 시간 기준 잡음표(`time_indexed_v1`)
- 공통 reward·environment·action·termination 변경 금지
  - 변경이 필요하면 비교군 공통이어야 하고, `docs/REWARD_KO.md` 근거와 측정 결과가 필요하다
  - 현재 reward_v5
- PPO 손실은 세 비교군이 완전히 같다. 특정 비교군에만 주는 손실 항·잔차 헤드·입력 표준화·우회 경로 금지
  - 2026-10-17 R-GAT 전용 명령 평활화 항 삭제
- R-GAT
  - 단일 층, 입력 의존 attention(`input_dependent_v1`), 노드별 국소 경로, `grouped_factorized` readout, graph embedding 16
  - Actor 35-38, Critic 35-30
  - `fixed_relation_v1`은 같은 파라미터의 선택지로만 유지
- 그래프(`docs/TOSM7_ONTOLOGY_KO.md`)
  - 7노드·4관계+self·20간선·6채널
  - 모든 특징은 $o_t$와 공개 보정 상수의 결정론적 함수
  - Implicit 노드는 guard가 아님
- 학습 분포(`defaultPlanarVisibilityConfig`)
  - UGV CV/CA 요인과 마커 정상/누락 요인을 독립 표본(각 셀 약 25%)
  - $T_1$ 무작위
  - 누락 시작은 $T_1$과 독립
  - 초기 상대속도·위치 편차(FOV 확인)
  - 학습에서 누락과 가속을 일부러 겹치지 않는다
- 시드 계약
  - 환경 시드 < 1e6
  - split 서로소: validation 2001–2200, test 3001–3200, stress 9001–9200, 고정 사례 41001–49999, PPO 학습 에피소드 100001–999999 (`validatePrimaryConfig`가 검사)
  - 학습 시드 s → `rl.seed = base + s − 1`. 기본 1–5, 확장 1–10
- 체크포인트 선택은 validation만 사용
  - test·stress·고정 사례·probe 결과로 체크포인트·임계값·사례를 고르는 것은 금지
- 통제 사례 S1–S4(`landing2d.evaluation.factorialCases`)
  - 반복마다 같은 시드·deadline·평가 구간
  - 모든 값이 학습 범위 안
  - 사례 시간 배치를 정책 결과에 맞춰 조정하는 것은 금지
- 학습 범위 밖 조건(`defaultEvaluationConfig.generalization`)은 학습 범위를 실제로 벗어나야 한다(검증됨)
- 평가 지표
  - 평가 전용 참값으로만 계산(`landing2d.evaluation.episodeMetrics`). 온톨로지 노드·attention·보상 미사용
  - 추종 오차는 카메라 광축 기준 aim error
  - 외부 주입 누락과 정책 유발 시야 이탈을 분리 기록
- open-loop probe
  - 정책과 무관한 기준 구동기 궤적 사용
  - 명목 재생 = 환경 관측(비트 일치)
  - 정책 행동을 궤적에 되먹이지 않음
  - attention 변화는 기술 지표이며 인과적 중요도로 해석 금지
- 통계
  - 분석 단위 = 학습 시드. 비교군 차이는 학습 시드별 짝 차이
  - 학습 시드 하나로는 방법 간 차이를 주장하지 않는다
  - 명령 변화 감소는 같은 쌍의 추종 오차와 함께만 해석
- 결과 생성 없는 수치·그림 작성 금지
- 체크포인트: `results/checkpoints/<method>_sNN[_gNN].mat`
  - 학습 서명(알고리즘 버전·rl·experiment·graphState) 불일치 시 재학습
  - 평가 설정(`c.evaluation`)은 서명 밖

## 실행 계약

```matlab
run_check                    % self-test + smoke
run_check('learnability')    % 새 환경에서 과제 학습 가능성 사전 점검
run                          % 3 비교군 × 학습 시드 1–5
run_scenario('S4')
```

## 검증 계약

- `landing2d.orchestration.selfTest`: 14개 검사
  - contract, seeds, scenario-family, factorial-cases, causal-boundary, scenario-dynamics, termination
  - context-graph, ppo-smoke, relation-attention, common-observation, relation-shuffle, probe-replay, evaluation
- 구조 변경 후에는 `run_check`(self-test + smoke) 실행
- 실제 MATLAB을 실행하지 않았으면 통과를 주장하지 않는다
