# TOSM 축소 온톨로지 (`tosm7_v2`)

R-GAT 비교군(`onto_rgat_ppo`, `shuffled_rgat_ppo`)의 상태 표현이다. 10차원 공통 관측 $o_t$
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
| N3 | `RelativePosition` | Explicit | relative_x, relative_height |
| N4 | `RelativeVelocity` | Explicit | relative_vx, relative_vx² |
| N5 | `DroneMotion` | Explicit | drone_vz, sinθ, pitchRate |
| N6 | `ViewMargin` | Implicit | $(\theta_{FOV}/2-|\hat\beta|)/(\theta_{FOV}/2)$, $\hat\beta/(\theta_{FOV}/2)$ |
| N7 | `LandingCondition` | Implicit | $r/(1+r)$, $r$ = \|e_x\|, \|v_r\|, \|v_z\|, \|θ\|, \|θ̇\| ÷ 접지 한계 |

- N2–N5의 값은 정규화된 $o_t$ 성분 $x/(\lvert x\rvert+s)$이다. N6·N7은 역정규화한 미터·라디안 값으로 계산한다.
- `tosm7_v1`에서 `tosm7_v2`로 바뀐 것(`relational-policy-v2.3`, 2026-10-20). 결과와 무관하게 결함이 확정된 특징만 뺐고, 빈 채널은 0 패딩이다. 노드·간선·채널 수는 그대로다.
  - N3 `normalizedCrossTrack` $c=s_x(e_x)-m\,s_h(h)$: 정규화 척도가 다른 두 축을 섞는다. 그래서 미터 단위 aim error $e_x-mh$가 아니고, 광축 기준점에서도 0이 아니었다(`VARIABLE_NAMING_AUDIT.md` F5).
  - N3 `geometryQuadratic` ½($c$²+h²): 같은 결함이 있는 $c$로 정의된다.
  - N5 `navigationValid`·`navigationAge`: 구조상 상수(1, 0)이고, $o_t$에서도 뺐다.
  - 남긴 것: 제곱 특징(ugv_vx², relative_vx²)과 `visionUpdated`. 기반 값의 결정론적 함수이고 새 정보는 없지만, 상수나 정의 결함은 아니다. 효과를 검증하지 않은 채 결과를 보고 빼지 않는다.
- `typeId`는 노드 식별 코드 node/N(N1 = 1/7 … N7 = 1)이다. `nodeClasses`의 클래스 번호가 아니다. 예를 들어 RelativePosition과
  RelativeVelocity는 클래스(RelativeState)가 같지만 typeId는 다르다.
- $\hat\beta$는 추정된 상대 위치와 기체 피치, 카메라 장착각으로 계산한다. 계산식은 `landing2d.sensing.projectPad`와 같다.
  이 값은 예상 시야 여유일 뿐 검출 결과가 아니므로 `VisionQuality`와 함께 읽는다.
- `LandingCondition`은 현재 상태의 착륙 적합성을 나타내는 특징이다. 미래 접촉을 예측하지 않는다.
  각 값이 0.5이면 해당 접지 한계에 있다는 뜻이다. 행동·승인·보상·종료 어디에도 guard로 쓰지 않는다.
- `NavigationObservation` 노드는 없다. 항상 유효한 항법 추정에는 유효·경과시간 입력이 없다(v2.3).
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

## 인코더 (`rgat_v2`, 기본값 `relational-policy-v2.11`, 2026-10-22)

설계 근거와 사전 등록은 `RGAT_V2_DESIGN_KO.md`에 있다.

- 표준 관계형 그래프 어텐션 2층을 쓴다. 층마다 모든 간선(의미 13 + self 7)이 관계별 가중치 $W_r$로 메시지 $W_r h_j$를 보낸다.
- 도착 노드는 들어오는 모든 간선(모든 관계 유형과 self)에 대해 입력 의존 attention 하나로 메시지를 모은다. 그래서 입력이 하나뿐인 관계 풀이 α = 1에 고정되지 않는다.
- 노드 갱신은 $h^{(l)}_i=\tanh(W^{(l)}_0h^{(l-1)}_i+\sum_j\alpha_{ij}W_{r(ij)}h^{(l-1)}_j+b^{(l)})$이다. $W^{(l)}_0$는 표준 R-GCN 층의 root(self-connection) 가중치이고 무작위로 초기화한다.
- 관계 가중치는 공유 기저 3개의 조합 $W_r=\sum_b C_{rb}V_b$다. $C_r$는 학습하지 않고 관계 의미 기술자로 고정한다. 공통 좌표, 도착 맥락의 추상화 단계, 관측 품질/자기 정보 역할을 나타내며 모든 행의 크기는 1이다(`RGAT_V2_DESIGN_KO.md` §15).
- attention은 층마다 공유 벡터 하나를 학습하고, 관계 임베딩은 위 의미 기술자와 self 표시의 고정 4차원 벡터다. 관계별 독립 학습 파라미터로 교란 라벨을 재명명할 수 없다.
- 2층이라 리드아웃 전에 관계가 최대 2홉까지 합성된다. 예: `qualifiesEstimate` 다음 `conditionsLanding`.
- 곱셈 게이트, 연산군(modulate/propagate), 항등 초기화, 손으로 고른 readout 시작점(`readoutInit`)은 없다. 초기화는 LeCun 정규 분포다.
- `grouped_factorized` readout: 7개 노드에 하나의 학습 채널 벡터를 공유하되, 고정 실수 Fourier 코드북으로 노드 역할을 16개 graph-embedding 채널에 보존한다. 코드북의 모든 행은 단위 노름이고 모든 노드는 동일한 총 에너지를 갖는다. 특정 노드의 학습 가중치나 손으로 고른 종착점은 없다(`RGAT_V2_DESIGN_KO.md` §18).
- 파라미터:
  - 인코더 하나 1,800개, Actor MLP 26-28, Critic MLP 27-27
  - 전체 6,101개로 일반 PPO(MLP 48-48)와 같다(selfTest `contract`, `relation-attention`)
- `schema.relationOperators`(modulate/propagate)는 v1.x 기록을 위한 서술용 메타데이터다. `rgat_v2` 계산에는 쓰이지 않는다.

### 이전 인코더 (`rgat_v1`, v1.x 기록 재현용)

- 단일 층, 노드별 국소 경로 $W_0X+b_0$(앞 채널 항등 초기화), `readoutInit` 시작점을 썼다.
- `typed_v1`(2026-10-18, v1.1 기본값)
  - 조절 관계(`qualifiesEstimate`, `conditionsLanding`)는 곱셈 게이트 $(1+\tanh(\cdot))$로 작용했다.
  - 전파 관계(`informsMotion`, `affectsVisibility`, self)는 덧셈 메시지였다.
  - `operator_shared_v1`이 연산군별 파라미터를 공유했고, 헤드는 Actor 38-42, Critic 40-36이었다.
  - 결함: PadVelocity·RelativePosition·RelativeVelocity의 조절 입력이 VisionQuality 하나뿐이라 세 노드의 게이트가 항상 같았다(`RGAT_V2_DESIGN_KO.md` §1).
- `additive_v1`: 모든 관계가 덧셈 메시지였다.
- `fixed_relation_v1`: 관측과 무관한 관계별 고정 가중치다.
- 모두 `graphState.encoderVersion = 'rgat_v1'`로 고를 수 있다.

## 관계 교란 대조군 (`shuffled_rgat_ppo`)

- `landing2d.rgat.applyRelationPerturbation`이 의미 간선 13개의 관계 유형을 고정 순열로 바꾼다. self 간선은 보호하고,
  원래 배치와 전역 이름 치환 배치(`qualifiesEstimate` ↔ `informsMotion`, 둘 다 3개)는 거부한다.
- 의미 간선 중 10개 이상(`registry.relationShuffle.minChangedFraction = 0.7`)의 유형이 바뀐 순열만 받는다. registry v5에서 더했던 연산군 변경 규칙은 v6(`rgat_v2`)에서 뺐다. 연산군이 없기 때문이다.
  제약 없는 순열은 평균 3.6개 간선의 TOSM 유형을 우연히 유지하므로, 대조군이 TOSM 배치의 상당 부분을 갖지 않게 한다.
  run별 실제 교란 비율과 간선별 유형은 `training_relations.csv`, `training_edges.csv`에 저장된다.
- 노드·간선(src/dst)·관계별 간선 수·파라미터 초기값은 TOSM과 같다. 그래프 해시와 학습 서명은 다르다.
- 그래프 시드 = 학습 시드. 체크포인트에는 실제 사용한 그래프(src/dst/rel/hash)가 저장된다. 로드할 때는
  `landing2d.rl.verifyCheckpointGraph`가 이를 확인한다. 추론 시 다시 순열하지 않는다.

## 진단 해석

- open-loop 갱신 대비의 `AttentionShift`는 마커 갱신 상태가 바뀔 때 VisionQuality 출발 간선의 α가 얼마나 바뀌는지
  보여준다. α는 들어오는 간선 합이 1인 정규화 계수일 뿐 인과적 중요도가 아니다.
- 노드 특징·α는 평가 지표에 쓰지 않는다. 평가 지표는 참값 궤적에서만 계산한다.
