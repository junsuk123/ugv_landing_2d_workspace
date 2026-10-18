# TOSM 축소 온톨로지 (`tosm7_v1`)

R-GAT 비교군(`onto_rgat_ppo`, `shuffled_rgat_ppo`)의 상태 표현이다. 12차원 공통 관측 $o_t$
(`COMMON_OBSERVATION_KO.md`)의 결정론적 함수이고, 새 센서·추정기·참값을 쓰지 않는다. 실험 설계와 주장 범위는
`EXPERIMENT_DESIGN_KO.md`가 정의한다.

## 범위

- 다루는 관계: 불완전한 마커 관측(`qualifiesEstimate`), UGV 운동 변화(`informsMotion`), 시야·착륙 조건
  (`affectsVisibility`, `conditionsLanding`).
- 다루지 않는 것: 추정·제어 지연 보상, 3차원 접촉 안전. $o_t$에는 공분산·innovation이 없으므로, 관측 품질은
  "마커 갱신 여부·경과시간"으로만 해석한다. 센서 신뢰도를 추정한다는 뜻이 아니다.
- 온톨로지는 관측에 없는 정보를 만들지 않는다($I(s_t;z_t)\le I(s_t;o_t)$). 관계 구조는 같은 정보를 어떤 경로로
  모을지에 대한 사전지식이다.

## 노드 (6채널 = 노드별 특징 5 + typeId)

| ID | 노드 | TOSM | f1–f5 (모두 $o_t$의 결정론적 함수) |
|---|---|---|---|
| N1 | `VisionQuality` | Explicit | visionUpdated, visionAge |
| N2 | `PadVelocity` | Explicit | ugv_vx, ugv_vx² |
| N3 | `RelativePosition` | Explicit | relative_x, relative_height, 정규화 cross-track $c$, ½($c$²+h²) |
| N4 | `RelativeVelocity` | Explicit | relative_vx, relative_vx² |
| N5 | `DroneMotion` | Explicit | drone_vz, sinθ, pitchRate, navigationValid, navigationAge |
| N6 | `ViewMargin` | Implicit | $(\theta_{FOV}/2-|\hat\beta|)/(\theta_{FOV}/2)$, $\hat\beta/(\theta_{FOV}/2)$ |
| N7 | `LandingCondition` | Implicit | $r/(1+r)$, $r$ = \|e_x\|, \|v_r\|, \|v_z\|, \|θ\|, \|θ̇\| ÷ 접지 한계 |

- N2–N5의 값은 정규화된 $o_t$ 성분 $x/(\lvert x\rvert+s)$이다. 그래서 N3의 cross-track은 정규화 좌표에서 계산한
  $s_x(e_x)-m\,s_h(h)$이고, 미터 단위 aim error $e_x-mh$와 같지 않으며 광축 기준점에서 0도 아니다. 코드의 변수와 스키마 라벨 이름은
  `normalizedCrossTrack`이다(`docs/VARIABLE_NAMING_AUDIT.md` F5). N6·N7은 역정규화한 미터·라디안 값으로 계산한다.
- `typeId`는 노드 식별 코드 node/N(N1 = 1/7 … N7 = 1)이다. `nodeClasses`의 클래스 번호가 아니다. 예를 들어 RelativePosition과
  RelativeVelocity는 클래스(RelativeState)가 같지만 typeId는 다르다.
- $\hat\beta$는 추정된 상대 위치와 기체 피치, 카메라 장착각으로 계산한다. 계산식은 `landing2d.sensing.projectPad`와 같다.
  이 값은 예상 시야 여유일 뿐 검출 결과가 아니므로 `VisionQuality`와 함께 읽는다.
- `LandingCondition`은 현재 상태의 착륙 적합성을 나타내는 특징이다. 미래 접촉을 예측하지 않는다.
  각 값이 0.5이면 해당 접지 한계에 있다는 뜻이다. 행동·승인·보상·종료 어디에도 guard로 쓰지 않는다.
- 측위 유효·경과시간은 `NavigationObservation` 노드를 없애면서 `DroneMotion` 안으로 옮겼다. 그래서 12차원 정보가 모두 남아 있다.
  cosθ는 |θ|<90° 범위에서 sinθ로 결정되므로 특징에서 뺐다. 단 ViewMargin과 LandingCondition 계산에는 쓴다.
- 추정 노드에는 신뢰도 가중을 하지 않는다. 영상 품질은 `qualifiesEstimate` 간선으로만 추정 노드에 전달된다.
  관계 교란 대조군(`shuffled_rgat_ppo`)에서는 이 간선들의 관계 유형이 다른 유형으로 바뀐다.

## 관계와 간선 (의미 13 + self 7 = 20)

| 관계 | 간선 |
|---|---|
| `qualifiesEstimate` (3) | VisionQuality → PadVelocity, RelativePosition, RelativeVelocity |
| `informsMotion` (3) | PadVelocity → RelativeVelocity, RelativeVelocity → RelativePosition, DroneMotion → RelativePosition |
| `affectsVisibility` (2) | RelativePosition → ViewMargin, DroneMotion → ViewMargin |
| `conditionsLanding` (5) | RelativePosition, RelativeVelocity, DroneMotion, ViewMargin, VisionQuality → LandingCondition |
| `self` (7) | 각 노드 |

`informsMotion`은 운동학 관계다. 예를 들어 `RelativeVelocity → RelativePosition`은 상대 속도가 시간에 따른
상대 위치 변화에 영향을 준다는 뜻이다. 현재 상대 위치를 상대 속도만으로 정한다는 뜻은 아니다.
관계 구조는 고정되어 있고, 매 시점 바뀌는 것은 노드 특징뿐이다.

## 관계 연산자 (`typed_v1`, 기본값)

관계 유형은 가중치만이 아니라 메시지의 연산 형태를 정한다(`schema.relationOperators`).

- 조절(modulate): `qualifiesEstimate`, `conditionsLanding`. "A가 B를 조건 짓는다/한정한다"는 뜻이므로, A의 메시지가 B의 노드 상태에 곱셈 게이트 $(1+\tanh(\cdot))\in(0,2)$로 작용한다.
- 전파(propagate): `informsMotion`, `affectsVisibility`, self. "A가 B를 바꾼다"는 뜻이므로 덧셈 메시지다.
- 두 종류는 각각 도착 노드 기준으로 정규화된 attention 그래프이고, 같은 관계별 파라미터를 쓴다(파라미터 수 불변). 교란 대조군에서는 연산자가 순열된 라벨을 따라간다.
- 근거와 진단은 `EXPERIMENT_DESIGN_KO.md` §2.1에 있다. 모든 관계가 덧셈인 이전 인코더는 `relationOperators = 'additive_v1'`로 고를 수 있다.

## 인코더와 모델 용량

- 단일 R-GAT 층: 관계별 사영 $W_r$, 관계 임베딩 $E_r$, **입력 의존 attention**(`input_dependent_v1`)
  $lpha^{(r)}_{ij}(X_t)$, 도착 노드 기준 softmax. 노드 상태 16차원.
- 노드별 국소 경로 $W_0X+b_0$. 초기값은 앞 채널 항등이고 학습된다. 원시 관측 우회 경로는 없다.
- `grouped_factorized` readout: 노드 × 채널 분해로 16차원 graph embedding을 만든다.
  초기값은 `schema.readoutInit`의 온톨로지 좌표에서 시작한다.
- Actor MLP 35-38, Critic MLP 35-30. 전체 학습 파라미터는 **6,101개로 일반 PPO(MLP 48-48)와 같다**
  (selfTest `contract`, `ppo-smoke`가 검증).
- 이전의 `fixed_relation_v1`(관측과 무관한 관계별 고정 가중치)도 같은 파라미터로 선택할 수 있다. 다만 이번 설계의
  기본값은 아니다.

## 관계 교란 대조군 (`shuffled_rgat_ppo`)

- `landing2d.rgat.applyRelationPerturbation`이 의미 간선 13개의 관계 유형을 고정 순열로 바꾼다. self 간선은 보호하고,
  원래 배치와 전역 이름 치환 배치(`qualifiesEstimate` ↔ `informsMotion`, 둘 다 3개)는 거부한다.
- 의미 간선 중 10개 이상(`registry.relationShuffle.minChangedFraction = 0.7`)의 유형이 바뀐 순열만 받는다.
  제약 없는 순열은 평균 3.6개 간선의 TOSM 유형을 우연히 유지하므로, 대조군이 TOSM 배치의 상당 부분을 갖지 않게 한다.
  run별 실제 교란 비율과 간선별 유형은 `training_relations.csv`, `training_edges.csv`에 저장된다.
- 노드·간선(src/dst)·관계별 간선 수·파라미터 초기값은 TOSM과 같다. 그래프 해시와 학습 서명은 다르다.
- 그래프 시드 = 학습 시드. 체크포인트에는 실제 사용한 그래프(src/dst/rel/hash)가 저장된다. 로드할 때는
  `landing2d.rl.verifyCheckpointGraph`가 이를 확인한다. 추론 시 다시 순열하지 않는다.

## 진단 해석

- open-loop 갱신 대비의 `AttentionShift`는 마커 갱신 상태가 바뀔 때 VisionQuality 출발 간선의 α가 얼마나 바뀌는지
  보여준다. α는 들어오는 간선 합이 1인 정규화 계수일 뿐 인과적 중요도가 아니다.
- 노드 특징·α는 평가 지표에 쓰지 않는다. 평가 지표는 참값 궤적에서만 계산한다.
