# T00 감사: 현행 코드·최종 설정·비교군·그래프 경로·로그

## 요약

- 대상: `ugv_landing_2d_workspace_refactor` (`refactor` 브랜치, 기준 커밋 `6e97bb8` + 미커밋 변경), 2026-10-07 작업 트리
- 결론: PPO 정책 일관성 검증에 필요한 비교군 registry·고정 관계 교란·고정 probe·요청/적용 명령 로그·다중 학습 시드·method_id 체크포인트가 모두 부재
- 차단 사항: 리팩토링 워크스페이스의 2차원 체크포인트는 전부 서명 불일치, 평가 전용 실행 불가 (학습 필요)
- 결정 필요: 정책 관측을 현행 `observationSchema`(26차원 `causal_packet_v2`)로 유지할지 여부
- 성능 수치: 이 문서는 감사 전용, 성능·우월성 수치 없음

## 1. 작업 트리·계약 상태

- 미커밋 변경: 수정 23개 파일, 신규 파일·폴더 11개 (공통 관측·마커 카메라·인지 기반 감독기)
- 평면 계약 변경 내용: 마커 카메라 단일 기하(세로 FOV 63.95°, 광축 -30°), 광축 기준 시작 위치, 공통 관측 UGV 추정 기반 감독기·착륙 승인·최종 하강 단계
- 3차원 옵션: 변경 전과 비트 동일 (공통 관측 제거, 하향 원뿔 카메라)
- Simulink 백엔드: 환경 블록이 tracker 기반 감독기 유지, `verifyEquivalence` 재생 비교 실패 (baseline, seed 2001: 종료 사유 UNSAFE_CONTACT vs SAFETY_ENVELOPE_VIOLATION, 보상 차이 43.0)

## 2. 최종 적용 설정 (MATLAB `primaryConfig` 해석값)

| 항목 | 값 |
|---|---|
| 정책 관측 | `causal_packet_v2`, 26차원 (own_motion·pad_track·visibility·task_memory) |
| 공통 관측 | `common_observation_v2`, 24차원, 정책 입력 아님, 감독기·승인 구동 |
| 주기 | 물리 0.01 s, 결정 0.1 s, 최대 임무 70 s |
| 시드 분할 | train 1–2000, validation 2001–2200, test 3001–3200, stress 9001–9200, 평가 각 100개 |
| PPO | 2500 반복 × 6 에피소드, epoch 8, minibatch 256, γ 0.99857, 평가 주기 25, `rl.seed` 20240501 (전 비교군 공통) |
| 커리큘럼 | performance 방식, 초기 고도 0.025–1.0 m, 시작 0.05 m, `initialLogStd` -1.1 |
| 그래프 (context_rgat) | readout `raw_plus_groups`, hiddenDim 8, 상태 108 + 문맥 4, 사전학습 12 에피소드 |
| 파라미터 수 (smoke `profileAgent`) | baseline 7445, context_flat 15317, context_rgat 17001 (동결 backbone·R-GAT 인코더 중복 포함 계수) |
| task fingerprint | 세 비교군 동일 `6a9b4457` |
| 체크포인트 | 세 비교군 모두 `CheckpointMismatch` (변경 전 계약 학습본) |

- 원본 워크스페이스(`ugv_landing_2d_workspace`): 세 비교군 체크포인트 호환, 비교군별 학습 시드 1개, 교란 비교군 없음, 공통 관측·마커 카메라 없음

## 3. 비교군·체크포인트

- 현행 공식 비교군: `{'baseline','context_flat','context_rgat'}` 하드코딩
  - `trainEvaluate.m:83`, `validateStudy.m:19`, `runLive.m:28`, `selfTest.m:34,153`, `simulink/runScenario.m:22`, `simulink/verifyEquivalence.m:19`
- 표시 이름 정의 3곳: `trainEvaluate.m:176-185`, `validateStudy.m:20`, `runLive.m:29`
- 3개 비교군 고정 가정: `replayPlanarVisibilityComparison.m:12`, `plotStudy.m:9`, `normalizeRuns.m:5-11`
- 체크포인트 이름: `ppo_<stateRepresentation>_planar_visibility_v2.mat`, method_id·학습 시드·그래프 시드 없음
  - 교란 RGAT는 같은 stateRepresentation이라 `context_rgat` 파일과 충돌
- 학습 서명: `c.rl` 전체 포함 (`rl.policyFile`, `rl.seed` 포함) → 파일명·시드 변경 시 서명 변경
- 다중 학습 시드: `trainEvaluate`의 `rlSeed` 옵션 1개 시드/호출, 같은 파일 덮어쓰기, 시드 간 집계 없음

## 4. 그래프 경로 (context_rgat)

### 4.1 구조

- 노드 9: PadVisibility, PadMotion, DroneTranslation, DroneAttitude, RelativeTracking, TrackingCorrection, ViewRecovery, DescentEligibility, LandingInhibit
- 관계 5: informs(1), affects_visibility(2), supports(3), inhibits(4), self(5)
- 간선 26: 의미 17 (informs 13, affects_visibility 2, supports 1, inhibits 1) + 자기 9
- 입력 간선이 자기 간선뿐인 노드: PadMotion, DroneTranslation, DroneAttitude (attention 항상 1)
- 노드 특징: `contextGraph(packet)` (26차원 packet 기반), 간선 배치와 무관

### 4.2 연산

- 관계별 파라미터: `W1(:,:,r)`, `a1(:,:,r)`, `E1(:,r)`, 목적지별 전체 입력 간선 공동 softmax (`relationForward.m:24-46`)
- 관계 이름별 특수 처리 없음 (inhibits 부호·supports 처리 없음), self도 일반 관계 + 관계 무관 지역 경로 `W0`
- 위상 저장: `encoderInit.m:24-28`에서 1회 계산, `agent.encoderSpec.schema`·`agent.encoderSpec.T`에 저장, 순전파·역전파·사전학습·병렬 worker·RL Toolbox 층 모두 이 값 사용
- 모드 문자열로 정준 스키마를 재구성하는 곳: `contextGraph.m:5-7`(차원만), `evaluateV2.m:20-24`(진단), 시각화 (`ontologyRgatExplorer.m`, `liveDashboard.m`, `plotRgatField.m`)
- 그래프 해시: 없음

### 4.3 학습 절차상 관계 경로의 크기

- readout 가중치 `Wg`·`bg` 0 초기화 → 초기 R-GAT 출력 = semantic-flat 출력
- 그래프 적응: PPO 반복의 90% 이후만 (`graphAdaptationWarmupFraction` 0.90, 2251–2500 반복)
- `E1`, `W0`, `b0` 상시 동결, raw MLP·`logStd`는 적응 구간 고정
- 관계 체크포인트 선택 여유 `graphSelectionMargin` 5 (baseline·flat에는 없음)
- 활성 판정 (`relationalPathActive.m`): policy·value의 `Wg`와 관계 head 노름 4개 모두 1e-10 초과
- 경로 복구 (`ensureRelationalPath.m`): 비활성 시 관계 전용 PPO 25 반복 + guard
- guard (`guardRelationalCandidate.m`): 배율 격자에서 검증 성능 비저하·잔차 노름 [1e-6, 0.005] 조건
- 변경 전 체크포인트 감사 (`results/paper/paper_architecture_audit.csv`): `Wg` 노름 policy 1.7e-4, value 6.1e-4

### 4.4 고정 관계 교란 구현 가능성

- 삽입 위치: `encoderInit` 직후 `schema.rel` 순열 → `topology` 재계산 → `encoderSpec`에 저장, 이후 전 연산 경로 자동 반영
- 순열 대상: 의미 간선 17개의 관계 type_id, 자기 간선 9개 보호
- 서로 다른 배치 수: 17!/(13!·2!·1!·1!) = 28,560
- 관계 이름 전역 치환으로 같은 배치: supports↔inhibits 교환만 가능 (개수가 같은 관계 쌍 유일) → 원 배치와 그 교환 배치 2개 거부
- 파라미터 형상: 간선 배치와 무관, 같은 시드면 초기 가중치 비트 동일
- 해석 제약: 관계 경로 기여가 작고 guard가 잔차 상한을 두므로 제안군 대 교란군 차이가 작게 나타날 가능성, 교란군의 관계 경로 비활성(semantic-flat과 동일) 가능성 → 비교군별 활성 진단 보고 필요

## 5. 학습 절차·공정성

- 공통: 환경·보상·행동·종료·감독기, `rl.seed`, PPO 예산, 평가 시드
- R-GAT 전용 추가 계산: 사전학습(12 에피소드 × 최대 80 결정, 8 epoch), 경로 복구(25 반복 × 6 에피소드), guard 검증(최대 11 배율 × 검증 100 에피소드), 선택 여유
- 학습 에피소드 시드: PPO 난수열의 int32 추출, manifest train 분할 미사용, 검증·시험 시드와의 중복 검사 없음
- PPO 난수열 소비: `randperm(rs,n)`의 `n`이 비교군마다 달라 2번째 반복부터 학습 에피소드 시드 상이
- 비용 기록: `info.trainingSeconds` 1개 값 (사전학습 분리 없음), 경로 복구 시간 미기록, CSV 미출력
- Simulink 학습: RL Toolbox 탐색 난수 미고정

## 6. 평가·난수열

| 난수열 | 시드 | 소비 방식 |
|---|---|---|
| 시나리오 | base + 0 | reset 시 사전 추출 |
| 센서(tracker) | base + 1e6 | 외생 사건 사전 추출 후, 물리 스텝마다 **검출 시에만** 측정 잡음 |
| 마커 | base + 3e6 | 결정마다, **검출된 마커만** 코너 잡음 |
| 측위 | base + 4e6 | 결정마다 3개, 가시성 무관 |
| 정책 | base + 2e6 | 결정론 평가 미사용 |

- base: `20261002 + seed`
- 외생 사건(dropout·pitch 외란): reset 시 사전 추출, 비교군 공유
- 잡음 정렬: 측위만 결정 인덱스 정렬, tracker·마커 잡음은 가시성 이력에 따라 실현값 상이 → 폐루프 쌍 비교·고정 probe에 시각 기준 잡음 필요
- `resetInfo.provenance`: 시나리오·센서·정책 시드만 기록, 마커·측위 시드 미기록
- 체크포인트 선택: 검증 2001–2100만 사용, 시험 분할은 학습 후 1회 평가 (확인)
- 대표 시나리오 S1–S3: 수작업 고정 파라미터, 시드 41001–41003 (전 분할 밖), 시험 시드 미사용
  - S3 dropout 0.8 s (4.2–5.0 s)는 `short`로 표기되나 선언된 short 범위 0.2–0.5 s 밖

## 7. 로그

| 항목 | 현황 |
|---|---|
| tanh 이전 actor 평균 | 단일 필드 없음, `baseMean + relationResidual`로 재구성 가능, 결정론 평가에서 `command`와 동일 |
| tanh 이전 명령 | `traj.command` |
| tanh 행동 | `traj.normalizedAction` |
| 감독기 이전 요청 명령 | `traj.requestedAcceleration` (축별 배율 적용) |
| 감독기 적용 명령 | `traj.appliedAcceleration` = 결정 구간 내 물리 스텝 적용 명령의 **시간 평균**, 물리 스텝별 값 미기록 |
| 감독기 개입 | `traj.safetyIntervened`, 사유 `supervisorReasons`는 미저장 |
| 시각 | `result.time`, `traj.dt` (traj 자체 시각 필드 없음) |
| 가시성 | `result.visible` = tracker 검출, 인지 기반 감독기의 영상 보정 여부 미기록 |
| 참값·관측 분리 | 참값 `result.*`, 정책 입력 `traj.observation/state`, packet·공통 관측·추정 오차 미저장 |
| 실행 식별자 | method_id·train_seed·graph_seed·graph_hash·checkpoint_hash 없음 |

- `evaluateV2`: 에피소드별 `traj` 폐기 → 검증·시험 100 에피소드의 명령 로그 없음
- `runLive`·Simulink 로그: 명령 미기록, `runLive`의 감독기 플래그는 첫 개입 이후 계속 참

## 8. 지표

- 구현됨 (`trajectoryMetrics.m`): 종료 사유, 성공, 수익, 착륙 시각, 추종 RMSE, 상대속도 RMSE, pitch RMS, 측정·기하 FOV 소실률, 감독기 개입률, 착륙 금지율, 위험 하강 노출, 적용 명령 저크 RMS, 재포착 지연, 안정성 지수, 금지 원인 분해, 관계 잔차
- 저크: 구간 평균 적용 명령 기준, 요청 명령 저크·정상 구간 한정 없음
- 재포착 지연: dropout 종료 후 첫 `visible`, 실패·소실 없음 구분 없음
- 미구현: 대응 지연, 기한 내 적절 대응률, 실패 반영 지연, 명령 포화율, 유효 판정(behaviorValidity), C_valid·D_obs·D_seed·J_policy
- `recoveryMetrics.m`: 구버전 결과 필드 사용, 현행 파이프라인 미사용

## 9. 시각화·산출물

- 창 구성: 학습 대시보드 1, 비교 재생 1, 논문 그림 최대 4, 온톨로지 탐색기 1, 실시간 비교 1 → 전체 파이프라인 6창
- 명령 시계열 그림: 없음
- 라벨: 대부분 영문 (대시보드·`runLive` 일부 한글)
- 지양 대상 존재: attention heatmap(`imagesc`), 3차원 surface(`plotRgatField`), 3차원 궤적 탭
- 저장 결과만 읽는 함수: `plotStudy`, `replayPlanarVisibilityComparison` (`trainEvaluate`는 학습 후 그림 생성)
- 저장 형식: PNG 300 dpi(논문)·200 dpi(탭), `.fig` (비교 재생), CSV 요약, MAT
- JSON 출력: 없음, manifest·resolved config 미저장
- 해시: `util/checksum.m` 32-bit djb2 (비암호, 대용량 체크포인트 해시 부적합)
- `results/` 기존 산출물: 변경 전 계약 기준 (`planar_visibility_full*.csv`의 표시 이름도 구 명칭), `training_history_summary.csv`·`pipeline_output_summary.mat`는 현행 코드에 생성 함수 없음
- `results/spatial3d/planar_visibility_full_summary.csv`: 세 비교군 착륙률 0%, context_flat과 context_rgat의 비율·평균 수익 동일 (−9.117)

## 10. 관측오차 배율 적용 대상 (T02 준비)

| 오차원 | 현재 값 | 시간 상관 | 정책 관측 경로 |
|---|---|---|---|
| tracker 상대 위치 | 0.02 m | 백색 | packet (정책 입력) |
| tracker bearing | 0.15° | 백색 | packet (정책 입력) |
| 마커 코너 | 0.5 px | 백색 | 공통 관측 → 감독기·승인, packet의 금지·중단 플래그 |
| 측위 속도·자세 | 0.05 m/s, 0.5° | 백색 | 공통 관측 → 감독기·승인 |
| dropout·pitch 외란 | 확률·구간 분포 | 사건 단위 | 양쪽 |

- 혼합 구조: 정책 입력 packet의 추적 항목은 tracker, 착륙 금지·중단 플래그는 공통 관측 인지에서 유래

## 11. 결정 필요 사항

1. 정책 관측: 현행 `observationSchema`(26차원 packet)로 진행 (권장, 기존 노드 특징·readout 유지 조건과 부합) 또는 24차원 공통 관측으로 전환 (그래프 노드 특징 재설계 필요, 금지 조건과 충돌)
2. 대상 워크스페이스: 리팩토링(학습 필요) 또는 원본(호환 체크포인트 1시드, 교란군 없음)
3. 학습: 다중 시드 결과는 전체 학습 명시 요청 필요 (본 검증 10시드 × 일반·제안 + 교란 3그래프 × 시드)
4. S3 dropout 길이: 현행 유지(범위 밖 표기 보고) 또는 선언 범위 안으로 수정

## 12. T01 작업 범위 (제안)

- method registry: `ppo`·`onto_rgat_ppo`·`shuffled_rgat_ppo`, method_id와 stateRepresentation 분리, 표시 순서·선 스타일 단일 정의
- 관계 교란: `graphState`에 교란 설정·graph_seed 추가, `encoderInit` 직후 고정 순열, 거부 규칙(원 배치·supports↔inhibits 교환), `encoderSpec`에 src/dst/type_id·graph_hash 저장
- 체크포인트: `ppo_<method_id>_s<train_seed>[_g<graph_seed>]` 형식, 학습 서명에 method_id·graph_seed 포함
- 진단 경로: 정준 스키마 재구성 대신 `agent.encoderSpec` 위상 사용
- 범위 밖 유지: 보상·PPO loss·동역학·노드 특징·readout·감독기·행동 한계
