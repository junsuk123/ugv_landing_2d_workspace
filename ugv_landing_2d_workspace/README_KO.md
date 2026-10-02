# 이동 UGV 착륙 — Planar Visibility PPO v2

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

한 번의 PPO 반복으로 코드 연결만 빠르게 확인하려면 스모크 모드를 명시합니다.

```matlab
run_all(struct('executionMode','smoke'))
```

전체 학습은 세 비교군 모두 모방학습 없이 동일한 2,500회 scratch PPO 설정을
사용합니다. 초기에는 패드 위 0.4~0.8 m에서 시작해 무작위 정책도 교사 없이 실제
안전 착륙 표본을 발견하게 하고, 이후 고도와 패드 운동을 공칭 CV–CA–CV 분포까지
확장합니다. 미관측 복구 탐색 시간도 12초에서 공칭 3초로 점진적으로 줄이며, 모든
모델에 동일한 potential-difference 진행 보상을 적용합니다. 검증과 최종 시험에는
처음부터 끝까지 원래 분포와 공칭 3초 안전 감독기만 사용합니다.
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
