# 코드 유지 가이드 — minimal_relational_v3.1 (2026-10-24)

사용자 요청: 기존 2D 물리·센서는 유지하고 연구 구조를 단순화한다. 이 문서가 현재 실행 계약이다. 이전 v2 계약·결과 이력은 [보관본](docs/archive/AGENTS_V2_20261024.md)에 있으며 현재 4노드 구조에 적용하지 않는다.

## 현재 경로

- 개요 `docs/MINIMAL_SYSTEM_KO.md`, 온톨로지·수식 `docs/TOSM4_ONTOLOGY_KO.md`, 귀납적 편향·업데이트 `docs/INDUCTIVE_BIAS_KO.md`, 실험·주장 `docs/EXPERIMENT_DESIGN_KO.md`.
- 루트 MATLAB 파일은 `run.m`, `run_check.m`, `run_scenario.m`, `run_live.m` 네 개만 둔다.
- `run.m` → `landing2d.minimal.runPipeline`. 학습은 사용자가 직접 실행한다. 에이전트는 self-test·1 update smoke만 실행할 수 있다.
- **이번 작업의 명시적 예외 승인(2026-10-24):** 사용자가 v3.1 개발 시드 271–275 × 세 비교군의 본 학습과 고정 일반화 평가를 에이전트가 실행하도록 허용했다. 이 15개 모델과 해당 평가에 한해 위 직접 실행 제한을 해제한다. 확인 시드 281–290이나 다른 버전의 자동 학습 허가는 아니다.
- **위 승인 작업 완료:** 15개 체크포인트·9,000개 평가와 수치 검증을 완료했다. OOD 착륙률 PPO 77.93%, TOSM 59.07%, Shuffled 44.87%; 두 주 비교 구간 모두 0 포함. v3.1을 성능 개선안으로 채택하지 않는다. 원자료·실패 분석·실행 조정은 `docs/MINIMAL_V31_RESULTS_20261024_KO.md`에 있다. 구조 시험 통과와 품질 경로 활성화를 성능 증거로 확대하지 않는다.
- 설정 `landing2d.minimal.config` 기본은 v3.1이다. `config(root,'v3')`는 한 홉 v3 재현용, `primaryConfig`, `orchestration.runPipeline`은 v2 재현용이다. 모델 변경 근거는 `docs/MINIMAL_V31_DESIGN_KO.md`.
- 공통 PPO·환경·센서·평가 함수는 기존 패키지를 재사용한다. 새 인코더는 `src/algorithms/+landing2d/+minimal`, 새 실행·평가는 `src/orchestration/+landing2d/+minimal`.
- 새 체크포인트는 `results/minimal_v31/checkpoints/`, 평가는 `results/minimal_v31/generalization_v1/<phase>/s<시드목록>/`에 저장한다. 기존 v3 결과를 덮어쓰거나 합치지 않는다.

## 공통 비교 계약

- 비교군은 registry의 `ppo`, `onto_rgat_ppo`, `shuffled_rgat_ppo` 세 개.
- 같은 2D 환경·센서·10차원 o_t·reward_v5·[a_x,a_z]·종료·PPO 손실·탐색·예산·검증·조기 종료, **총 파라미터 1,419개씩**.
- PPO Actor 10→58→2, Critic 10→55→1. 그래프 Actor/Critic 각각 371개 인코더, 8→32→2 / 8→32→1. 두 행동의 logσ 2개 포함.
- 정책은 direct-policy다. 착륙 승인·SAFE_ABORT guard·방법 전용 손실·평활화·입력 필터·우회 경로를 추가하지 않는다.
- 공통 관측은 `landing2d.observation.capture` 단일 경로, 시간 기준 잡음표 `time_indexed_v1`.
- 숨은 참값·미래·보상·결과 라벨을 정책에 넣지 않는다. 참값은 평가 지표에만 사용한다.
- 물리·센서·보상을 변경해야 한다면 사용자 범위를 먼저 확인하고 모든 비교군에 공통 적용하며 근거·측정을 기록한다.

## 작은 그래프 계약

- 특징 `tosm4_v1`, 현재 인코더 `rgat_minimal_v2`, 학습 서명 `minimal-relational-v3.1`. `rgat_minimal_v1`·v3.0은 보관 재현용이다.
- 4노드: ObservationQuality(o9–10), TargetMotion(o4), OwnMotion(o5–8), RelativeState(o1–3).
- X는 10×4 공통 좌표. 각 o_t 성분이 정확히 한 번 나타나며 열 합은 o_t다. 파생 특징·고이득 사본·typeId 없음.
- 의미 간선: Quality→Relative(qualifiesEstimate), Target→Relative와 Own→Relative(informsMotion). self 4개 포함 총 7간선.
- 공유 입력 사영 tanh(PX+bP) → 폭 8의 R-GAT 두 홉(가중치 공유) → RelativeState 상태 선택. Actor/Critic은 독립 인코더.
- 동적 점수 a' LeakyReLU(W_r h_j + W_r h_i + b_a) + beta_r. 점수 8 + 공동 bias 8 + 관계 bias 3 = 19개, 인코더 371개와 총 1,419개 유지. 도착 노드 모든 입력 간선에 안정 softmax, root W0 + self, tanh, fan-in 초기화. 두 홉의 같은 파라미터에 기울기를 합친다.
- 첫 홉에서 품질 정보가 RelativeState로 전달되고 두 번째 홉의 query에서 운동 간선 선택에 쓰일 수 있다. 고정 품질 게이트나 감쇠 규칙은 없다. `cache1`은 기존 표시 코드용 첫 홉 cache 별칭이고 역전파는 `cache.layers`를 사용한다.
- 기저·의미 코드북·곱셈 게이트·잔차 혼합·학습 readout 없음. 관계는 강제 제어 규칙이나 신뢰도 필터가 아니다.
- Shuffled: 세 의미 간선 중 두 개(2/3) 관계 변경, self·위상·관계 수 보존, graphSeed=trainSeed. 가능한 비정상 배치 두 개 중 시드로 고정한다. 결과를 보고 선택하지 않는다.
- 귀납적 편향은 입력 배치·허용 정보 경로·관계 가중치 공유에 있다. 별도 편향 점수·보상·손실을 만들지 않는다. MLP도 상태 사이 가중치를 공유하므로 '편향 없는 PPO'라고 부르지 않는다.
- Actor/Critic은 독립 인코더다. Critic 손실은 Actor 인코더에 직접 역전파되지 않는다. 상태 독립 logσ의 엔트로피 항도 인코더에 직접 역전파되지 않는다.

## 실행과 검증

```matlab
run_check                         % 새 11검사 + 세 비교군 1 update smoke + 평가·그림
run_check('contracts')            % 새 11검사만
run_check('legacy')               % 보관 v2 14검사
run_check('trace',struct('trainSeed',1,'allowArchivedCheckpoint',true)) % 보관 7노드 A01–A13
run                               % v3.1 개발 271–275, 세 방법 학습·일반화 평가 (train=true)
run_scenario('S1')                 % 현재 모델의 고정 사례
run_live('S2',struct('trainSeeds',271,'replicates',10))
```

- 구조 변경 후 `run_check`. 공통 코드 변경 시 legacy 검사도 실행한다. 그래프·관측 공통 경로 변경 시 보관 trace 회귀도 검사한다. 실행하지 않은 MATLAB 검사를 통과했다고 쓰지 않는다.
- 새 검사는 정보 보존·공통 조건·파라미터 수·shuffle 재현·모든 인코더 파라미터/입력 유한차분·batch/attention·사례·서명 격리를 확인한다.
- `checkLearningPath`는 실제 PPO 손실의 관계/attention 미분·표본 기울기 누적·Adam 갱신을 확인한다. `checkGeneralization`은 한 요인만 바뀌는 짝짓기·범위 밖 조건·시드 단위 집계·두 주 비교 구간을 검사한다. 모두 TEST ONLY이며 성능 지표가 아니다.
- `checkDynamicAttention`은 query 변화에 따른 운동 간선 순위 역전, 품질→두 번째 홉 경로, 같은 시드에서 PPO 초기 가중치·출력·공통 학습 설정 보존을 검사한다.
- 이전 7노드 trace 대시보드를 4노드에 연결하지 않는다. 새 모델의 실시간 진단은 물리 궤적·행동을 표시하는 `run_live`를 쓰며 `rolloutSet`과 비트 일치 검사를 유지한다.
- smoke는 TEST ONLY다. 본 학습 성능·seed 효과의 증거로 쓰지 않는다.

## 학습·평가 규칙

- v3 개발 251–255 완료·확인 261–270 미실행은 보관한다. v3.1 새 개발 271–275, 확인 281–290을 registry에 등록했다. 세 방법 모두 새 시드로 학습한다. 확인은 phase='confirmation', 시드 281:290, 세 train=true로 사용자가 실행한다.
- validation 2001–2200, test 3001–3200, stress 9001–9200, 고정 사례 41001–49999, 학습 에피소드 100001–999999. split 겹침 금지.
- 750×6 상한, 검증 25 update마다, 기존 validation_screen_v1·validation_plateau_v1. 체크포인트 선택은 validation만.
- train=false면 현재 서명에 맞는 모델을 읽기만 하고, 없으면 오류. v2 체크포인트는 현재 모델로 쓰지 않는다.
- CV/CA × 정상/누락 독립 학습 분포는 유지한다. 현재 설명용 사례는 S1 기준, S2 누락, S3 가속이며 동일 시드·초기 상태·deadline·평가 구간이다.
- 평가 프로토콜 `minimal_generalization_v1`은 학습 서명 밖이다. 주 지표는 motion/dropout/noise 세 OOD 조건의 동등 가중 착륙률, 주 비교는 TOSM−Shuffled와 TOSM−PPO. 별도 편향 점수 없음. 두 주 비교는 개별 97.5% t 구간(Bonferroni), 보조 지표는 기존 95% 구간.
- 일반화는 가속 0.3–0.8→1.0–1.5 m/s²(양쪽 CA), 누락 0.5–1.0→1.2–2.0초(양쪽 severe), 센서 잡음 ×1→×2. 같은 에피소드 시드로 한 요인만 바꾸고 조건별 ID/OOD·차이·실패를 저장한다. 조건당 100개. 개발 stress 9001–9100, 확인 9101–9200.
- OOD 성공률과 함께 위험 접촉·추종 오차·최악 조건·ID 대비 감소를 해석한다. 감소가 작거나 attention/gradient가 크다는 이유만으로 유리한 일반화를 주장하지 않는다.
- AUC/Reached80는 보조 지표다. held-out와 S1–S3는 `includeDiagnostics=true`일 때 추가한다. S4·combined OOD·probe·G2–G6는 주 실행에서 제외한다.
- 지표는 공통 episodeMetrics, 추종 오차는 aimError. 명령 분산·변화는 같은 run의 추종·회복·성공과 함께만 해석한다. attention은 인과적 중요도가 아니다.
- 분석 단위는 학습 시드, 방법 차이는 seed-paired. 한 시드나 smoke로 방법 차이를 주장하지 않는다. 결과 없이 수치·그림을 만들지 않는다.

## 유지·명명

- `preTanhAction` → `normalizedAction` → `requestedAcceleration`을 구분한다. 정책 입력은 `policyInput`, 물리 참값은 `state`.
- 수학 기호 X,H,W,a,alpha,g는 유지한다. 새 용어는 `docs/VARIABLE_NAMING_AUDIT.md` 규칙을 따른다. MATLAB 내장 함수를 변수명으로 가리지 않는다.
- 학습 서명·그래프 해시·저장 스키마 이름은 마이그레이션 없이 바꾸지 않는다. 표시 훅은 학습 수치와 난수열을 바꾸지 않아야 한다.
- 변경 전 소스는 `results/archive/v215_pre_rebuild_2026-10-24/source`와 SHA-256 목록으로 보존했다. 사용자 수정·옛 체크포인트·기록을 삭제하지 않는다.
- 일반화 평가 개정 전 소스는 `results/archive/minimal_v3_pre_generalization_20261024/source`, v3.1 모델 변경 직전 전체 소스는 `results/archive/minimal_v3_pre_dynamic_20261024/source`와 SHA-256 목록으로 보존했다.
