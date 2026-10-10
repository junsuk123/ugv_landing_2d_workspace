# 최소 핵심 파이프라인 (2026-10-08)

## 범위

평면 비교군은 동일 센서, 12차원 공통 관측, 보상, 행동, 종료 규칙을 사용한다. 차이는 Actor/Critic 상태 표현뿐이다.

- `ppo`: 12차원 공통 관측을 MLP에 직접 입력
- `onto_rgat_ppo`: 같은 12차원 값으로만 7개 노드·4개 관계 그래프를 만들고, grouped R-GAT embedding을 MLP에 직접 입력

## 12차원 공통 관측

`relative_x`, `relative_height`, `relative_vx`, `ugv_vx`, `drone_vz`, `drone_sinTheta`, `drone_cosTheta`, `drone_pitchRate`, `ugv_visionUpdated`, `ugv_visionAge`, `drone_navigationValid`, `drone_navigationAge`.

전역 수평 위치, 항상 0이던 `drone_x`, 직전 시점 상태 전체 복사를 제거했다. 벡터는 마커/PnP/KF 추정과 드론 항법 측정으로만 만들어진다.

## 온톨로지

노드: `RelativePosition`, `RelativeVelocity`, `PadVelocity`, `VerticalMotion`, `Attitude`, `VisionQuality`, `NavigationQuality`.

관계: `informs`, `conditions`, `couples`, `self`. 그래프 특징은 등록된 12차원 벡터를 다시 읽어서만 생성한다. 착륙 승인, 감독기 모드, 보상, 종료 결과, simulator truth는 노드 특징에 없다.

## 학습·추론

`o_t -> ontology graph -> typed attention -> grouped readout -> Actor/Critic MLP -> tanh -> acceleration` 단일 경로이다. raw semantic bypass, additive relation residual, descent gate, masked-node pretraining, backbone freeze, relation-only adaptation, validation guard, behavior cloning, scripted descent prefix, curriculum replay를 기본 평면 파이프라인에서 사용하지 않는다. 정책 명령은 감독기가 수정하지 않고 동역학에 직접 적용된다.

PPO가 R-GAT encoder와 Actor/Critic을 처음부터 end-to-end로 공동 학습한다. Simulink/RL Toolbox 변환도 같은 direct grouped embedding을 사용한다.

### 2026-10-10 최종 파라미터 정합 구조

- 관계 은닉: 16차원 복원
- 저랭크 grouped readout: `W_c ∈ R^(16×16)`, `W_n ∈ R^(16×7)`, 출력 16차원
- Actor head: `16–38–37–2`, Critic head: `16–35–34–1`
- 인코더당 1,040개, Actor 3,207개, Critic 2,894개, 합계 6,101개
- 일반 PPO와 파라미터 수 정확히 동일
- raw 관측 우회·residual·gate·guard 없음

Held-out 100회 결과는 착륙 96%, unsafe 1%, timeout 3%, 평균 return 32.372이다. 일반 PPO 대비 공칭 `C_valid`는 77.329%에서 80.799%로 증가했다. `D_obs` P95 0.095983과 pooled `J_policy` 6.6914는 종전 6,095개 과압축 모델보다 각각 5.5%, 11.4% 개선됐지만 일반 PPO보다는 높다.

## 측정 결과

- MATLAB self-test 13/13 통과
- smoke 파이프라인 통과
- R-GAT 120 iteration, reward_v3: test 착륙 0%, unsafe 0%, abort 15%, timeout 85%, mean return -10.558

## 2026-10-08 역학 정합 튜닝 결과

- 단순 증액 진단: 500 반복은 3,000 에피소드이므로 과거 2,500 에피소드를 이미 넘었지만, 기존 승인 가드에서는 validation/test 착륙이 모두 0%였다.
- 원인 1: 카메라 접근 곡면 `ex=h*tan(30 deg)`의 미분은 `relativeVx=tan(30 deg)*vz`인데 기존 속도 potential은 `relativeVx=0`을 목표로 해 하강 중 위치 목표와 충돌했다.
- 원인 2: 최종 하강 승인은 0.5 m에서 3초 후 만료됐지만 안전한 `0.8h` 하강의 0.04 m 접촉까지 이론 시간도 약 3.16초라 정상 접근을 `UNAUTHORIZED_CONTACT`로 만들었다.
- 수정: 접근 곡면 오차와 폐합 속도를 공통 reward와 온톨로지 노드에 함께 적용하고, 7개 노드를 평균 3그룹으로 비가역 압축하지 않고 노드별 readout으로 보존했다. 평면 direct-policy 경로의 착륙 승인·SAFE_ABORT 가드는 제거하고 기계적 접촉 조건만 유지했다.
- 500 반복(3,000 에피소드), seed 1: 선택 체크포인트 225회. validation 30개 seed 착륙 73.3%, held-out test 50개 seed 착륙 68.0%, unsafe 10.0%, timeout 22.0%, safe-abort 0%, 포착률 74.1%, 평균 반환 17.686.
- 동일 reward·seed·예산의 일반 PPO는 선택 체크포인트 25회, validation/test 착륙 0%, test unsafe 0%, timeout 100%, 포착률 31.4%, 평균 반환 -6.573이었다. 따라서 개선은 보상만이 아니라 관측 기반 접근 곡면 온톨로지와 direct R-GAT 표현에서 발생했다.
- 225회 이후 현재 정책은 다시 붕괴했으나 validation 선택 정책은 보존됐다. 따라서 기본 평면 예산은 500 반복으로 두고, 2,500 반복까지의 단순 증액은 채택하지 않는다.
- 공격적 수직 shaping 후보: test unsafe 45%로 폐기
- 보수적 shaping+안정화 500 iteration 진단: capture는 80%까지 증가했으나 반환된 마지막 정책은 test 착륙 0%, unsafe 8%, timeout 92%. 이 실험에서 direct-PPO checkpoint 적격 버그를 발견·수정했다.

따라서 현재 수치는 구조 단순화와 추적/capture 학습을 검증하지만, 착륙 성능 개선을 증명하지는 못한다. 보조 장치 없이 공식 난이도에서 착륙을 발견하는 문제가 남은 핵심 한계이다.
