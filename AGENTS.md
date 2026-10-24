# 코드 유지 가이드 (`relational_policy_v1`, 2026-10-17 재설계)

> **진행 중 작업 (2026-10-24, v2.15, 본학습 전):** v2.14는 G2·G3·G5를 통과했으나 G4(잡음)에서 실패했다. validation 진단에 근거해 `tosm7_v5`는 LandingCondition f3의 수직속도 사본만 0으로 두고 DroneMotion의 수직속도는 유지한다. 나머지 특징·인코더·PPO는 동일하다. 설계·결과·논문 정합성은 `docs/RGAT_V2_DESIGN_KO.md` §22.5–23. 학습은 사용자가 `run.m`으로 실행한다. 개발 1–5(PPO 재사용), 확인 241–250(게이트 통과 시만). v2.14 원본 101개 파일은 `results/archive/v2.14_s01-05_2026-10-24/`에 바이트 동일하게 보관했다.

> **진행 중 작업 (2026-10-23, v2.14):** v2.13(잠재 종착 노드)은 두 그래프 비교군 모두 학습이 무너져 개발 게이트 G2에서 실패했다(§21.5). 사용자 선택(A)으로 v2.14(`tosm7_v4`)는 종착 노드 특징을 같은 다섯 양의 부호 있는 o_t 값으로 바꾼다(§22). PPO는 계속 고정한다.
>
> **v2.13 (2026-10-23):** 사용자 결정으로 구조 탐색을 다시 열었다. `run_live`(S4)에서 본 TOSM의 이탈·a_z 떨림의 원인을 validation probe로 찾았다. v2.12 종착 노드 LandingCondition의 부호 없는 고이득 접지 한계비가 의미 간선을 우회했고, 두 R-GAT 비교군의 속도 반응이 천막 모양이었다(§21.1). v2.13(`tosm7_v3`)은 이 노드를 잠재 노드로 바꾸고 두 그래프 비교군만 다시 학습한다. PPO는 고정한다(시드 1–5 체크포인트 재사용, `landing2d.rl.baselineVersion`). 개발 게이트는 §21.4이고, v2.12 시드 1–5 결과는 `results/archive/v2.12_s01-05_2026-10-22/`에 있다.
>
> **이전 작업 (2026-10-22):** v2.4 확인과 v2.5–v2.10 개발 게이트는 관계 의미 효과를 입증하지 못했다(설계 문서 §11.4–§17.3). v2.11 고정 노드 역할 코드북 readout(§18)은 개발 게이트를 통과했지만(§18.3), 확인 실험(시드 191–200, §18.5)에서 목적 판정 0/5로 관계 의미 효과를 입증하지 못했다. v2.12 온톨로지 종착 노드 readout(§19)은 개발 게이트에서 실패했다(AUC 평균 −0.031, 양 2/4, §19.4). 사용자 결정으로 구조 탐색을 멈추고 확인 실험 세 개(v2.3·v2.4·v2.11)를 §20에 종합했다(그림 `landing2d.viz.plotConfirmatorySummary`).
>
> **작업 폴더 정리 (2026-10-22, 사용자 결정):** 작업 폴더는 이 폴더(`codes/ugv_landing_2d_workspace`, 브랜치 `main`) 하나다. `_refactor`·`_d4` 작업 폴더와 그 밖의 옛 결과는 삭제했다. 남은 결과(`results/`, gitignore)는 다음이 전부다.
> - v2.11 확인 실험(시드 191–200)의 체크포인트 30개, 평가 전체, 그림
> - §20 종합 그림·표와 그 근거 CSV(`v23_/v24_/v211_primary_endpoints.csv`)
> - 개발 게이트 판정 CSV(v2.5–v2.12)
> - v2.11·v2.12 등록 스크립트와 로그
>
> 설계 문서 §1–§19가 가리키는 `results/archive/…`, `_d4/…`, `_refactor/…`, 이전 버전의 스크립트·체크포인트는 더 이상 없다. 수치는 문서에 기록된 값이 전부이고, 코드는 git 이력에 있다. `results/v211_scripts`·`v212_scripts`의 등록 스크립트는 SHA-256을 지키려고 옛 `_d4` 경로를 고치지 않았으므로, 다시 실행하려면 `root`를 이 폴더로 바꾼다. 현재 코드의 기본값은 v2.12라서, v2.11 체크포인트는 학습 서명이 맞지 않아 그대로 로드되지 않는다. 재사용하려면 커밋 `387e935`(v2.11)를 체크아웃해야 한다.

## 적용 범위

- 실험: `planar_visibility_v2` 계약 위의 `relational_policy_v1` 설계 (`docs/EXPERIMENT_DESIGN_KO.md`)
- 진입점: `run.m`(스크립트, 학습·평가·그림; 맨 위 실행 설정 `runSettings`는 학습 시드와 비교군별 학습 여부 `train.<비교군>`이다. `false`면 학습하지 않고 가장 최근 검증 모델을 `landing2d.rl.loadLatestCheckpoint`로 불러온다. 학습은 사용자가 `run.m`으로 직접 실행한다), `run_check.m`(self-test·smoke·learnability 사전 점검·결정 추적 시험), `run_scenario.m`(통제 사례 하나, 결정 추적 대시보드·재생), `run_live.m`(통제 사례 하나에서 잡음 반복의 라이브 겹침, 2026-10-22 사용자 요청). 루트에 다른 MATLAB 파일 추가 금지
- 비교군 3개 고정, 단일 정의 `landing2d.config.methodRegistry`
  - `ppo`
  - `onto_rgat_ppo`
  - `shuffled_rgat_ppo`: 관계 유형 고정 순열, self 보존, 그래프 시드 = 학습 시드, 의미 간선 13개 중 10개 이상 유형 변경(`registry.relationShuffle.minChangedFraction = 0.7`). registry v6부터 연산군 규칙은 없다(`rgat_v2`에는 연산군이 없음)
- 비교군을 추가하려면 registry 등록과 문서 근거가 필요하다. Semantic-Flat·R-GCN·PPO-LSTM은 미포함이며, 이들과의 비교는 주장하지 않는다
- 공통 계약: 동일 환경·센서·보상·행동·종료·PPO 손실·예산·검증 일정·조기 종료 규칙·파라미터 수(6,101). 핵심 차이는 Actor/Critic 상태 표현뿐
- direct-policy: 안전 감독기·착륙 승인·SAFE_ABORT 가드 없음. 접촉은 기계적 조건만 판정
- 공간 차원 2차원 x–z 전용, 학습 백엔드 MATLAB PPO

## 소스 구조

- `src/orchestration/+landing2d`
  - `+config`: 실험·PPO·평가 설정, 비교군, 검증
  - `+orchestration`: 파이프라인, 학습/로드, self-test
  - `+evaluation`: 평가 6종(학습 효율·학습 진단·held-out·S1–S4·일반화·probe), 지표, 실패 분류, 시드 통계
  - `+viz`: 그림, 결정 추적 대시보드(`TosmTraceDashboard`)
  - `+trace`: 결정 추적(기록·센서 경로 재실행·출처·설명·내보내기·시험 A01–A13, `docs/TRACE_DASHBOARD_KO.md`)
  - `+util`
- `src/simulations/+landing2d`: 환경·동역학·센서·공통 관측(`+observation`)·시나리오·기준 구동기와 측정 재생(`+probe`)
- `src/algorithms/+landing2d`: PPO(`+rl`), TOSM 그래프·부호기(`+graphstate`), R-GAT(`+rgat`)

## 유지 계약

- 행동 출력: `[a_x,a_z]`. 정책 입력은 10차원 공통 관측(`experiment.observationSchema`, v2.3부터 상수 항법 유효·경과 제외)과 그것의 `tosm7_v5` 그래프만 허용(이전 특징은 기록 재현용)
- 비가시 시점 hidden truth·미래 상태·보상·결과 라벨 입력 금지
- 공통 관측: `landing2d.observation.capture` 단일 경로, 설정 `defaultCommonObservationConfig`, 잡음은 시간 기준 잡음표(`time_indexed_v1`)
- 공통 reward·environment·action·termination 변경 금지
  - 변경이 필요하면 비교군 공통이어야 하고, `docs/REWARD_KO.md` 근거와 측정 결과가 필요하다
  - 현재 reward_v5
- PPO 손실은 세 비교군이 완전히 같다. 특정 비교군에만 주는 손실 항·잔차 헤드·입력 표준화·우회 경로 금지
  - 2026-10-17 R-GAT 전용 명령 평활화 항 삭제
  - 손실 기울기는 `landing2d.rl.policyLossGradient`·`valueLossGradient` 단일 경로(PPO 갱신과 학습 진단이 공유)
  - 갱신 진단(손실·엔트로피·KL·clip 비율·기울기 노름)은 읽기만 한다. 진단 추가로 학습 수치가 바뀌면 안 된다(바뀌면 `algorithmVersion` 갱신)
- R-GAT (`relational-policy-v2.15`, 2026-10-24, `docs/RGAT_V2_DESIGN_KO.md` §23; 인코더·readout은 v2.12 §19와 같고 그래프 특징만 `tosm7_v5`)
  - 기본 인코더 `rgat_v2`
    - 표준 관계형 그래프 어텐션 2층, 노드 폭 16
    - 관계별 가중치 $W_r=\sum_b C_{rb}V_b$(공통 기저 3개). $C_r$는 온톨로지 관계 역할의 고정 의미 기술자이고 학습하지 않는다
    - attention 관계 임베딩도 의미 기술자+self 표시로 고정하며, 층마다 공유 attention 벡터 하나만 학습한다
    - 입력 의존 attention(`input_dependent_v1`)을 도착 노드의 모든 입력 간선(관계 유형·self 포함)에 대해 한 번 정규화
    - 층마다 R-GCN root(self-connection) 가중치 $W_0$, tanh 노드 갱신, LeCun 초기화
    - 곱셈 게이트·연산군·잔차 혼합 없음(`v2Operators = none`, `residualMix = 0`)
    - `grouped_factorized` readout은 온톨로지 종착 노드 `LandingCondition` 하나만 읽는다(`landing_sink_v1`). 나머지 노드의 증거는 의미 간선으로만 정책에 닿는다(2홉 안에 7개 노드 모두 도달). 종착 노드는 온톨로지가 선언한 노드이고 readout 시작값이 아니다
    - v2.14: 종착 노드 특징은 relative_x, relative_vx, drone_vz, sinθ, pitchRate의 부호 있는 o_t 값이다(`tosm7_v4`). o_t와 같은 이득·부호다. 종착 노드에 부호 없는 값이나 o_t보다 고이득인 사본을 넣지 않는다(v2.12 천막 반응, §21.1). 잠재 종착 노드(v2.13, `tosm7_v3`)는 학습되지 않았다(§21.5)
    - 현재 v2.15(`tosm7_v5`): 위 f3만 0이다. 수직속도는 DroneMotion의 원래 특징에서 의미 간선으로 전달한다. G2–G5 기준 유지, 수직 반응 소실 방지 G6 추가. 성능 개선은 재학습·게이트 전까지 주장하지 않는다.
    - 인코더당 1,800개, Actor 26-28, Critic 27-27로 총 6,101개
  - v2.7(§14)은 고정 순환 코드북으로 실패했고, v2.8(§15)은 3/4 양의 방향이나 평균 AUC −0.039917로 실패했다. v2.9(§16)는 산술평균 공유 readout에서 두 arm 모두 `Reached80` 1/4로 실패했다. v2.11(§18, 7노드 고정 코드북 readout)은 개발 게이트를 통과했지만 확인 실험에서 목적 판정 0/5였다
  - v2.0–v2.13(`tosm7_v2`·`tosm7_v3` 포함)과 `rgat_v1`은 기록 재현용 선택지로만 유지한다
  - 금지: 곱셈 게이트·연산군·항등 초기화 경로·손으로 고른 readout 시작점·특정 비교군이나 시드에 맞춘 튜닝. 성능은 온톨로지 그래프, R-GAT 구조, 정책 입력 경로로만 검증한다
- 공통 학습 규칙 (`relational-policy-v2.1`, 2026-10-20, `docs/RGAT_V2_DESIGN_KO.md` §8)
  - 탐색 척도 `rl.initialLogStd = −2.0`(σ 0.135). 수렴 정책도 v2.0 값(σ 0.368)에서는 위험 접촉 53%라 공중 정지 함정이 생겼다. σ는 과제 잡음 허용치로만 고르며, 비교군·시드 결과로 고르지 않는다
  - validation 선별 `validation_screen_v1`: 검증마다 첫 20개가 착륙 ≥ 50%일 때만 나머지 80개를 비행한다. 통과한 검증은 100개 평가와 같고, 멈춘 검증은 20개로 기록한다(`validationEpisodes`)
  - 조기 종료 `validation_plateau_v1`: 최근 검증 3회 착륙 ≥ 95%, 150 update 이상. 750 update가 상한
  - learning AUC: 업데이트 축 [0, 750], 조기 종료 뒤 마지막 값 유지
  - `concurrentRuns`(스레드 풀 동시 학습)는 실행 옵션이다. 직렬과 비트 단위 동일함을 확인했다
  - 실시간 학습 그림 `landing2d.viz.TrainingMonitor`(2026-10-22)는 표시 전용이다
    - `run`의 `liveTraining` 옵션. MATLAB 데스크톱에서는 기본으로 켜지고, smoke·`-batch`에서는 꺼진다
    - 매 PPO update마다 학습 return·학습 착륙률(최근 `rl.evaluateEvery` update 이동평균)·approx KL을 그린다. validation 착륙·위험 접촉은 `rl.evaluateEvery`(25)마다 표시한다. 검증 일정은 체크포인트 선택·조기 종료·learning AUC 계약이라 그림 때문에 바꾸지 않는다
    - 훅 `c.trainingMonitor`(함수 핸들, 동시 학습은 `parallel.pool.DataQueue`)는 학습 서명 밖이다. `ppoTrain`이 에피소드 수집 전에 떼어 내고 값만 읽으며, 반환 run 설정·체크포인트에 남지 않는다. 모니터 유무로 학습 결과가 비트 단위로 같아야 한다(self-test `ppo-smoke`)
- 그래프(`docs/TOSM7_ONTOLOGY_KO.md`, `tosm7_v5`)
  - 7노드·4관계+self·20간선·6채널
  - 모든 특징은 $o_t$와 공개 보정 상수의 결정론적 함수
  - `tosm7_v5`: LandingCondition f1–f5 = (relative_x, relative_vx, 0, sinθ, pitchRate). 나머지는 부호 있는 o_t 값 그대로다. 접지 한계비는 `semanticEvidence` 서술값으로만 남는다. `tosm7_v2`·`tosm7_v3`·`tosm7_v4`는 기록 재현용
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
  - 학습 시드 s → `rl.seed = base + s − 1`. 기본 1–5, v4 확장 1–10, v5 대조군 수정 확인 11–15, v2.0 확인 16–20(`v2`), v2.3 확인 21–30(`v23`), v2.4 확인 51–60(`v24`), v2.5 개발 61–64(실패; 71–80 미사용), v2.6 개발 81–84(실패; 91–100 미사용), v2.7 개발 101–104(실패; 111–120 미사용), v2.8 개발 121–124(실패; 131–140 미사용), v2.9 개발 141–144(실패; 151–160 미사용), v2.10 개발 161–164(실패; 171–180 미사용), v2.11 개발 181–184(`v211Dev`), v2.11 확인 191–200(`v211`, 완료; §18.5), v2.12 개발 201–204(실패; 211–220 미사용), v2.13 개발 1–5(`v213Dev`, 실패; 221–230 미사용), v2.14 개발 1–5(`v214Dev`, 그래프 비교군만 새로 학습, PPO 1–5 재사용), v2.14 확인 231–240(`v214`, 게이트 통과 시에만, PPO도 같은 코드로 학습)
- 체크포인트 선택은 validation만 사용
  - test·stress·고정 사례·probe 결과로 체크포인트·임계값·사례를 고르는 것은 금지
- 통제 사례 S1–S4(`landing2d.evaluation.factorialCases`)
  - 반복마다 같은 시드·deadline·평가 구간
  - 모든 값이 학습 범위 안
  - 사례 시간 배치를 정책 결과에 맞춰 조정하는 것은 금지
- 학습 범위 밖 조건(`defaultEvaluationConfig.generalization`)은 학습 범위를 실제로 벗어나야 한다(검증됨)
- 평가 지표
  - 평가 전용 참값으로만 계산(`landing2d.evaluation.episodeMetrics`). 온톨로지 노드·attention·보상 미사용
  - 추종 오차는 카메라 광축 기준 aim error, 단일 정의 `landing2d.evaluation.aimError`($e_x-mh$, $m=\tan(-\theta_C)$, 보상과 같은 기울기). 그림도 이 함수를 쓴다
  - 외부 주입 누락과 정책 유발 시야 이탈을 분리 기록
  - 실패 분류는 `landing2d.evaluation.failureClasses`의 사전 고정 규칙. 결과를 보고 규칙·임계값을 바꾸지 않는다
  - 관측 잡음 민감도·궤적 분산·명령 변화 감소는 같은 run의 추종 오차·회복 시간·속도 민감도와 함께만 해석(`EXPERIMENT_DESIGN_KO.md` §1)
- open-loop probe
  - 정책과 무관한 기준 구동기 궤적 사용
  - 명목 재생 = 환경 관측(비트 일치)
  - 정책 행동을 궤적에 되먹이지 않음
  - 잡음 대비는 같은 물리 궤적을 다른 잡음표(전용 난수열)로 재생한다
  - attention 변화는 기술 지표이며 인과적 중요도로 해석 금지
- 학습 진단(`landing2d.evaluation.trainingDiagnostics`)
  - R-GAT 기울기·파라미터 변화는 체크포인트에서 계산. 초기값은 `landing2d.rl.initialAgent`(PPO 시작점과 동일)로 재구성
  - 진단 결과로 체크포인트·비교군을 고르지 않는다
- 통계
  - 분석 단위 = 학습 시드. 비교군 차이는 학습 시드별 짝 차이
  - 학습 시드 하나로는 방법 간 차이를 주장하지 않는다
  - 명령 변화 감소는 같은 쌍의 추종 오차와 함께만 해석
- 결정 추적(`+trace`, 2026-10-19)
  - 진단 도구다. 평가 지표가 아니며, 체크포인트·사례·임계값 선택에 쓰지 않는다
  - 읽기 전용이다. 루프는 `rolloutEpisodeV2`와 같은 순서·같은 함수를 쓴다. 센서 경로 재실행과 Actor 캐시가 환경·정책 값과 비트 단위로 같아야 한다(`landing2d:TraceReplay`, `landing2d:TraceForward`). 환경·보상·PPO·R-GAT 파일은 이 도구 때문에 바꾸지 않는다
  - 그래프는 체크포인트 `encoderSpec.T`에서 읽는다. tosm7 그래프(위상은 `tosm7_v1` = `tosm7_v2`)와 다르면 `landing2d:TraceSchema`로 멈춘다. 그래프 정의를 바꾸면 `+trace/labels.m`·`graphSchema.m`의 의미 표도 함께 고친다
  - 기본 체크포인트는 `onto_rgat_ppo` 학습 시드 21(v2.3 첫 시드, `registry.trainSeeds.v23(1)`)이다. 층 수는 체크포인트 `encoderSpec.layers`에서 읽는다(범례·설명·DAG·α 막대). 학습되지 않은 가중치는 `mock`으로만 쓰고, 출력에 `TEST ONLY` 표시를 붙인다
- 잡음 반복 라이브 비교(`run_live`, `landing2d.orchestration.runLive`, 그림 `landing2d.viz.ReplicateLiveView`, 2026-10-22)
  - 진단 도구다. 평가 지표가 아니며, 체크포인트·사례·임계값 선택에 쓰지 않는다
  - 통제 사례(S1–S4)의 시나리오·초기 상태·주입 누락을 고정한다. 반복 r은 `replicateSeeds`(고정 사례 시드 + r − 1)를 쓰므로 시간 기준 센서 잡음표(마커 코너·융합 측위·tracker)만 바뀐다. 정책은 결정론적이다
  - 모든 에피소드를 한 결정씩 함께 진행한다(`rolloutEpisodeV2`와 같은 함수·순서: 정책 입력 → `policyAction` → tanh → `environment.step`). 환경·보상·정책 코드는 이 도구 때문에 바꾸지 않는다
  - 끝나면 같은 에피소드를 `landing2d.evaluation.rolloutSet`으로 다시 계산해 연구 지표를 내고, 라이브 궤적·요청 가속도가 비트 단위로 같아야 한다(`landing2d:LiveReplay`)
  - 반복 간 확산(요청 가속도 sqrt(var a_x + var a_z), aim error 표준편차)은 같은 run의 aim error·결과와 함께만 해석한다
- 결과 생성 없는 수치·그림 작성 금지
- 체크포인트: `results/checkpoints/<method>_sNN[_gNN].mat`
  - 학습 서명(알고리즘 버전·rl·experiment·graphState) 불일치 시 재학습
  - `trainMethods`(run.m의 `train.<비교군> = false`)에서 빠진 비교군은 학습하지 않는다. `results/checkpoints`와 `results/archive/*/checkpoints`에서 쓸 수 있는 가장 최근 체크포인트를 쓰고, 없으면 오류로 멈춘다(학습으로 넘어가지 않음)
    - 쓸 수 있는 체크포인트: 서명이 일치하는 것, 또는 인코더 코드가 같은 R-GAT 버전(v2.12–v2.15)이면서 rl·experiment·행동 상수가 같은 그래프 비교군 체크포인트
    - 후자는 학습 당시의 graphState(그래프 특징)로 평가하고 경고를 띄운다
  - PPO(`baseline`)의 서명은 graphState를 보지 않고, 알고리즘 버전 대신 PPO 경로 버전(`landing2d.rl.baselineVersion`)으로 비교한다(v2.13). 그래프 비교군만 바꾸는 버전은 PPO 경로를 건드리지 않았음을 확인한 뒤에만 그 목록에 넣는다. PPO 경로(o_t·MLP·PPO 손실·검증·난수열)를 바꾸면 새 PPO 경로 버전을 만든다
  - 평가 설정(`c.evaluation`)은 서명 밖

## 실행 계약

```matlab
run_check                    % self-test + smoke
run_check('learnability')    % 새 환경에서 과제 학습 가능성 사전 점검
run                          % 스크립트(2026-10-23): run.m 맨 위 runSettings(학습 시드, 비교군별 학습 여부 train.<비교군>, 포함 비교군, 재학습, 실시간 학습 그림, 동시 학습, 평가 항목, 그림 표시, self-test)를 고친 뒤 F5. 학습은 사용자가 직접 실행한다
                             % 현재 값 = v2.15 개발: 시드 1–5, PPO false(재사용), TOSM·Shuffled true, 평가 6종
landing2d.orchestration.runPipeline(struct('trainSeeds',1:5,'trainMethods',{{'onto_rgat_ppo','shuffled_rgat_ppo'}}))   % 코드에서 옵션으로 실행 (필드 = runSettings, 비교군별 학습 여부는 trainMethods 목록)
% 기록: v2.3 확인(시드 21–30)·v2.4 확인(51–60)·v2.11 확인(191–200, 커밋 387e935)은 당시 함수 run(struct('trainSeeds',...,'concurrentRuns',8,'concurrentPool','threads'))로 실행했다
% (판정표 results/evaluation/v23_/v24_/v211_primary_endpoints.csv, v2.11 학습은 results/v211_scripts/chain_v211.sh, 결과 §18.5)
% v2.12 개발 게이트는 results/v212_scripts/train_v212_dev.m
% 그 뒤 results/v214_scripts/gate_v214_dev.m (개발 게이트 G2–G5, §22.4; v2.13은 v213_scripts, §21.4)
landing2d.evaluation.v215DevelopmentGate()  % v2.15 학습 후: validation G2–G6, 체크포인트 history로 계산
% §20 종합 그림·표는 results/summary_scripts/summary_confirmatory.m
run_scenario('S4')
run_live                                   % S4, 세 비교군 × 학습 시드 1, 센서 잡음 반복 10개를 라이브로 겹쳐 그림 (비교군별 창 + 확산 비교 창)
run_live('S4',struct('replicates',20,'trainSeeds',1:3,'speed',1))   % 반복 수·학습 시드·실시간 속도 지정 (체크포인트는 run.m으로 먼저 학습)
run_scenario('S4',struct('trace',true))    % 결정 추적 대시보드 (학습된 M2, 기본 시드 21; 현재 버전 체크포인트가 필요)
run_scenario([],struct('replay','results/trace/<저장한 파일>.mat'))   % 대시보드에서 저장한 기록 재생
run_check('trace')                         % 결정 추적 수용 시험 A01–A13
run_check('trace',struct('trainSeed',1))    % v2.15 학습 후 시드 1로 검사
% 이전 특징 모델을 명시적으로 검사할 때만 allowArchivedCheckpoint=true (자기 특징을 복원해 검사).
```

## 명명 규칙 (2026-10-19, INCSL 용어 DB)

- 근거와 전체 변경표는 `docs/VARIABLE_NAMING_AUDIT.md`에 있다. 새 식별자는 DB `canonical_en`을 camelCase로 쓴다. 문서에 정의된 수학 기호(Γ=`G`, `O`, `X`, `H`, `W`·`a`·`E`, `alpha`, `g`, `mu`·`sigma`, KF의 `F`·`Q`·`C`·`P`·`y`)는 기호 그대로 둔다
- 행동은 세 가지로 구분한다: `preTanhAction`(tanh 이전 가우시안 표본) → `normalizedAction`(tanh, [-1,1]) → `requestedAcceleration`([m/s²])
- 정책·Critic 입력은 `policyInput`(10차원 $o_t$ 또는 그 노드 특징)이다. 환경 상태(`state`, 물리 참값)와 Adam 상태(`*OptimizerState`)와 섞어 쓰지 않는다
- R-GAT: 입력 노드 특징 `X` → `attentionPreActivation` → `attentionScore`(softmax 입력) → `alpha`(정규화 계수) → `edgeMessages` → 집계 `Z` → 노드 상태 `H` → graph embedding `g`
- 정규화 값은 `normalized*` 접두사를 쓰고 물리 값은 단위 접미사(`*Meters`)를 쓴다. `*Norm` 접미사는 노름(크기)으로 읽히므로 쓰지 않는다
- MATLAB 내장 함수 이름(`norm`, `get`, `det`, `gamma`, `log`, `text` 등)을 변수 이름으로 쓰지 않는다
- 학습 서명·그래프 해시·체크포인트·결과 스키마에 들어가는 이름(`traj.command`, `captureRate`, 노드·관계 이름, 설정 필드)은 마이그레이션 없이 바꾸지 않는다(감사 문서 §4)

## 검증 계약

- `landing2d.orchestration.selfTest`: 14개 검사
  - contract, seeds, scenario-family, factorial-cases, causal-boundary, scenario-dynamics, termination
  - context-graph, ppo-smoke, relation-attention, common-observation, relation-shuffle, probe-replay, evaluation
- 결정 추적 시험 `landing2d.trace.selfTest`(A01–A13)는 위 14개와 별도다. `run_check('trace')`로 실행하며 v2.3 시드 21 체크포인트가 필요하다
- 구조 변경 후에는 `run_check`(self-test + smoke) 실행. `+trace`·대시보드·그래프·관측 경로를 바꿨으면 `run_check('trace')`도 실행
- 실제 MATLAB을 실행하지 않았으면 통과를 주장하지 않는다
