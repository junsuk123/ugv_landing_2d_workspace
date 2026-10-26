# 행동 평균에 직접 결합하는 관계 잔차 v2 (2026-10-26)

현재 기본 실행 버전은 `relational-residual-v2.0`, 인코더는 `relational_residual_v2`다. 구현·미분·실제 PPO·저장/재생 검증을 마친 개발 후보이며, 일반화 우위를 입증한 버전은 아니다. 기존 2D 물리·센서·10차원 관측·reward_v5·행동·종료·PPO 손실·학습 분포와 예산을 유지한다.

## 변경 근거

[v1 전체 결과](RELATIONAL_RESIDUAL_V1_KO.md)는 20개 모델과 12,000개 평가를 검산했으나 개발 기준에 실패했다. OOD 착륙률은 PPO 95.27%, Residual-MLP 78.33%, TOSM 77.73%, Shuffled 95.33%였다. TOSM과 Residual-MLP의 같은 학습 시드 343이 ID·OOD 모두 0%였고, Shuffled도 같은 시드에서 늦게 수렴했다.

v1의 원 관측 경로는 `10→16 base→LayerNorm→16→2`를 통과했다. v2는 기본 MLP가 행동 평균까지 직접 연결되도록 바꾼다. 기본 폭과 결합 위치를 함께 바꾸므로, 결과만으로 LayerNorm 하나가 실패 원인이라고 결론짓지 않는다. 성공 시드만 남기거나 실패 시드의 예산을 늘리지 않는다.

## 수식과 구현

공통 센서 관측을 \(o\in\mathbb R^{10}\)이라 할 때,

\[
\mu_b(o)=B_2\tanh(B_1o+b_1)+b_2,\qquad
c(o)=\tanh(R e(o)+b_r),
\]
\[
\boxed{\mu(o)=\mu_b(o)+\rho c(o)},\qquad
\rho=\operatorname{sigmoid}(\beta_c),\quad \beta_{c,0}=-2.
\]

기본 정책은 10→74→2다. 그래프 보정의 \(e(o)\)는 네 노드의 두 번째 홉 상태를 연결한 32차원 값이다. 노드별 입력 사영 폭 8, H0를 보존하는 두 홉 공유 동적 attention, root·self·의미 관계 가중치는 v1과 같다. readout은 32→2이며 마지막 층 초기화 gain은 0.1이다. MLP 보정은 10→36→2, 마지막 보정에 같은 tanh와 \(\rho\)를 사용한다.

기본 경로에는 LayerNorm이나 공통 특징 head가 없다. 코드의 인코더가 완성된 2차원 Gaussian 평균을 반환하고, 기존 MLP head 인터페이스는 층과 파라미터가 없는 항등 함수다. 학습하지 않는 가짜 파라미터로 용량을 채우지 않는다.

보정 readout을 0으로 두면 \(\mu=\mu_b\)가 정확히 성립한다. 고정된 상류 미분에서 기본 MLP의 미분도 그대로다. 학습 중 방문 상태·advantage·상류 기울기까지 일반 PPO와 같다는 의미는 아니다. 이 구조도 학습 안정성이나 일반화 개선을 자동 보장하지 않는다.

## 온톨로지와 귀납적 편향

| 노드 | 공통 관측 인덱스 | 내용 |
|---|---|---|
| ObservationQuality | 9–10 | 갱신 여부·관측 나이 |
| TargetMotion | 4 | 추정 UGV 수평속도 |
| OwnMotion | 5–8 | 수직속도·sinθ·cosθ·pitch rate |
| RelativeState | 1–3 | 상대 수평위치·높이·상대 수평속도 |

Quality→Relative의 `qualifiesEstimate`, Target/Own→Relative의 `informsMotion`, 네 self 간선으로 총 7개다. 같은 관계의 간선은 \(W_r\)를 공유한다. 두 홉에서도 파라미터를 공유한다. 허용 경로와 공유 묶음이 귀납적 편향이며 별도 편향 점수는 계산하지 않는다.

그래프 파라미터 \(\theta_g\)는 공통 PPO 기울기를 받는다.

\[
\frac{\partial L}{\partial\theta_g}
=\frac{\partial L}{\partial\mu}\,
\rho\,\operatorname{diag}(1-c^2)R\,
\frac{\partial e}{\partial\theta_g}.
\]

관계 구조 자체를 학습하는 것은 아니다. attention이나 기울기 크기를 인과적 중요도·신뢰도 점수로 해석하지 않는다. `OwnMotion`에 수평속도를 재구성하거나 NIS·공분산·동역학 보조 손실을 추가하지 않는다. 이들 제안의 별도 관측 가능성 검사는 보존하되 이번 후보의 원인을 함께 섞지 않는다.

## 비교 조건

| 방법 | Actor | 공통 Critic | 총 파라미터 |
|---|---|---|---:|
| PPO | 10→110→2 | 10→55→1 | 2,095 |
| Residual-MLP PPO | 기본 MLP + MLP 보정 | 동일 | 2,098 |
| TOSM residual PPO | 기본 MLP + 관계 보정 | 동일 | 2,089 |
| Shuffled residual PPO | 기본 MLP + 교란 관계 보정 | 동일 | 2,089 |

표에는 행동 logσ 두 개가 포함된다. 용량 차이는 0.44% 미만이다. 세 잔차 방법의 기본 MLP 초기값과 네 방법의 Critic 초기값은 각각 같다. Actor 전체에 동일한 기울기 clipping과 학습률 2e−4, Critic에 5e−4를 적용한다. 보상·손실·추가 입력·안전 제어·필터를 특정 방법에만 주지 않는다.

Shuffled는 위상·self·관계 수를 유지하며 의미 간선 2/3개의 유형을 바꾼다. 의미 행렬의 초기값은 같되 별개로 학습한다. 따라서 초기 TOSM/Shuffled 함수는 같고, 어떤 간선의 기울기가 같은 행렬로 모이는지가 달라진다. 단순한 전역 관계 이름 교환은 대조군이 아니다.

## 개발·확인 계약

- 개발 시드 **361–365×네 방법**, 모두 새로 학습한다. 750 update×6 episode 상한, 공통 validation screen·25 update 검증·plateau 종료를 유지한다. 체크포인트는 validation만 사용한다.
- 고정 가속·누락·잡음 ID/OOD 여섯 셀을 방법·학습 시드마다 100개씩 평가한다. 개발 환경 9001–9100, 총 12,000개다. 수치 범위·사건 시각·실패 분류·주 지표는 v1과 같다.
- 학습 안정성은 **네 방법 각각** 검증 80% 도달과 선택 모델 80% 이상이 모두 5/5여야 한다. TOSM 검증 중앙값·위험 접촉 중앙값의 기존 5%p/2%p 조건도 유지한다.
- 다음 확인 단계 진입에는 TOSM−PPO, TOSM−Residual-MLP, TOSM−Shuffled의 OOD 평균 차이가 모두 양수여야 한다. motion·noise의 착륙률은 낮지 않고, 위험 접촉·aim RMS 평균은 높지 않아야 한다. 이는 개발 방향 판정이며 통계적 우월성·비열등성 판정이 아니다.
- 분석 단위는 학습 시드이고 비교는 시드별 짝 차이다. 개발의 세 주 비교는 개별 98.3333% 구간을 보고한다. 실패 시드와 전체 구간을 보존한다.
- 확인 371–380과 환경 9101–9200은 별도 등록 전 닫혀 있다. 처음 확인을 열 때 family alpha=.025/세 비교, 개별 99.1667% 구간을 사용하며 세 하한 모두 0보다 커야 목표의 우위를 주장한다. 성능·안전·추종의 조건별 결과도 함께 검토한다. 이전 확인 예약 351–360은 미사용이다.

## 실제 검증과 실행

공개 `run_check`의 네 방법 1 update와 인코더 전체 파라미터·입력 미분, 실제 clipped PPO 미분을 통과했다. 최대 수치 미분 오차는 인코더 3.2e−11 미만, PPO 1.4e−10 미만이다. v1의 20개 기존 모델 출력·초기값과 15개 인코더 미분, v3.1/v3.2 기준 자료가 비트 단위로 같았다. 기존 최소 13개·보관 14개·trace 13개 검사, 네 저장/복원, 여덟 라이브 재생, 네 통제 사례 비행도 통과했다. PPO 1 update 모델과 시간 제외 이력은 v1과 정확히 같다.

근거는 `results/goal_generalization_20261025/residual_v2_public_check.mat`와 `residual_v2_integration_checks.mat`다. 초기 검산 도구의 경로 구분자 불일치와 정적 검사 경고를 고친 기록도 `residual_v2_integration_checks*.log`에 보존했다. 모든 사전 검증은 **TEST ONLY**이며 성능 근거가 아니다.

```matlab
run_check                       % 현재 v2 구조·PPO 체인·네 방법 1 update
run_check('residual-v1')         % 완료된 v1 재현용 검사
run                             % v2 새 개발 361–365, 네 비교군
run_scenario('S2')               % v2 체크포인트가 생성된 뒤
run_live('S3',struct('trainSeeds',361,'replicates',10))
```

본 실행은 코드·문서·사전 검사·스크립트를 SHA-256으로 등록한 뒤 시작한다. 출력은 `results/relational_residual_v2/`이며 이전 결과를 덮어쓰지 않는다. 파이프라인은 `landing2d.residual_logits.runPipeline`, 등록 스크립트는 `results/goal_generalization_20261025/train_residual_v2_dev.m`다.

## 개발 완료: 기준 실패 (2026-10-26)

20개 모델·12,000개 평가·120개 셀·260개 등록 파일과 시드별 짝 통계를 실제 MATLAB에서 검산했다. 실행과 사후 검산은 정상 종료했지만, 학습 안정성·OOD 방향·조건별 강인성 기준은 모두 실패했다. 확인 371–380은 열지 않았다.

| 방법 | 검증 80% 도달/선택 | learning AUC | OOD 착륙 | OOD 위험 접촉 | OOD aim RMS(m) |
|---|---:|---:|---:|---:|---:|
| PPO | 5/5 | 0.731867 | 97.933% | 0.800% | 0.626131 |
| Residual-MLP | 4/5 | 0.623733 | 77.533% | 1.400% | 3.123616 |
| TOSM | 5/5 | 0.795133 | 96.400% | 0.600% | 0.614281 |
| Shuffled | 5/5 | 0.843967 | 95.467% | 1.400% | 0.706871 |

세 주 비교의 개별 98.3333% 구간은 TOSM−PPO −1.533%p [−8.036, 4.970], TOSM−Shuffled +0.933%p [−11.518, 13.384], TOSM−Residual-MLP +18.867%p [−60.792, 98.525]다. 모두 0을 포함하므로 우위를 입증하지 못했다. 서로 다른 개발 시드를 쓴 v1과의 수치 차이를 구조 변경의 인과 효과로 해석하지 않는다.

TOSM의 가속/누락/잡음 OOD 착륙률은 93.4/97.8/98.0%, PPO는 97.2/99.4/97.2%였다. 가속에서 TOSM의 위험 접촉은 낮지만(1.6% 대 2.2%), 시야 이탈 3.2%와 공중 정지 시간 초과 1.8%가 남았고 aim RMS는 1.111m 대 1.077m였다. 잡음의 작은 평균 이점만으로 전체 목표를 달성했다고 판단하지 않는다.

Residual-MLP 시드 361은 750 update 내내 검증 착륙률 0%였다. 선택 update 675의 검증 20개를 그대로 재생해 기록된 결과율·평균 return을 재현했다. 시야 이탈 16개, 재획득 실패 2개, 추종 시간 초과 2개이며 평균 aim RMS는 8.928m다. 이 시드와 모든 실패 에피소드를 포함했다. 특정 초기화나 층 하나를 유일 원인으로 입증한 결과는 아니다.

근거: `results/relational_residual_v2/development/review.json`, `learning_review/`, `failure_review/`, `validation_failure_s361_mlp/` 및 `generalization_v1/development/s361-362-363-364-365/`. 일반화·평균 학습·전체 시드 학습 그림도 직접 확인했다. 학습 당시 소스는 `development/registered_source/`에 보존하며, 이후 문서 보충본과 등록 SHA-256은 구분한다.
