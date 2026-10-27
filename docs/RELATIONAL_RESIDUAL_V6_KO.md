# 일반화 목표 재개 — 후보 C1: 관계 대칭 비포화 잔차 (relational_residual_v6, 2026-10-27)

## 재개 근거와 범위

2026-10-27 사용자가 "이제 내 목표 달성하게 알고리즘 수정해줘"라고 지시했고, 다음 두 가지를 선택했다.
- **목표:** 기존 일반화 목표 재개
- **권한:** 등록된 개발 기준을 통과하면 확인 실험까지 자율로 진행

[목표 문서](GENERALIZATION_GOAL_KO.md)의 완료 판정을 그대로 따른다. 확인 실험에서 TOSM−PPO와 TOSM−Shuffled의 동등 가중 OOD 착륙률 짝 차이의 보정 구간 하한이 모두 0보다 커야 한다. 조건별 위험 접촉과 추종 오차도 악화되지 않아야 한다. [목표 종료 문서](GENERALIZATION_GOAL_CLOSURE_KO.md)의 이전 결과는 보존한다.

달성은 보장되지 않는다. 실패하면 실패로 보고한다.

## 후보와 메커니즘 (Codex 판단, GO)

진단 근거는 [귀납 편향 진단](INDUCTIVE_BIAS_DIAGNOSTICS_KO.md), [이득 감사](CONTROL_GAIN_AUDIT_KO.md), [R1](ACCELERATION_RANGE_R1_KO.md), [D1](RESPONSE_GAIN_R1_KO.md), [H3 게이트](UGV_ACCEL_H3_GATE_KO.md)다. 네 방법에 공통인 과소 반응이 있고 잔차 혼합 계수는 작다(σ(β) ≈ 0.13). 그래서 보정 경로의 응답 제한을 완화하면 어떻게 되는지 시험한다. "tanh 포화가 실패 원인"이라는 주장은 하지 않는다.

**유일한 변경:** 세 잔차 방법(Residual-MLP·TOSM·Shuffled)의 보정 경로 활성 함수를 바꾼다.

φ(z) = 0.9·tanh(z) + 0.1·z,  φ'(z) = 0.9(1 − tanh²z) + 0.1 ≥ 0.1

- 그래프 방법은 노드 입력 사영, 매 홉 노드 갱신, 최종 보정에 적용한다. Residual-MLP는 보정 은닉층과 최종 보정에 적용한다.
- 계수 0.1은 고정하고 탐색하지 않는다.
- 모든 관계에 같은 연산을 적용한다. 관계별 파라미터 공유만 다르다. informsMotion에만 선형 통로를 주거나 qualifiesEstimate에만 감쇠를 강제하지 않는다.
- 기본 MLP(tanh), 공통 raw Critic, attention 수식, 행동 tanh, 관측 변환, 초기화(R = 0, β = −2)는 v5와 같다.
- 파라미터 수는 PPO/Residual-MLP/TOSM/Shuffled 각각 2095/2098/2089/2089다. PPO는 바꾸지 않는다.
- 물리·센서·10차원 관측·reward_v5·행동·종료·PPO 손실·학습 분포(v5 a2 0.3–0.8)·학습률·탐색·750×6 상한·validation 규칙은 고정이다.
- 구현:
  - `landing2d.residual_motion.correctionActivation`
  - `residual_motion.encoderForward`·`encoderBackward`: 활성 함수의 기울기를 캐시해서 쓴다. tanh 경로는 기존과 같은 식이다.
  - `graphState.correctionActivation = 'soft_linear_v1'`
  - 알고리즘 버전 `relational-residual-v6.0`, 패키지 `landing2d.residual_soft`, 출력 `results/relational_residual_v6/`

예상 실패 양상은 잡음 증폭, 학습 불안정, 작은 혼합 계수의 지속, 관계 타입의 상호 대체다. 원 관측의 softsign 압축은 남아 있으므로 선형 응답이나 충분한 이득을 보장하지 않는다.

## 개발 (프로토콜 v2)

- **학습:** 451–455 × 네 방법, 모두 새로 학습한다(시드 미사용 감사 통과: 결과 CSV 672개·체크포인트 259개).
- **평가:** 가속 1.5–2.0 m/s², 누락 2.1–2.9 s, 잡음 ×3. 환경 9001–9100, 6셀 × 100회 × 20모델 = 12,000회다.
- **개발 기준(v5 `developmentGate` 규칙):**
  - 네 방법 모두 Reached80과 선택 validation ≥ 80%가 5/5다.
  - TOSM의 validation 중앙값이 PPO·MLP − 5%p 이상이고, 위험 접촉 중앙값이 +2%p 이하다.
  - TOSM−PPO, TOSM−MLP, TOSM−Shuffled의 OOD 평균 차이가 모두 양수다.
  - motion·noise 각각에서 세 비교군 대비 착륙률이 낮지 않고, 위험 접촉·aim RMS가 크지 않다(허용 오차 1e−12).
  - 세 개별 98.3333% 짝 t 구간(df = 4)은 보고만 하고 게이트로 쓰지 않는다.

## 확인 (개발 통과 시에만, 별도 등록 뒤)

- 431–450 × 네 방법을 새로 학습한다. 체크포인트는 validation으로만 선택하고, 평가 전에 잠근다.
- 환경 9101–9200의 v2 6셀에서 80모델 × 600회 = 48,000회를 평가한다.
- 확인 회차 j = 1이고 alpha = 0.05/2 = 0.025다. 세 비교에 Bonferroni를 적용해 개별 양측 99.1667% 짝 t 구간(df = 19)을 쓴다.
- **목표 달성 조건:** 다음을 모두 충족해야 한다.
  - TOSM−PPO와 TOSM−Shuffled의 하한이 모두 0보다 크다.
  - motion·noise의 착륙·위험·추종 평균이 PPO·Shuffled보다 악화되지 않는다.
  - 전체 검산을 통과한다.
- Residual-MLP 비교도 같은 구간으로 보고한다. 실패 시드를 포함한 20쌍 전체를 쓴다.

## 예산과 중단 규칙

- 후보는 최대 두 개다. C1(451–455)이 개발에 실패하면 C2(461–465: 기본 MLP 폭 74→42, 그래프 폭 8→12, Residual-MLP 보정 폭 36→68)를 실행한다.
- 처음 개발을 통과한 후보만 확인 1회로 보낸다.
- 두 개발이 모두 실패하거나 확인이 실패하면 "등록 예산 내 목표 미달성"으로 종료한다.
- 시드 제외·재학습·예산 연장·기준 완화·확인 표본 재사용은 하지 않는다.
- 관측·센서·보상·PPO 목적·학습 분포 변경, 평가 재보정, 후보·예산 확대, 추가 확인 회차는 사용자 승인이 필요하다.

## 학습 전 검사 (TEST ONLY)

- **`landing2d.residual_soft.selfTest`:**
  - v5와의 설정 차이는 활성 함수뿐이다.
  - 초기 모델 20개가 v5와 같고, 파라미터 수와 초기 잔차 평균이 일치한다.
  - φ와 그 기울기를 유한차분으로 확인했다.
  - 그래프·MLP 보정의 전체 파라미터·입력 유한차분과 배치 일치를 확인했다.
  - 실제 PPO 손실 기울기를 전체 인코더 파라미터에 대해 확인했다.
  - Shuffled는 이름이 아니라 공유 구조를 바꾼다.
  - 첫 업데이트 뒤 내부 학습이 활성화된다.
  - 저장·복원과 결정적 재현이 된다.
- **v5 회귀:** 관측 시퀀스와 네 방법 1 update가 비트 단위로 같다. v5 selfTest 미분 오차는 약 1e−10이다.
- **보관 검사:** run_check의 residual-v5…v1, contracts, legacy, trace를 실행했다. 결과는 `results/relational_residual_v6/prechecks/`에 있다.
- **smoke:** 개발 실행 경로 전체를 smoke로 실행한다.
- **등록:** 학습 전에 모든 소스와 이 문서의 SHA-256을 `development/registration.json`에 등록한다. 실행 중에는 등록 소스를 수정하지 않는다.

## 주장 범위

- 개발 통과, 응답 증가, 관계 민감도 증가만으로 일반화 우위를 주장하지 않는다.
- 평균 비악화는 통계적 비열등성의 증명이 아니다.
- 실패 시드와 조건별 구간을 모두 공개한다.

## 결과 — 개발 실패, 미채택 (2026-10-27)

**판정:** 학습 기준은 통과했지만 OOD 평균 방향과 motion·noise 강인성 기준은 실패했다. 확인(431–450, 9101–9200)은 열지 않았다. Codex 판정은 GO(C1 실패 확정, 등록 정의 그대로 C2 진행)였다([decisionP.yaml](../results/relational_residual_v6/post_hoc/decisionP.yaml)).

**실행과 검산**
- 실행: WMI 분리 실행 1회, 종료 코드 0, 2026-10-27 00:30–03:04. 20모델을 새로 학습했고 12,000회를 평가했다.
- 소스·체크포인트: 등록 소스 296개가 학습 전·학습 후·평가 후·종료 후 모두 해시와 일치했다. 체크포인트 20개도 manifest와 일치했다.
- 출력 해시 예외: 출력 20개 중 `execution.json` 1개가 다르다. 출력 해시를 수집한 뒤 phase를 complete로 다시 쓰는 기록 순서 결함이다. 내용은 시작·종료 시각뿐이다. 최종 해시는 [closed_evidence.json](../results/relational_residual_v6/development/closed_evidence.json)에 남겼다. 전체 출력 해시 일치로 보고하지 않는다.
- 독립 재계산: 원 episode CSV에서 Python으로 다시 계산했다([recompute_v6_dev.py](../results/relational_residual_v6/post_hoc/recompute_v6_dev.py)). 120셀×100회와 방법 간 시드 짝을 확인했고, MATLAB 결과와 약 1e−15 수준으로 일치했다.
- 그림 두 장을 직접 확인했다.

**학습:** 네 방법 모두 Reached80과 선택 validation ≥ 80%가 5/5다. validation 중앙값은 PPO/MLP/TOSM/Shuffled 1.00/1.00/0.99/1.00이다.

**OOD 착륙률과 주 대비**

| 지표 | PPO | Residual-MLP | TOSM | Shuffled |
|---|---|---|---|---|
| OOD 동등 가중 착륙률 | 91.27 | 90.33 | 88.67 | 88.87 |

| 대비 | 평균 차이 | 98.3333% 짝 t 구간 (df = 4, 보고용) |
|---|---|---|
| TOSM−Shuffled | −0.20%p | [−18.42, 18.02] |
| TOSM−PPO | −2.60%p | [−18.51, 13.31] |
| TOSM−MLP | −1.67%p | [−21.47, 18.13] |

시드별 TOSM−Shuffled는 −14.67, +13.67, −3.67, +2.67, +1.00%p로 부호가 불안정하다.

**강인성 (OOD 평균)**

| 조건 | 지표 | PPO | Residual-MLP | TOSM | Shuffled |
|---|---|---|---|---|---|
| motion | 착륙 (%) | 79.4 | 80.0 | 74.8 | 78.6 |
| motion | 위험 접촉 (%) | 7.4 | 11.6 | 18.8 | 11.2 |
| motion | aim RMS (m) | 2.16 | 2.54 | 1.84 | 2.41 |
| noise | 착륙 (%) | 97.0 | 93.8 | 94.8 | 92.6 |
| noise | 위험 접촉 (%) | 1.4 | 3.4 | 3.8 | 4.4 |
| noise | aim RMS (m) | 0.435 | 0.416 | 0.673 | 0.466 |

TOSM의 motion 최악 시드(451)는 착륙률 45%다.

**사후 기술 분석 (학습 없음, 원인 단정 없음)**

이미 연 개발 환경 9001–9010의 motion OOD에서 결정적 rollout을 했다. 자료는 [post_hoc](../results/relational_residual_v6/post_hoc/)에 있다.
- 혼합 계수: 학습 후 σ(β)는 v5 0.139/0.135/0.135, C1 0.142/0.135/0.134(MLP/TOSM/Shuffled)다. 초기값은 0.119다. 예상 실패 양상 중 "작은 혼합 계수의 지속"이 관찰됐다.
- 행동 크기: pre-tanh 행동 평균의 크기는 |base| 0.065–0.073이다.
- 보정 크기: |σφ| 평균은 v5 0.008/0.014/0.014에서 C1 0.012/0.017/0.020으로 늘었다. 최대값은 0.03–0.06으로 σ(β)에 미치지 않는다. 다만 φ는 비유계이므로 σ(β)가 절대 상한은 아니다. 이 비교만으로 내부 포화나 기울기 병목을 배제할 수 없다.
- 시드가 다르므로 v5와 C1은 서술 비교만 한다.

다음 단계는 등록된 C2([RELATIONAL_RESIDUAL_V7_KO.md](RELATIONAL_RESIDUAL_V7_KO.md))다. C1 등록 소스는 `results/archive/pre_residual_v7_20261027/`에 보존했다.
