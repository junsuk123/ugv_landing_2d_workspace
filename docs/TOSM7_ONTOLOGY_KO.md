# TOSM 축소 온톨로지 (`tosm7_v5`)

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
| N7 | `LandingCondition` | Implicit | relative_x, relative_vx, **0**, sinθ, pitchRate (부호 있는 o_t 값). 수직속도는 N5에서 관계 메시지로 전달. `tosm7_v4`: f3=drone_vz. `tosm7_v3`: 없음(잠재). `tosm7_v2`: 접지 한계비 $r/(1+r)$ |

- N2–N5의 값은 정규화된 $o_t$ 성분 $x/(\lvert x\rvert+s)$이다. N6(과 `tosm7_v2`의 N7)은 역정규화한 미터·라디안 값으로 계산한다.
- `tosm7_v5`(`relational-policy-v2.15`, 2026-10-24, `RGAT_V2_DESIGN_KO.md` §23):
  v2.14 validation 잡음 진단에서 수직속도와 종착 노드 직접 경로의 큰 민감도가 남았다.
  N7 f3의 중복 사본만 0으로 바꾸고 N5의 수직속도, 다른 모든 특징·위상·인코더 수식은 유지한다.
  새 관측·필터·손실·가드는 없다. v2.13의 전체 잠재화와 다르며, 재학습 전 후보다.
  위치·상대속도·자세의 직접 경로는 남아 있으므로 관계 의미의 필요성을 보장하지 않는다.
  `tosm7_v2/v3/v4`는 저장된 특징 그대로 기록 재현에 사용한다.
- `tosm7_v2`에서 `tosm7_v3`으로 바뀐 것(`relational-policy-v2.13`, 2026-10-23, `RGAT_V2_DESIGN_KO.md` §21). readout 종착 노드 LandingCondition을 잠재 노드로 바꿨다.
  - 상태는 `conditionsLanding` 메시지로만 정해진다. 노드·간선·채널 수는 그대로다.
  - v2.12 readout은 이 노드만 읽는데, 이 노드의 접지 한계비는 RelativePosition·RelativeVelocity·DroneMotion 증거의 부호 없는 사본이었다. 0 근처 이득은 $o_t$ 정규화의 5–29배였다. 그래서 의미 간선을 거치지 않는 고이득 경로가 정책의 주 입력이 됐다.
  - validation probe에서 이 경로가 잡음으로 생긴 행동 분산의 대부분을 실었다. 상대 속도 반응도 0에서 꺾인 천막 모양이었다($v_{rel}>0$이면 감속).
  - 접지 한계비는 `semanticEvidence`에 서술값으로 남는다(결정 추적 표시).
  - 두 그래프 비교군 모두 학습이 무너졌다(80% 도달 최대 2/5, §21.5).
- `tosm7_v4`(`relational-policy-v2.14`, 2026-10-23, §22). LandingCondition f1–f5를 같은 다섯 양의 부호 있는 o_t 값으로 바꿨다. 이득과 부호가 PPO 입력과 같다.
  - v2.12의 학습 가능한 직접 경로는 유지하고, 천막 반응과 잡음 증폭의 원인(부호 없음·고이득)만 없앤다.
  - 종착 노드가 다른 노드 증거의 사본을 다시 가지므로, 관계 라벨을 우회할 수 있다. 이 버전으로 관계 의미의 필요성을 주장하지 않는다.
- `tosm7_v1`에서 `tosm7_v2`로 바뀐 것(`relational-policy-v2.3`, 2026-10-20). 결과와 무관하게 결함이 확정된 특징만 뺐고, 빈 채널은 0 패딩이다. 노드·간선·채널 수는 그대로다.
  - N3 `normalizedCrossTrack` $c=s_x(e_x)-m\,s_h(h)$: 정규화 척도가 다른 두 축을 섞는다. 그래서 미터 단위 aim error $e_x-mh$가 아니고, 광축 기준점에서도 0이 아니었다(`VARIABLE_NAMING_AUDIT.md` F5).
  - N3 `geometryQuadratic` ½($c$²+h²): 같은 결함이 있는 $c$로 정의된다.
  - N5 `navigationValid`·`navigationAge`: 구조상 상수(1, 0)이고, $o_t$에서도 뺐다.
  - 남긴 것: 제곱 특징(ugv_vx², relative_vx²)과 `visionUpdated`. 기반 값의 결정론적 함수이고 새 정보는 없지만, 상수나 정의 결함은 아니다. 효과를 검증하지 않은 채 결과를 보고 빼지 않는다.
- `typeId`는 노드 식별 코드 node/N(N1 = 1/7 … N7 = 1)이다. `nodeClasses`의 클래스 번호가 아니다. 예를 들어 RelativePosition과
  RelativeVelocity는 클래스(RelativeState)가 같지만 typeId는 다르다.
- $\hat\beta$는 추정된 상대 위치와 기체 피치, 카메라 장착각으로 계산한다. 계산식은 `landing2d.sensing.projectPad`와 같다.
  이 값은 예상 시야 여유일 뿐 검출 결과가 아니므로 `VisionQuality`와 함께 읽는다.
- `LandingCondition`은 현재 상태의 착륙 적합성을 나타내는 맥락 노드다. 미래 접촉을 예측하지 않는다.
  `tosm7_v3`에서는 자체 특징 없이 관계로만 형성된다. 서술값인 접지 한계비는 0.5이면 해당 한계에 있다는 뜻이다. 행동·승인·보상·종료 어디에도 guard로 쓰지 않는다.
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

## 인코더 (`rgat_v2`, 기본값 `relational-policy-v2.15`, 2026-10-24; 인코더·readout은 v2.12와 같고 그래프 특징만 `tosm7_v5`)

설계 근거와 사전 등록은 `RGAT_V2_DESIGN_KO.md`에 있다.

- 표준 관계형 그래프 어텐션 2층을 쓴다. 층마다 모든 간선(의미 13 + self 7)이 관계별 가중치 $W_r$로 메시지 $W_r h_j$를 보낸다.
- 도착 노드는 들어오는 모든 간선(모든 관계 유형과 self)에 대해 입력 의존 attention 하나로 메시지를 모은다. 그래서 입력이 하나뿐인 관계 풀이 α = 1에 고정되지 않는다.
- 노드 갱신은 $h^{(l)}_i=\tanh(W^{(l)}_0h^{(l-1)}_i+\sum_j\alpha_{ij}W_{r(ij)}h^{(l-1)}_j+b^{(l)})$이다. $W^{(l)}_0$는 표준 R-GCN 층의 root(self-connection) 가중치이고 무작위로 초기화한다.
- 관계 가중치는 공유 기저 3개의 조합 $W_r=\sum_b C_{rb}V_b$다. $C_r$는 학습하지 않고 관계 의미 기술자로 고정한다. 공통 좌표, 도착 맥락의 추상화 단계, 관측 품질/자기 정보 역할을 나타내며 모든 행의 크기는 1이다(`RGAT_V2_DESIGN_KO.md` §15).
- attention은 층마다 공유 벡터 하나를 학습하고, 관계 임베딩은 위 의미 기술자와 self 표시의 고정 4차원 벡터다. 관계별 독립 학습 파라미터로 교란 라벨을 재명명할 수 없다.
- 2층이라 리드아웃 전에 관계가 최대 2홉까지 합성된다. 예: `qualifiesEstimate` 다음 `conditionsLanding`.
- 곱셈 게이트, 연산군(modulate/propagate), 항등 초기화, 손으로 고른 readout 시작점(`readoutInit`)은 없다. 초기화는 LeCun 정규 분포다.
- `grouped_factorized` readout: 온톨로지 종착 노드 `LandingCondition`의 최종 상태 하나만 읽는다, $g=\tanh((W_cH_{LC})\odot w_n+b_g)$(`landing_sink_v1`, `RGAT_V2_DESIGN_KO.md` §19). 나머지 여섯 노드의 증거는 의미 간선으로만 도달하고, 2층 안에 일곱 노드 모두 `LandingCondition`에 닿는다. (`tosm7_v3`에서는 종착 노드 자신도 특징이 없었다. `tosm7_v4`의 종착 노드 특징은 부호 있는 o_t 값이며 self/root 경로로도 readout에 닿는다.) v2.11의 7노드 고정 코드북 readout(§18)은 기록 재현용 선택지로 남는다.
- 파라미터:
  - 인코더 하나 1,800개, Actor MLP 26-28, Critic MLP 27-27
  - 전체 6,101개로 일반 PPO(MLP 48-48)와 같다(selfTest `contract`, `relation-attention`)
- v2.15에서 수직속도는 N5에서 의미 간선을 거쳐서만 readout에 닿는다. N7 f3은 항상 0이다.
  두 층 안의 `DroneMotion → LandingCondition` 경로와 수직속도에 대한 정책 반응 경로는 self-test가 검사한다.
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
