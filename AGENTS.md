# 일반화 목표 종료 (2026-10-26, 미달성)

사용자 결정으로 일반화·강인성 목표를 종료했다. 종합 결과와 진단, 논문 주장의 범위는 `docs/GENERALIZATION_GOAL_CLOSURE_KO.md`에 있다.

- 7개 후보와 평가 프로토콜 v1·v2(PPO 단독 보정) 어디에서도 개발 기준을 통과하지 못했다. 확인은 한 번도 열지 않았다.
- **목표 작업의 본 학습 반복 승인은 종료됐다.** 새 학습이나 새 후보는 사용자의 새 지시가 있을 때만 시작한다.
- 확인 환경 9101–9200과 확인 예약 시드는 미사용 상태로 보존한다.
- 공개 진입점(`run`, `run_check` 등)은 v5 재현 경로로 유지한다.
- 아래 v5 절과 그 이하 내용은 보관 재현용이다.

---

# 코드 유지 가이드 — relational_residual_v5 개발 후보 (2026-10-26)

현재 계약은 `docs/RELATIONAL_RESIDUAL_V5_KO.md`다. 아래 v4 이하 내용은 보관 재현용이며 이 절이 우선한다. 사용자가 승인한 목표 작업의 본 학습·평가 반복을 계속한다. 성능 우위는 아직 입증하지 못했다.

**v5 개발 완료·미채택(2026-10-26):** 20개 모델·12,000개 평가·303개 등록 파일을 검산했고 세 실행 모두 종료 코드 0이다. 첫 실행은 VS Code 재시작으로 종료됐으며 `development/interrupted_attempt_01/`에 보존했다. 재실행에서 중단 전 45줄을 글자 단위로 재현했다. 학습 5/5×4는 통과했지만 OOD 평균·강인성 기준은 실패했다. OOD 착륙률은 PPO/MLP/TOSM/Shuffled 97.27/94.73/96.73/96.53%이고 TOSM−PPO는 −0.53%p다. 확인 431–440은 열지 않았다. 종료 근거는 `results/relational_residual_v5/development/closed_evidence.json`이다. 사후 기술 분석(`residual_ceiling_power_review.json`)에서 PPO 천장 때문에 TOSM이 완벽해도 확인 기준 통과가 어려울 수 있음을 확인했다. 장시간 실행은 VS Code와 분리해 띄운다(WMI `Win32_Process.Create`).

**평가 프로토콜 v2(2026-10-26, 사용자 선택 2):** `docs/GENERALIZATION_PROTOCOL_V2_KO.md`. OOD 크기는 PPO 10개만으로 보정해 등록했다(보정 환경 9201–9300). 선택값은 가속 1.5–2.0 m/s², 누락 2.1–2.9 s, 잡음 ×3이다. 확인 시드는 431–450(20개)으로 늘렸다. 등록은 `results/generalization_v2_calibration/protocol_registration.json`이다. v5 개발 모델 20개의 v2 평가에서도 학습 기준만 통과했다. OOD 착륙률은 PPO 89.53, MLP 86.33, TOSM 89.13, Shuffled 91.33%다. 확인은 닫혀 있다. v2는 다시 보정하지 않는다. **다음 구조 후보(v6) 진행이나 목표 종료는 사용자 결정 전에 시작하지 않는다.**

- v4의 20개 모델·12,000개 평가를 종료·검산했고 세 실행 모두 종료 코드 0이다. 학습 기준은 통과했으나 OOD 평균·강인성 기준은 실패했다. 원자료·등록 소스·미분 fixture를 보존했다. 확인은 열지 않았다.
- v5 `relational-residual-v5.0`, 프로필/인코더 `relational_residual_v5`, 패키지 `landing2d.residual_context`, 그래프 `tosm4_context_v1`.
- 유일한 구조 변경은 Q→T, R→T, R→U 간선 추가다. 4노드·10간선·3관계, 특징 배치·공유 두 홉·전체 노드 readout·초기화·파라미터 수·공통 raw Critic은 v4 그대로다. 역방향 간선은 추론 문맥이며 물리 인과 주장이나 제어기가 아니다.
- 공통 10차원 관측·물리·센서·reward_v5·행동·종료·학습 분포·PPO 손실·학습률·탐색·예산·validation 규칙을 유지한다. NIS/공분산·보조 손실·단조 게이트는 이번 후보에 추가하지 않는다.
- Shuffled는 위상·self·유형별 수 2/4/4를 보존하고 의미 간선 6개 중 4개 유형을 바꾼다. 초기 함수·파라미터는 TOSM과 같고 관계별 기울기 공유만 다르다. 전역 이름 교환은 거부한다.
- 새 개발 421–425×네 방법 모두 새 학습, 12,000개 고정 평가. 이전 모든 방법 5/5 학습·세 양의 OOD 평균·motion/noise 성공/위험/오차 방향 게이트를 유지한다. 확인 431–440 및 환경 9101–9200은 개발 통과 후 별도 등록 전 닫는다. 미사용 391–400, 401–405, 411–420은 사용하지 않는다.
- 공개 `run_check`/`residual-v5`, `run`, `run_live`, `run_scenario`는 v5/421이다. v4 이하 검사와 체크포인트는 보관한다. 루트 MATLAB 파일은 기존 네 개만 유지한다.
- 실제 MATLAB 구조·전체 미분·PPO 기울기, 공개 네 방법 1 update, 보관 잔차 80개 모델·60개 미분과 minimal fixture, 기존 13+14+13 검사, 저장/복원·8개 라이브 재생, 실행 정적 검사까지 통과했다. v4/v5 PPO·Residual-MLP 1 update도 비트 단위로 같다. 소스 등록 직후 본 학습하며 단일 제어기가 전체 검산·검증 실패 재현까지 실행한다. TEST ONLY 검사를 성능 근거로 해석하지 않는다. 진행 중 등록 소스는 수정하지 않는다.
- 변경 전 262개 파일은 `results/archive/pre_residual_v5_20261026/`에 보존했다. 이전 결과·모델·스냅샷을 덮어쓰지 않는다.

---

# 보관 코드 유지 가이드 — relational_residual_v4 짝 개발 후보 (2026-10-26)

현재 계약은 `docs/RELATIONAL_RESIDUAL_V4_KO.md`다. 아래 v3 이하 계약은 보관 재현용이며 이 절이 우선한다. 목표 작업의 본 학습·평가 반복 승인은 계속 유효하다. 성능 우위는 아직 입증하지 못했다.

**v4 짝 개발 완료·미채택(2026-10-26):** 학습/평가·전체 검산·검증 실패 대상 확인의 세 실행 모두 종료 코드 0으로 완료됐다. 20개 모델·12,000개 평가·318개 등록 파일과 원본 스냅샷을 검산했다. 네 방법 모두 Reached80/선택 검증 80% 이상 5/5로 학습 기준은 통과했지만, OOD 평균 방향과 조건별 강인성 기준은 실패했다. PPO/Residual-MLP/TOSM/Shuffled OOD 착륙률은 95.40/95.73/95.53/96.73%이며 세 주 구간 모두 0을 포함한다. 새 개발 401–405와 확인 411–420은 열지 않았다. `results/relational_residual_v4/paired-development/closed_evidence.json` 이후의 다음 버전 작업은 허용되며 기존 모델·등록 소스는 보존한다. 현재 공개 기본은 v4 재현 경로이고 다음 후보는 아직 정하지 않았다. 목표는 계속 진행 중이다.

- v3의 학습/평가·전체 검산·검증 실패 재현을 모두 완료했다. 20개 모델·12,000개 평가·279개 등록 파일을 검산했고 세 개발 기준 모두 실패했다. 확인 391–400은 미실행이다. `results/relational_residual_v3/development/closed_evidence.json`에 종료 근거를 보존한다.
- v4 알고리즘 `relational-residual-v4.0`, 프로필/인코더 `relational_residual_v4`, 패키지 `landing2d.residual_base_init`. **유일한 알고리즘 변경은 기본 MLP 출력 가중치의 기존 fan-in Gaussian gain 0.1 복원**이다. 일반 PPO 마지막 W와 세 잔차 방법의 B2에 적용한다. R=0·bias·beta·은닉 특징·난수 소비·Critic·σ는 v3 그대로다.
- 세 잔차 초기 함수는 같고 TOSM/Shuffled의 관계별 기울기 공유 배치만 다르다. Plain PPO와 잔차 Actor는 폭이 달라 초기 함수가 정확히 같다는 주장은 하지 않는다. 초기화가 v3 실패 원인이었다고 미리 결론 내리지 않는다.
- 물리·센서·10차원 원 관측·reward_v5·행동·종료·학습 분포·PPO 손실·학습률·탐색·예산·validation 규칙·평가 조건 유지. `tosm4_motion_v1`, `masked_own_vx_v1`, 네 노드·7간선·두 홉·모든 노드 readout·공통 raw Critic 유지. 순전파/역전파는 보관 v3 함수를 공유한다.
- 파라미터 수 PPO 2,095, Residual-MLP 2,098, 그래프 두 방법 2,089. 새 입력·보조 손실·제어기·필터 없음. 네 방법 모두 새 학습이며 이전 PPO 서명과 호환 등록하지 않는다.
- **짝 개발 381–385×네 방법**, 단계 `paired-development`. 같은 12,000개 평가와 기존 세 개발 기준을 적용한다. 실패 시드 제외·재시작·예산 연장·기준 완화 금지. v3와의 짝 변화는 원인 분리용이며 확인 근거가 아니다.
- 짝 개발 통과 뒤에만 별도 등록한 새 개발 **401–405**, 그 뒤 같은 전체 기준 통과 시 미사용 확인 **411–420**을 검토한다. 현재 진입점은 짝 개발만 허용한다. 확인 환경 9101–9200과 alpha spending은 목표 문서 그대로다.
- 공개 기본 `run_check`/`residual-v4`, `run`, `run_live`, `run_scenario`는 v4/시드 381이다. 보관 v3 검사는 `run_check('residual-v3')`. 루트 MATLAB 파일 추가 금지.
- v4 초기화·실제 PPO 경로·공유 미분, 공개 네 방법 1 update, 보관 잔차 v1/v2/v3 60개 모델·45개 미분, minimal v3.1/v3.2, 기존 13+14+13 검사, 저장/복원·8개 라이브 재생을 실제 MATLAB에서 통과했다. 최종 실행/분석 정적 검사도 종료 코드 0이다. 소스·규칙·원자료 SHA-256 등록 후 본 학습하며, 위 구현 검사는 TEST ONLY다.
- 변경 전 252개 코드·문서는 `results/archive/pre_residual_v4_20261026/`에 보존한다. 이전 결과와 등록 스냅샷을 덮어쓰지 않는다. 실행 중 등록 소스는 수정하지 않는다.

---

# 보관 코드 유지 가이드 — relational_residual_v3 (2026-10-26)

현재 실행 계약은 `docs/RELATIONAL_RESIDUAL_V3_KO.md`다. 아래 v2·minimal 계약은 보관 재현용이며 새 후보에는 이 절이 우선한다. 사용자의 목표 작업에 대한 본 학습·평가 반복 승인은 계속 유효하다. 성능 우위는 아직 입증하지 못했다.

**v3 개발 완료·미채택:** 학습/평가·전체 검산·검증 실패 재현 세 실행 모두 종료 코드 0으로 완료했다. 20개 모델·12,000개 평가·279개 등록 파일을 검산했다. OOD 착륙률 PPO 59.07%, Residual-MLP 98.20%, TOSM 96.20%, Shuffled 76.40%; 세 개발 기준 모두 실패, 확인 391–400 미실행. PPO 383·385와 Shuffled 384의 원래 검증 60개도 재현했다. 현재 공개 기본은 보관 v3이며 다음 초기화 분리 후보를 준비한다. `development/closed_evidence.json` 이후의 새 버전 작업은 허용되며, 완료된 등록 소스 스냅샷은 보존한다.

- v2 개발 20개 모델·12,000개 평가·260개 등록 파일을 검산했고 개발 기준 세 가지 모두 실패했다. TOSM OOD 96.40%, PPO 97.93%, Residual-MLP 77.53%, Shuffled 95.47%; 세 주 구간 모두 0 포함. 확인 371–380은 미실행이다. 원자료·실패 분석·등록 소스는 `results/relational_residual_v2/`에 보존한다.
- 현재 알고리즘 `relational-residual-v3.0`, 프로필/인코더 `relational_residual_v3`, 패키지 `landing2d.residual_motion`. 기본 raw MLP + 행동 평균 관계 잔차 + 공통 raw Critic의 v2 큰 틀·폭·파라미터 수 유지.
- 공통 10차원 관측·물리·센서·reward_v5·행동·종료·PPO 손실·학습 분포·예산·validation 선택/종료·평가 조건은 유지한다. 추가 NIS/공분산·보조 손실·안전 제어 없음.
- 보정 분기의 `masked_own_vx_v1`은 기존 o3/o4에서 동일 속도 척도의 드론 수평속도를 안정적인 유리식으로 복원한다. 초기 미가용 0 마스크는 유지하며, 정확한 포화로 분모 0이면 0 자리표시자/0 미분을 쓴다. 실제 숨은 속도를 읽지 않는다. 기본 MLP·Critic·PPO는 원 관측을 유지하고 Residual-MLP와 두 그래프 보정은 같은 변환을 쓴다.
- `tosm4_motion_v1`: Quality u9–10, Target u4, Own u3/u5–8, Relative u1–2. 네 노드·7간선·관계 공유·두 홉·모든 노드 readout은 v2와 같다. Shuffled는 의미 간선 2/3 교란, self·위상·관계 수 보존.
- 네 방법 모두 초기 행동 평균 0: PPO 마지막 W, 잔차 B2/R을 0으로 두고 무작위 은닉 특징·기존 난수 소비·σ·Critic은 유지한다. 첫 minibatch 뒤 내부 기울기가 활성화되는지 검사한다. 새 PPO 초기화이므로 이전 PPO 경로와 호환 등록/재사용하지 않는다.
- 새 개발 **381–385×네 방법**, 전부 새 학습. 고정 12,000개 평가, 모든 방법 Reached80·선택 검증 80% 이상 5/5, 세 OOD 평균 양의 방향, 기존 motion/noise 강인성 조건 유지. 실패 시드 제외·예산 연장·기준 완화 금지.
- 확인 **391–400** 및 환경 9101–9200은 별도 등록 전 닫는다. 개발·smoke만으로 목표 완료나 일반화 우위를 주장하지 않는다. 확인 통계·alpha spending은 목표 문서와 같다.
- 공개 기본 `run_check`/`residual-v3`, `run` 및 `run_live`/`run_scenario`는 v3/시드 381이다. `run_check('residual-v2')`·`('residual-v1')`로 보관 검사를 유지한다. 루트 MATLAB 파일 추가 금지.
- 실제 MATLAB 구조·전체 미분·PPO 기울기·공통 초기 분포와 네 방법 1 update smoke를 통과했다. 전체 회귀·저장/재생 검증 완료 후 최종 소스를 등록하고 본 학습한다. 검사 결과는 TEST ONLY다. 실행 중 등록 파일을 수정하지 않는다.

---

# 보관 코드 유지 가이드 — relational_residual_v2 (2026-10-26)

사용자의 첨부 설계안을 반영한 현재 실행 계약은 `docs/RELATIONAL_RESIDUAL_V2_KO.md`다. 아래 minimal v3 계약은 보관 재현용이며, 새 잔차 후보에는 이 절이 우선한다. 구현 검증을 통과했지만 일반화 성능 우위는 아직 입증되지 않았다.

**v1 개발 완료:** 시드 341–345의 20개 모델·12,000개 평가·235개 등록 파일을 검산했고 개발 성능 기준에 실패했다. OOD 착륙률은 PPO 95.27%, Residual-MLP 78.33%, TOSM 77.73%, Shuffled 95.33%였다. 모든 결과는 `results/relational_residual_v1/`, 변경 전 240개 파일은 `results/archive/pre_residual_v2_20261026/`에 보존한다. 확인 351–360은 미사용이다.

**현재 후보:** `relational-residual-v2.0`, 인코더 `relational_residual_v2`, 패키지 `landing2d.residual_logits`. 행동 평균에 기본 MLP와 관계 보정을 직접 더한다. 공개 `run_check`, 전체 미분·PPO·회귀·저장/재생 검증을 실제 MATLAB에서 통과했다. 본 학습 전 최종 코드·문서·검사·실행 스크립트의 SHA-256을 등록한다.

- 기존 2D 물리·센서·10차원 관측·reward_v5·행동·종료·PPO 손실·분포·예산·validation 선택/plateau 규칙 유지.
- 네 비교군: PPO, Residual-MLP PPO, TOSM residual PPO, Shuffled residual PPO. `config.methodRegistry(c)`가 버전별 단일 등록 창구다. 인자 없는 호출은 보관 세 방법을 반환한다.
- 공통 벡터 Critic 10→55→1. 잔차 Actor는 `10→74→2 base + sigmoid(beta)×tanh(correction)`이며 beta 초기값 −2. LayerNorm과 공통 특징 head는 없다. 완성된 2차원 평균을 인코더가 반환하며 MLP head는 파라미터 없는 항등 어댑터다.
- 그래프는 기존 4노드·7간선, 노드별 사영 폭 8, H0 증거를 보존하는 두 홉 공유 동적 attention, 네 노드 전체 readout 32→2. MLP 보정은 10→36→2. 마지막 층 초기화 gain은 0.1이다.
- 총 파라미터: PPO 2,095, Residual-MLP 2,098, 두 그래프 각각 2,089(차이 0.44% 미만). 사용하지 않는 파라미터로 수를 채우지 않는다. 네 방법 모두 새로 학습하며 기존 PPO를 재사용하지 않는다.
- Actor 전체 기울기를 함께 clip하고 학습률 2e−4를 적용한다. Critic은 5e−4. 특정 방법 전용 보상·손실·입력 필터·안전 감독기는 없다.
- 추가 NIS/공분산 입력·단조 신뢰도 감쇠·own-vx 재구성·동역학 보조 손실은 넣지 않는다. 관측 가능성 검사는 보존 자료이며 성능 증거가 아니다.
- 관계 교란은 self·위상·유형 개수를 보존하고 의미 간선 2/3개를 바꾼다. 초기 그래프 함수는 같고 파라미터 공유 묶음이 달라진다. 전역 관계 이름 교환은 대조군으로 인정하지 않는다.
- 새 개발 361–365×네 방법, 고정 평가 12,000개. 모든 방법이 Reached80·선택 검증 80% 이상 5/5여야 한다. 기존 세 OOD 평균 차이 및 motion/noise 강인성 방향 기준을 유지한다. 확인 371–380과 환경 9101–9200은 별도 등록 전 닫혀 있다. 출력은 `results/relational_residual_v2/`다.
- `run_check` 또는 `run_check('residual-v2')`는 현재 구조·실제 PPO·네 방법 1 update smoke다. `('residual-v1')`은 v1, `('smoke')`/`('contracts')`는 v3.1, `('legacy')`는 v2, `('trace',...)`는 보관 7노드 검사다. 실제 실행 없이 통과를 주장하지 않는다.
- `run_scenario`/`run_live` 기본 학습 시드는 361이며 S1–S3와 네 방법을 사용한다. 기존 7노드 trace에 연결하지 않는다.
- 목표 작업의 본 학습·평가 반복은 이미 사용자에게 승인받았다. 실패 결과·모든 시드·모델·등록 소스를 보존하고 test/OOD로 체크포인트를 선택하지 않는다. 개발이나 smoke만으로 목표를 완료하지 않는다.
- 진행 중 등록된 학습이 읽는 파일은 수정하지 않는다. 후속 후보는 별도 namespace나 검증 프로세스 전용 overlay로 준비한다.

---

# 코드 유지 가이드 — minimal_relational_v3.1 (2026-10-24)

사용자 요청: 기존 2D 물리·센서는 유지하고 연구 구조를 단순화한다. 이 문서가 현재 실행 계약이다. 이전 v2 계약·결과 이력은 [보관본](docs/archive/AGENTS_V2_20261024.md)에 있으며 현재 4노드 구조에 적용하지 않는다.

## 현재 경로

- **진행 중 목표(2026-10-25):** 사용자의 최신 지시 “목표 만들어서 그거 해결할 때까지 수정해줘”에 따라 수정·필요한 본 학습·평가를 반복하는 목표를 생성했다. 이 목표 작업에서는 아래의 이전 일회성 학습 제한을 대신해 반복 실행을 허용한다. 2D 물리·센서·공통 관측·보상·PPO 손실·공정한 비교와 결과 보존 계약은 유지한다. 세부 완료 기준과 개발/확인 분리는 `docs/GENERALIZATION_GOAL_KO.md`를 따른다. 결과가 부족하면 목표를 완료로 표시하지 않는다.
- 개요 `docs/MINIMAL_SYSTEM_KO.md`, 온톨로지·수식 `docs/TOSM4_ONTOLOGY_KO.md`, 귀납적 편향·업데이트 `docs/INDUCTIVE_BIAS_KO.md`, 실험·주장 `docs/EXPERIMENT_DESIGN_KO.md`.
- **v3.2 개발 완료·미채택(2026-10-25):** H0 증거를 유지하는 `rgat_minimal_v3`는 짝 개발 271–275에서 게이트를 통과했지만, 새 개발 291–295에서는 TOSM 4/5만 학습했다(PPO·Shuffled 5/5). 15개 모델·9,000개 평가의 OOD 착륙률은 PPO 98.07%, TOSM 78.60%, Shuffled 96.33%; 두 주 비교 구간 모두 0 포함. 등록 소스 191개·모델 15개·전체 평가·통계 검산을 통과했으나 성능 기준은 실패했다. 확인 301–310은 열지 않았다. 원자료는 `results/minimal_v32/`, 해석은 `docs/GENERALIZATION_GOAL_KO.md`에 보존한다.
- **v3.3 개발 후보(2026-10-25):** `minimal.config(root,'v33')`, `rgat_minimal_v3`, `minimal-relational-v3.3`, `relationInitialization='shared_semantic_v1'`. 두 의미 관계의 초기 W만 `(U1+U2)/sqrt(2)`로 같게 둔다. 학습 파라미터는 별개이며 self·root·사영·head·난수 소비 순서·PPO·그래프·관측·1,419개 예산은 유지한다. 두 그래프 방법의 초기 함수는 같고 관계별 기울기 공유 배치만 다르다. 짝 개발 291–295, 새 개발 311–315, 미사용 확인 예약 321–330. 본 학습 전 게이트는 목표 문서에 고정했다. 실제 MATLAB 사전 검증 전체가 통과했으며(`check_v33.log`), 소스 등록 후 두 그래프 방법 10개의 짝 개발을 진행한다. 기본 실행 버전은 v3.1로 유지한다.
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
run_check                         % 최소 구조 13검사 + 세 비교군 1 update smoke + 평가·그림
run_check('contracts')            % 최소 구조 13검사만
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
