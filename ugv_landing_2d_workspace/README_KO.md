# 이동 UGV 착륙 — Planar Visibility PPO v2

## v2.8 현재 제안 모델

현재 제안 모델은 semantic-flat의 108차원 상태를 손실 없이 그대로
Actor/Critic에 전달하고, 9노드·26간선 1층 R-GAT이 만든 지각·추적·기체·안전
문맥 4개를 별도 residual head로 더합니다. 따라서 그래프 압축이 flat 정책의
정보를 제거할 수 없습니다. 전체 파라미터는 현재 17,001개입니다.

전체 PPO의 처음 90%는 관계 출력을 0으로 고정해 semantic-flat과 동일한
정책을 동일 난수 흐름으로 학습합니다. 마지막 10%에는 완성된 raw 정책을
고정하고 관계 residual만 미세조정합니다. 관계 체크포인트는 validation
점수가 충분히 개선될 때만 flat-equivalent 체크포인트를 교체합니다.

R-GAT 백본은 train seed의 현재 시점 노드 특성만 마스킹 복원하여 먼저
학습합니다. 행동·보상·성공 여부·미래 샘플·교사 명령·시뮬레이터 참값은
입력이나 목표로 사용하지 않습니다. PPO 단계에서는 불변 관계 변환을
고정하고 상황 의존 attention gate와 작은 readout/head만 갱신합니다.

v2.8에서는 관계 residual을 수평 복구와 수직 착륙 채널로 분리했습니다.
수직 관계 출력이 추가 하강을 요구할 때는 `DescentEligibility`만큼만 통과하며,
`LandingInhibit`가 활성화되면 추가 하강 residual은 0이 됩니다. 상승·제동과
수평 복구는 억제하지 않습니다. 따라서 온톨로지의 `supports`/`inhibits` 의미가
attention 이름에만 머무르지 않고 실제 행동 제약으로 보존됩니다.

```matlab
run_all                                      % 기본: 전체 A/B/C 학습
run_graph_ablation(struct('executionMode','smoke', ...
    'figureVisible',false,'animate',false,'saveResults',false))
```

체크포인트 선택은 validation 100 seed를 사용하며 unsafe에는 성공보다 2.5배
큰 선택 페널티를 적용합니다. 최종 보고는 개발 과정에서 사용하지 않은 새 test
구간 `3001:3200` 중 100 seed를 사용합니다. 상세 설계는
[`docs/refactor/SEMANTIC_RESIDUAL_RGAT_V28.md`](docs/refactor/SEMANTIC_RESIDUAL_RGAT_V28.md)에
정리되어 있습니다. 아래의 query-node 설명은 v2.5 이전 구조 기록입니다.

연속 가속하는 이동 패드에서 기체 고정 하향 카메라의 시야 상실을 다루는 MATLAB
2차원 `x-z` 연구 시뮬레이터입니다. 기본 실험은 환경·관측 기억·행동·안전 감독기·
보상·종료 조건을 완전히 공유하고 상태 표현만 다른 세 PPO를 비교합니다.

| 비교군 | Actor/Critic 입력 |
|---|---|
| A 저수준 MLP | 이름이 정의된 공통 인과 관측 패킷 26개 필드 |
| B 의미 평탄화 MLP | 온톨로지와 동일한 노드 특징을 간선 없이 평탄화 |
| C 제안 모델 | 동일 노드 특징과 타입 관계를 두 개의 독립 R-GAT으로 처리 |

정책 행동은 정확히 2개이며 `tanh(u_raw)`를 거쳐 월드 좌표계의 요청 가속도
`[ax, az]`가 됩니다. 실제 이동과 카메라 투영에는 지연된 실제 피치와 실제 추력을
사용합니다. 피치나 짐벌은 정책 행동이 아닙니다.

## 실행

```matlab
run_tests(false)    % 기존 회귀 + 신규 계약 테스트 24개
run_all             % A/B/C 전체 PPO 학습·평가(기본 full 모드)
full_study_commands % 장시간 연구 실행 명령만 출력
```

`run_all` 기본값은 전체 학습 및 평가입니다. 저장된 호환 체크포인트를 무시하고
처음부터 다시 학습하려면 다음과 같이 실행합니다.

```matlab
run_all(struct('executionMode','full','rlRetrain',true))
```

최종 연구 주장은 한 번의 학습 seed가 아니라 기본 5개 독립 PPO seed의 평균과
표준편차로 검증합니다. 이 실행은 매우 오래 걸리므로 별도 명령으로 분리했습니다.

```matlab
run_multiseed_study(struct('executionMode','full'))
```

한 번의 PPO 반복으로 코드 연결만 빠르게 확인하려면 스모크 모드를 명시합니다.

```matlab
run_all(struct('executionMode','smoke'))
```

전체 학습은 세 비교군 모두 모방학습 없이 동일한 2,500회 scratch PPO 설정을
사용합니다. 초기에는 패드 위 0.4~0.8 m에서 시작해 무작위 정책도 교사 없이 실제
안전 착륙 표본을 발견하게 합니다. 3개 평가 창 연속으로 학습 착륙률 1% 이상을
달성할 때만 난이도를 4%씩 높여 고도·패드 운동·미관측 임계시간·충돌 페널티를
공칭 조건으로 수렴시킵니다. 모든 모델에는 동일한 착륙 준비도 dense reward와
potential-difference 항을 적용합니다. 검증과 최종 시험에는 처음부터 끝까지 원래
분포, 공칭 3초 안전 감독기와 충돌 페널티 `-40`만 사용합니다.
패드 미관측 3초는 즉시 종료가 아니라 공통 안전 감독기의 상승·정지 복구를 시작하며,
8초 안에 패드를 다시 관측하면 중단 래치를 해제하고 정책 제어로 복귀합니다. 끝까지
재획득하지 못한 경우에만 `SAFE_ABORT`로 종료합니다.
복구 중 수평 제어는 미래 참값이 아니라 마지막 인과 패드 추정치의 위치오차와
상대속도만 따라가므로, 움직이는 UGV를 정지 상태로 놓쳐 버리던 문제도 제거했습니다.

학습 완료 후 인과 관측만 사용하는 PN 기준 유도, 저수준 PPO, 온톨로지 R-GAT PPO를
동일한 V2 시험 seed에서 한 화면으로 재생합니다.

```matlab
run_finalTest                         % 실제 속도 재생
run_finalTest(struct('playbackSpeed',4))   % 4배속
run_finalTest(struct('playbackSpeed',Inf)) % 대기 없이 최종 궤적 표시
```

최종 창은 평가 seed별 고정 축 궤적, 실제 피치 기반 카메라 FOV, CV/CA/CV 배경,
R-GAT relation attention과 Monte Carlo 평균·1σ 공분산을 함께 표시합니다.

기존 11차원·이중적분기 실험은 삭제하지 않았으며 명시적으로 실행할 수 있습니다.

```matlab
run_all(struct('experimentVersion','legacy_v1'))
```

## 새 기본 실험 구조

```text
CV–CA–CV 패드 + 피치/추력 평면 기체
  -> 실제 피치로 회전하는 기체 고정 카메라
  -> 모든 비교군이 공유하는 인과적 패드 추정/관측 기억
  -> A: 관측 MLP | B: 의미 평탄화 MLP | C: 타입 관계 R-GAT
  -> Gaussian 원시 명령 -> tanh -> 요청 [ax, az]
  -> 공통 안전 감독기 -> 피치/추력 내부 루프 -> 물리 환경
  -> 최초 접촉/종료 판정 -> 공통 3개 실행 비용 + 1회 종말 보상
```

관측 패킷은 임의의 “11차원” 상수가 아니라
`landing2d.sensing.observationSchema`가 차원을 결정합니다. 현재는 26개입니다.
패드 속도와 가속도는 유효 검출의 실제 시간 차로 추정하며, 비가시 구간의 현재
패드 참값·구간 번호·미래 이벤트는 정책, Critic, 온톨로지, 감독기에 들어가지 않습니다.

## 온톨로지

의미 노드는 `PadVisibility`, `PadMotion`, `DroneTranslation`, `DroneAttitude`,
`RelativeTracking`, `TrackingCorrection`, `ViewRecovery`, `DescentEligibility`,
`LandingInhibit`입니다. `PolicyNode`와 `ValueNode`는 결과/행동 라벨이 없는 질의
노드입니다. 관계는 `informs`, `affects_visibility`, `supports`, `inhibits`,
`contributes`, `self`이며 무언의 역방향 간선을 만들지 않습니다.

R-GAT의 attention은 감독된 관계 중요도 정답이 아니라 PPO/가치 손실을 통해
학습되는 내부 계수입니다. 행동 문맥 C01–C12의 점수도 가속도 교사 명령이 아니라
해석 가능한 유계 사전 문맥일 뿐입니다.

## 보상과 종료

$$
r_t=B(e_t)-\frac{\Delta t}{T_{ref}}
\left(w_g c_{goal}+w_v c_{view}+w_u c_{control}\right)
$$

성공, 안전 중단, 시간 초과, 위험/비허가 접촉은 서로 다른 종말 사건이며 보상은
사건 시점에 정확히 한 번만 지급됩니다. 임무 시간 초과도 `terminated=true`이고
bootstrap은 0입니다. 단순 수집 경계만 `truncated=true`로 bootstrap합니다.

## 문서

- [시스템 블록 명세](docs/refactor/SYSTEM_SPEC.md)
- [설정 및 스키마](docs/refactor/CONFIGURATION.md)
- [보상 설계 근거](docs/refactor/REWARD_RATIONALE.md)
- [최종 구현/검증 보고서](docs/refactor/FINAL_REPORT.md)
- [모듈 지도](docs/MODULE_MAP_KO.md)

현재 검증은 MATLAB R2025b의 24개 비그래픽 테스트와 제한 스모크까지입니다.
장시간 다중 시드 학습은 실행하지 않았으므로 제안 모델의 우월성·보편 최적성·
실기체 안전성을 주장하지 않습니다.

## 논문용 최종 모델 시각화

```matlab
run_paper
run_paper(struct('figureVisible',false))
study = run_paper_validation(struct('saveResults',false));
```

`run_paper`는 재학습 없이 최종 baseline, semantic-flat, ontology R-GAT
체크포인트를 불러오고, 명목 정렬·급가속·가시성 손실의 고정 3개 시나리오를
동일한 물리 조건과 센서 이벤트로 검증합니다. 속도·가속도·제한시간으로 계산한
물리적 착륙 가능성과 일시적 `LandingInhibit`를 구분하며, 금지 시간은 센서
드롭아웃·궤적/FOV·상대속도·불확실성 원인으로 분해됩니다.

결과는 `results/paper/`에 PNG/PDF/FIG/CSV/MAT로 저장됩니다. 특히
`paper_architecture_audit.csv`는 선택된 R-GAT 체크포인트의 관계 readout이 실제로
활성인지 검사합니다. 0인 경우 실행 시 경고하고, 이를 활성 R-GAT 기여로 해석하지
않습니다.
