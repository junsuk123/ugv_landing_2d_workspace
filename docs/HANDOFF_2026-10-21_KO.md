# 작업 인계: Claude Code → Codex (2026-10-21 02:05 KST)

이 문서만 읽어도 이어서 작업할 수 있도록 상태·명령·주의점을 모두 적었다. 계약은 이 폴더의 `AGENTS.md`, 설계와 사전 등록은 `docs/RGAT_V2_DESIGN_KO.md` §8–§11이 원본이다. 이 문서와 그 둘이 다르면 그 둘을 따른다.

## 0. 지금 상태 한눈에

| 항목 | 값 |
|---|---|
| 작업 폴더 | `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_d4` (git worktree) |
| 브랜치 | `rgat-v2-4-fixedops` (이 인계 문서 커밋 직전 HEAD `283d9d2`) |
| 알고리즘 버전 | `relational-policy-v2.4`, `comparison_registry_v10` |
| 실행 중인 프로세스 | 없음. 2026-10-21 02:03에 v2.4 확인 실험 학습을 사용자 지시로 중단했다 |
| 다음 할 일 | §3의 v2.4 확인 실험 재개 → 판정 → 설계 문서 §11.4 작성 |
| 사용자 언어 | 한국어로 보고한다 |

## 1. 연구 질문과 지금까지의 결론

- 질문: 드론의 UGV 착륙 2D 과제에서 사람이 설계한 TOSM 온톨로지 관계를 R-GAT로 PPO 상태 표현에 넣으면, 같은 관측·보상·예산·파라미터 수(6,101)에서 학습과 일반화가 **학습 시드와 무관하게** 좋아지는가. 학습 시드를 여러 개 쓰는 이유가 이 "시드 일반화" 검증이다.
- 비교군 3개(고정): `ppo`(일반 PPO), `onto_rgat_ppo`(TOSM), `shuffled_rgat_ppo`(관계 유형 교란).
- 판정 규칙(§8.4, 모든 확인 실험 공통): 학습 시드별 짝 차이. 95% t 구간이 0을 벗어나면 "차이", 그중 10개 중 8개 이상 같은 방향이면 "시드와 무관한 차이", 90% 구간이 ±0.05 안이면 "동등(TOST)", 나머지는 "결론 없음". 주 평가 변수 5개(학습 범위 밖 성공률 motion·dropout·noise·combined, held-out 성공률) × 비교 2개(TOSM−Shuffled, TOSM−PPO) = 10개에 Holm 보정.

| 버전 | 인코더 | 확인 시드 | 결과 요약 | 기록 |
|---|---|---|---|---|
| v1.1 | 1층 `typed_v1`(곱셈 게이트·연산군) | 11–15 | TOSM−Shuffled는 held-out +1.4%p(5/5, Holm 후 유의하지 않음)뿐 | main `7d97953`, `EXPERIMENT_DESIGN_KO.md` §2.1 |
| v2.0 | 2층 `rgat_v2`(게이트 없음) | 16–20 | 10개 모두 차이의 증거 없음. 수렴 TOSM 4/5, 교란 2/5, PPO 2/5 | 브랜치 `rgat-v2` `05829a4`, 설계 문서 §7 |
| v2.1 | 2층 + 탐색 σ −2, validation 선별 | (게이트만) | 게이트 12/12 통과. 확인 실험은 학습 전 취소 | `rgat-v2-1` `d9dd2df`, §8 |
| v2.2 | 4층(폭 12, 분산 보존 잔차, 이득 5/3) | (게이트만) | 게이트 도중 중단 | `rgat-v2-depth4` `15d803c`, §9 |
| v2.3 | v2.2 + 10차원 $o_t$, `tosm7_v2` | 21–30 | 아래 표 | `rgat-v2-depth4` `0a5771e`, §10.7 |
| v2.4 | v2.3 + 의미별 고정 연산 | 51–60 | **학습 중 중단, 미완** | `rgat-v2-4-fixedops` `283d9d2`, §11 |

v2.3 확인 실험 결과(n = 10, 30 run 모두 수렴·조기 종료):

| 평가 변수 | TOSM − Shuffled | TOSM − PPO |
|---|---|---|
| held-out 성공률 | +0.015, 동등 | +0.001, 동등 |
| OOD motion(UGV 가속 1.0–1.5 m/s²) | +0.068, 결론 없음 | **−0.164, 시드와 무관한 차이(PPO 우위, 1/8)** |
| OOD dropout | +0.024, 차이(동시에 ±5%p 동등) | +0.007, 동등 |
| OOD noise | +0.024, 결론 없음 | −0.029, 결론 없음 |
| OOD combined | +0.059, 결론 없음 | **−0.164, 시드와 무관한 차이(PPO 우위, 1/9)** |

- Holm 보정 후 유의한 것은 없다(최소 0.079). 학습 AUC: PPO 0.800, TOSM 0.714, Shuffled 0.757(차이의 증거 없음).
- 결론: 관계 연산을 모두 학습하는 4층 R-GAT에서 온톨로지 효과는 나오지 않았다. 학습 분포에서는 동등, 학습 범위 밖 UGV 가속에서는 그래프 비교군 둘 다 PPO보다 낮다.

## 2. v2.4가 무엇이고 왜 하는가

- 사용자가 GPT로 별도 Python 4층 개발 실험을 했다(다른 시뮬레이터, 개발 시드 31 하나, 400 update). 보고: 관계 의미별로 연산을 고정한 4층 "Fixed TOSM"이 가장 좋았고(착륙 96.7%), 연산을 학습하는 "Adaptive TOSM"은 0%였다. 그 Python 코드는 이 PC에 없고, 수치는 사용자가 붙여 넣은 보고서 값이다.
- 사용자 결정(2026-10-21): 그 구성을 MATLAB에서 확인한다. 그래서 v2.0부터 금지였던 곱셈 게이트·연산군을 **v2.4에 한해** 허용하고(AGENTS.md 수정됨), 학습 가능성 게이트는 **생략**한다.
- 구현(`graphState.v2Operators = 'semantic_fixed_v1'`, `'none'` = v2.3):
  - 층마다 $A_l=\tanh(Z^{prop}_l+W^{root}_l h+b_l)$, $M_l=\tanh(Z^{mod}_l)$, $F^l=(1+M_l)\odot A_l$, 그 뒤 v2.3과 같은 분산 보존 잔차.
  - modulate = `qualifiesEstimate`, `conditionsLanding`(의미 간선 8개). propagate = `informsMotion`, `affectsVisibility`(5개)와 self(7개). 두 그래프는 도착 노드마다 softmax를 따로 한다.
  - 두 그래프가 층의 $W_r$(기저 2개)·$a$·$E$를 함께 써서 파라미터 6,101개, 같은 시드의 초기 가중치도 v2.3과 같다.
  - Shuffled: 관계 유형 10/13 이상 변경 + 연산군 10/13 변경(`minOperatorChangedFraction = 0.7`, v1.1 규칙).
  - 바뀐 파일: `+graphstate/{defaultGraphStateConfig,validateGraphStateConfig,encoderInit,encoderForward,encoderBackward}.m`, `+rl/algorithmVersion.m`, `+config/{methodRegistry,applyMethod}.m`, `+orchestration/selfTest.m`, `+trace/actorForward.m`.
  - 검증: `run_check` 14/14 + smoke 통과(`results/v24_run_check_log.txt`). 모든 파라미터 군과 입력의 해석적 기울기 = 중앙 차분, 연산군별 α 합 1, modulate 간선 없는 노드의 게이트 정확히 1, 4홉 경로가 4층에서 열리고 3층에서 정확히 0, 연산군 10/13 변경.
  - 알려진 성질(결과와 무관하게 보고): modulate 간선이 하나뿐인 도착 노드는 그 풀의 α가 언제나 1이다.
  - 결정 추적(`+trace`)은 v2.4 층을 아직 전개하지 못해 `landing2d:TraceSchema`로 멈춘다(§5의 2번).

## 3. 중단된 v2.4 확인 실험과 재개 방법

### 3.1 중단 시점 상태 (02:03, 기록용)

- 완료된 체크포인트 4개: `results/checkpoints/ppo_s53.mat`, `ppo_s56.mat`, `ppo_s57.mat`, `ppo_s58.mat`(모두 조기 종료). 나머지 26 run은 학습 도중이었고 중간 체크포인트가 없어 처음부터 다시 학습된다.
- 진행 기록: `results/v24_interrupted_2026-10-21_0203/` (학습 로그 2개, `v24_progress_at_stop.txt`).
- 중단 시점 일부 값: TOSM s51 200회 91%, s52 200회 95%, s53 150회 81%, s56 175회 76%; Shuffled s51 175회 88%; PPO s51·s52는 300회 넘게 0%(공중 정지).
- **이 중간 값으로 아무것도 바꾸지 않는다.** 사전 등록(§11.3) 이후 본 값이다.

### 3.2 재개가 정당한 이유

- 학습은 시드로 결정론적이고, 동시 학습과 직렬 학습은 비트 단위로 같다(§4에서 확인). 같은 명령을 다시 실행하면 끝난 run은 학습 서명 일치로 체크포인트를 다시 쓰고(로그에 `reusing checkpoint`), 끝나지 않은 run은 같은 시드로 처음부터 학습하므로 끊기지 않은 실행과 결과가 같다.
- 시드·비교군·지표·규칙은 그대로다. 결과 보고 때 "02:03 중단 후 재개"를 함께 적는다.
- 코드를 바꾸면 학습 서명이 달라져 완료된 체크포인트도 버려지고, 사전 등록과 다른 실험이 된다. **재개 전에 `src/` 파일을 바꾸지 않는다.**

### 3.3 재개 명령

Git Bash에서 한 번에:

```bash
bash "/c/Users/user/SynologyDrive/junsuk/학술대회/CICS2026/codes/ugv_landing_2d_workspace_d4/results/v24_scripts/resume_v24.sh"
```

같은 일을 단계별로(PowerShell이나 MATLAB 창에서):

```matlab
% 1) 학습: MATLAB 두 개를 동시에 (각각 8개 스레드 동시 학습). 작업 디렉터리 = results/v24_scripts
seeds = 51:55; run('train_v24.m')      % 프로세스 A
seeds = 56:60; run('train_v24.m')      % 프로세스 B (30초 뒤 시작)
% 2) 등록 명령 한 번 (체크포인트 30개 재사용, 평가 6종)
cd('C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_d4')
run(struct('trainSeeds',51:60,'concurrentRuns',8,'concurrentPool','threads'))
% 3) 사전 등록 분석 (작업 디렉터리 = results/v24_scripts)
runLogged('analyze_v24.m','<v24_scripts 경로>\v24_analysis_log.txt')
```

- `train_v24.m` sha256 `dfafd33f1d008f50…`, `analyze_v24.m` sha256 `e30b8909d4984173…`. 설계 문서 §11.3에 적힌 값과 같아야 한다. 고치지 않는다.
- 예상 시간(v2.3 기준): 학습 약 4시간 15분(PPO run당 약 45분, 그래프 run당 약 110–120분, 16개 동시), 평가 약 45분, 분석 수 초.
- 출력: `results/evaluation/*.csv`(평가), `results/evaluation/v24_primary_endpoints.csv`(판정 표), `results/figures/`, `results/v24_confirmatory_log.txt`.

### 3.4 끝난 뒤 할 일

1. `v24_primary_endpoints.csv`의 `Verdict` 열을 그대로 보고한다. 분석 스크립트는 "차이"가 "동등"보다 우선이라, 둘 다 참인 행은 `Difference`·`Equivalent` 열을 함께 적는다(v2.3 dropout 행 선례, §10.7.2).
2. 설계 문서 §11.4에 §10.7과 같은 형식으로 쓴다: 학습(수렴·조기 종료·AUC·시간·validation 생략 수), 주 평가 변수 표, 평균 성공률, 판정 요약(§1 해석표), 판정 밖 서술, 함께 보고할 것(중단·재개, 게이트 생략, 근거가 단일 시드 Python 실험, α = 1 성질).
   - validation 생략 수는 v2.3 때 쓴 `results/archive/v2.3_s21-30_2026-10-21/v23_scripts/valcount_v23.m`의 시드를 51:60으로 바꿔 계산했다(읽기 전용).
3. v2.3과 v2.4는 시드가 달라 짝 비교하지 않는다. 평균만 나란히 적는다.
4. 결과를 보고 연산 배치·층·시드·지표를 바꾸면 v2.5이고 학습 시드 61 이상으로 새로 등록한다.

## 4. 실행 환경 주의 (겪은 문제와 해결)

- Windows 11, MATLAB R2025b, `matlab -batch`. 리디렉션한 로그의 한국어는 깨진다(PASS/FAIL·숫자 줄은 읽힌다). 읽을 수 있는 로그가 필요하면 `results/v24_scripts/runLogged.m`(evalc + UTF-8 파일)로 실행한다. `runLogged`가 스크립트 안에서 `cd`하므로 로그 경로는 절대 경로로 준다.
- 병렬: 사용자 'Threads' 프로필이 작업자 8개로 제한돼 있다. 바꾸지 않는다. 학습은 프로세스 2개 × 스레드 8개. 평가는 run 안에서 'Processes' 풀(작업자 약 6개, 각 약 1 GB)을 띄운다.
- 메모리: 실메모리 16 GB, 사용자 앱(Chrome·ChatGPT·VS Code 등) 때문에 커밋이 약 50 / 57 GB까지 찬다. v2.3 평가 때 53.4 GB까지 올라갔지만 실패하지는 않았다. 메모리 부족으로 멈추면 같은 명령을 다시 실행하면 된다(체크포인트 재사용).
- MATLAB이 이 폴더에서 돌고 있을 때는 `.m` 파일을 고치지 않는다(실행 중인 함수가 바뀐 파일을 읽을 수 있음).
- 소스 파일은 CRLF다. 줄 끝을 바꾸지 않는다(파이썬으로 고칠 때 CRLF 보존).
- `results/`는 gitignore다. 체크포인트·평가·로그는 디스크(Synology 동기화)에만 있다. 지우거나 덮어쓰기 전에 `results/archive/`로 옮긴다.
- 사용자의 MATLAB 데스크톱 창이나 다른 앱 프로세스는 사용자 승인 없이 끄지 않는다.

## 5. 남은 일 (우선순위 순)

1. **v2.4 확인 실험 재개와 보고** (§3). 사용자가 가장 기다리는 결과다.
2. **결정 추적 v2.4 지원**: `src/orchestration/+landing2d/+trace/actorForward.m`의 `forwardV2`에 연산군별 전개(Tadd/Tmod, 게이트 $M$, $A$, 연산군별 α)를 넣고, `dependencyGraph.m`·`explainDecision.m`·`labels.m`·`TosmTraceDashboard.m`의 층 설명을 맞춘다. 기본 추적 시드는 지금 `registry.trainSeeds.v23(1)`(=21, `+orchestration/runTrace.m`과 `+trace/selfTest.m`의 기본값)이고 v2.3 체크포인트는 보관 폴더로 옮겨졌다. v2.4 체크포인트가 생기면 `v24(1)`(=51)로 바꾸고 AGENTS.md도 고친 뒤 `run_check('trace')`(A01–A13)를 돌린다. 학습 중에는 하지 않는다.
3. **보고서 갱신**: 사용자에게 준 결론 보고서 HTML 사본이 `results/reports/cics2026_conclusion.html`에 있다(v2.3 기준). v2.4 결과로 갱신한다. 노션 페이지(사용자 보고서에 링크된 이론·방법론, 실험 설계·검증, 코드·재현성)는 아직 고치지 않았다. 외부 페이지라 사용자 확인 후에만 고친다.
4. **정리 2단계(사용자 승인 필요)**: 사용자 커밋 `426e39e`(브랜치 `rgat-v2`, `_refactor` 작업 폴더: v1.1 결과 문서, `figureVisible true`, `trainSeeds.main 1:5`)를 최종 브랜치에 병합 → main 병합 → 결과 폴더 통합 → `_refactor`·`_d4` 작업 폴더 제거. `methodRegistry.m`의 `trainSeeds` 줄이 충돌한다.
5. Python(GPT) 시드 32–41 다중 시드 실험의 판정 규칙(결과 전 고정 권고)은 보고서 §4에 있다. 이 PC에서 그 실험은 돌지 않는다.

## 6. 파일 위치

| 무엇 | 경로 (`_d4` = 위 작업 폴더) |
|---|---|
| 계약 | `_d4/AGENTS.md` |
| 설계·사전 등록·결과 | `_d4/docs/RGAT_V2_DESIGN_KO.md` (§10.7 v2.3 결과, §11 v2.4 사전 등록) |
| 실험 설계 원칙·해석표 | `_d4/docs/EXPERIMENT_DESIGN_KO.md` §1 |
| v2.4 스크립트 | `_d4/results/v24_scripts/` (`train_v24.m`, `analyze_v24.m`, `runLogged.m`, `resume_v24.sh`, 실행 기록용 `chain_v24.sh`) |
| v2.4 중단 기록 | `_d4/results/v24_interrupted_2026-10-21_0203/` |
| v2.4 완료 체크포인트 | `_d4/results/checkpoints/ppo_s5{3,6,7,8}.mat` |
| v2.3 전체 결과 | `_d4/results/archive/v2.3_s21-30_2026-10-21/` (평가 CSV, 그림, 체크포인트 30개, 게이트 체크포인트 12개, 로그, `v23_scripts/`) |
| v2.1 게이트 결과 | `_d4/results/archive/v2.1_gate_s06-09_2026-10-20/` |
| v2.0 결과 | `codes/ugv_landing_2d_workspace_refactor/results/checkpoints/archive/v2.0_s16-20_2026-10-20/` |
| v1.1 결과 | `codes/ugv_landing_2d_workspace_refactor/results/checkpoints/archive/v1.1_s11-15_2026-10-19/` |
| 10/17 이전 옛 결과(사용자 승인으로 이동) | `CICS2026/_old_results_pre1017/ugv_landing_2d_workspace_refactor_results/` (`MANIFEST.txt`) |
| 결론 보고서 사본 | `_d4/results/reports/cics2026_conclusion.html` |

작업 폴더(git worktree) 목록: main `codes/ugv_landing_2d_workspace`(`7d97953`, detached), `_refactor`(`rgat-v2`, `426e39e`, 사용자 커밋), `_d4`(최종, `rgat-v2-4-fixedops`), `Downloads/ugv_landing_2d_workspace_planar_visibility_v2`(`codex/planar-visibility-ppo-v2`).

## 7. 사용자 결정과 선호 (지켜야 할 것)

- 결과는 사전 등록 규칙대로만 판정한다. 결과를 보고 설계·시드·임계값을 바꾸면 새 버전, 새 시드다. 체크포인트·사례·임계값을 test·stress·probe 결과로 고르지 않는다.
- 2026-10-20: 구조 결함은 게이트·가드·시드 맞춤 튜닝 없이 고친다(v2.0–v2.3).
- 2026-10-21: 의미별 고정 연산(곱셈 게이트 포함)은 v2.4에 한해 허용, 학습 가능성 게이트 생략(속도 우선).
- 관측·특징은 "구조상 불필요가 확정된 것만" 뺀다(v2.3에서 항법 유효·경과, normalizedCrossTrack, geometryQuadratic 제거).
- 보고는 한국어. 외부 서비스(노션 등) 수정·병합·작업 폴더 삭제는 사용자 확인 후.
