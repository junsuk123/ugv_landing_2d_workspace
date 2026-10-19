# 관계 기반 정책 표현의 유효성 검증 — 이동 UGV 자율 착륙 (2D, MATLAB)

2차원 $x$–$z$ 환경에서 세 PPO 정책을 비교한다. 드론은 등속 또는 가속하는 UGV 위 패드에 착륙한다.
세 정책은 같은 12차원 관측, 같은 보상, 같은 PPO 손실·예산·파라미터 수(6,101)를 쓰고 **Actor/Critic 상태 표현만 다르다**.

| id | 상태 표현 |
|---|---|
| `ppo` | 12차원 공통 관측 $o_t$ → MLP |
| `onto_rgat_ppo` | 같은 $o_t$의 TOSM 7노드 그래프 → 입력 의존 attention R-GAT → MLP |
| `shuffled_rgat_ppo` | 위와 같고 의미 관계 유형만 고정 순열로 교란 (대조군) |

일반 PPO도 관계를 암묵적으로 배울 수 있다. 그래서 질문은 "R-GAT가 더 많은 것을 표현하는가"가 아니다. 질문은 "올바른 관계 구조라는 사전지식이 **학습 효율·학습 범위 밖 일반화·관측/운동 변화에 대한 반응**을 개선하는가"다. 그래프는 $o_t$의 결정론적 함수이므로 관측에 없는 정보를 만들지 않는다. 설계와 주장 범위는 [docs/EXPERIMENT_DESIGN_KO.md](docs/EXPERIMENT_DESIGN_KO.md)에 있다.

## 실행

```matlab
run_check                    % self-test 14개 + 모든 단계 smoke (수 분, 결과 아님)
run_check('learnability')    % 일반 PPO가 쉬운 조건에서 착륙을 배우는지 사전 점검 (약 1시간)
run                          % 3 비교군 × 학습 시드 1–5: 학습 → 평가 → 그림 (수 시간)
run_scenario('S4')           % 통제 사례 하나의 궤적 (학습된 체크포인트 필요)
run_scenario('S4',struct('trace',true))   % 결정 추적 대시보드: 센서 사건 → o_t → TOSM 노드 → R-GAT → 가속도 명령
run_check('trace')           % 결정 추적 수용 시험 A01–A13 (headless)
```

- `run`은 학습 서명이 맞는 체크포인트를 재사용하므로, 중단 후 다시 실행하면 이어서 진행한다.
- 옵션: `run(struct('trainSeeds',1:10))`, `run(struct('sections',{{'factorial','probes'}}))`, `run(struct('retrain',true))`.

## 평가

| 절 | 내용 |
|---|---|
| learning | validation 착륙률 학습 곡선, 목표(50%·80%) 도달 환경 스텝, AUC, plateau 확인(LateGain), PPO 갱신 진단 |
| training | R-GAT 인코더까지 PPO 손실 기울기가 전달되는지, 초기값 대비 파라미터 변화, 각 run이 쓴 관계 그래프(교란 비율) |
| heldout | 학습 분포 test 200개. 전체와 UGV(CV/CA) × 마커(정상/누락) 네 셀. 회복 시간·재획득 시간·착지 오차·실패 분류 |
| factorial | 통제 사례 S1–S4 (CV·CA × 정상·누락, S4는 누락이 가속 시작과 겹침). 짝지은 효과와 상호작용 $S4-S3-S2+S1$, 잡음에 의한 궤적 분산 |
| generalization | 학습 범위 밖: 가속 1.0–1.5 m/s², 누락 1–2 s, 잡음 ×2, 가속+누락 |
| probes | 모든 정책에 같은 관측 입력. 관측 잡음 민감도 $\mathrm{tr\,Cov}[a]$, UGV 속도 대비에 대한 민감도, 마커 갱신 유무에 대한 반응, attention |

모든 요약은 **학습 시드 간** 평균과 95% t 구간이다(중앙값·사분위수도 함께 저장). 비교군 차이는 학습 시드별 짝 차이로 계산한다. 시드 하나로는 방법 간 차이를 주장하지 않는다. 관측 잡음 민감도와 궤적 분산은 추종 오차·회복 시간·속도 민감도와 함께만 해석한다(입력을 무시하는 정책도 잡음에 둔감하다).

## 구조

```
run.m  run_check.m  run_scenario.m      진입점
src/orchestration/+landing2d/
  +config         실험·PPO·평가 설정, 비교군 등록
  +orchestration  파이프라인, 학습/로드, self-test
  +evaluation     평가 6종, 지표, 실패 분류, 시드 통계
  +viz            결과 그림, 결정 추적 대시보드
  +trace          결정 추적: 기록·출처·설명·내보내기·시험 (진단 전용)
  +util           Adam, 해시 등
src/simulations/+landing2d/     환경·동역학·센서·공통 관측·기준 구동기
src/algorithms/+landing2d/      PPO, TOSM 그래프, R-GAT
docs/                           설계·관측·온톨로지·보상·기호
results/                        checkpoints, evaluation, figures (생성물)
```

문서: [실험 설계](docs/EXPERIMENT_DESIGN_KO.md) · [공통 관측](docs/COMMON_OBSERVATION_KO.md) · [TOSM 온톨로지](docs/TOSM7_ONTOLOGY_KO.md) · [보상](docs/REWARD_KO.md) · [기호](docs/NOTATION_KO.md) · [결정 추적 대시보드](docs/TRACE_DASHBOARD_KO.md)
