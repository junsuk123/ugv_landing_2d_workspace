> 2026-10-26: 현재 개발 후보의 구조·비교·실행 계약은 [관계 문맥 잔차 v5](RELATIONAL_RESIDUAL_V5_KO.md)를 따른다. 이 문서는 이전 minimal v3 설계의 재현 기록이다.

# 4노드 온톨로지와 공유 동적 집계 (`tosm4_v1`, v3.1)

현재 구현: `landing2d.minimal.schema`, `features`, `encoderInit/Forward/Backward`.
공통 관측·정규화는 기존 `landing2d.observation.capture`와 `toVector`를 그대로 쓴다.

현재 v3.1은 같은 4노드에서 **가중치를 공유하는 두 번의 동적 집계**를 수행한다. 변경 원인·측정·전체 식은 [v3.1 설계](MINIMAL_V31_DESIGN_KO.md)에 있다. 귀납적 편향과 업데이트는 [학습 설명](INDUCTIVE_BIAS_KO.md), 주 지표는 [실험 설계](EXPERIMENT_DESIGN_KO.md)를 참조한다.

## 노드와 입력

| 노드 | 관측 성분 | o_t 인덱스 | 역할 |
|---|---|---|---|
| ObservationQuality | visionUpdated, visionAge | 9–10 | 상대 추정의 갱신 여부와 나이 |
| TargetMotion | ugv_vx | 4 | 관측으로 추정한 목표 속도 |
| OwnMotion | drone_vz, sinθ, cosθ, pitchRate | 5–8 | 자기 운동·자세 |
| RelativeState | relative_x, relative_height, relative_vx | 1–3 | 추종·하강의 직접 기준 |

$X\in\mathbb R^{10\times4}$에서 각 관측 성분은 그 노드의 해당 행에 한 번만 넣고 나머지는 0으로 둔다. 따라서 $\sum_iX_{:,i}=o_t$이다. 부호·이득은 o_t와 같고 제곱, 접지 비율, typeId는 없다. 공통 좌표를 쓰므로 같은 행은 어느 노드에서나 같은 물리량을 뜻한다.

RelativeState의 **입력**은 상대 관측 세 값이다. 그 노드의 **갱신 후 상태**가 관계로 통합된 표현이다. 별도의 가상 착륙 조건이나 guard를 선언하지 않는다.

## 관계와 위상

| 출발 → 도착 | 관계 | 구조에 넣은 가정 |
|---|---|---|
| ObservationQuality → RelativeState | qualifiesEstimate | 추정의 갱신 상태를 운동 증거와 구분한다 |
| TargetMotion → RelativeState | informsMotion | 목표 운동이 상대 운동을 이해하는 데 필요하다 |
| OwnMotion → RelativeState | informsMotion | 자기 운동도 상대 운동과 하강을 이해하는 데 필요하다 |
| 각 노드 → 자기 자신 | self | 자기 정보의 보존 |

합계는 의미 간선 3개 + self 4개 = **7개**, 관계 유형은 의미 관계 2개 + self = **3개**다. 다른 모든 노드에서 RelativeState까지 한 홉이다. 관계별 연산 종류는 같고 가중치 공유 묶음만 다르다.

## 인코더 수식

먼저 모든 노드에 같은 입력 사영을 적용한다.

$$h_i^0=\tanh(PX_i+b_P),\quad P\in\mathbb R^{8\times10}.$$

두 번의 공유 집계 $\ell=1,2$에서, $e=(j\to i,r)$에 대해

$$m_e^\ell=W_rh_j^{\ell-1},\qquad q_e^\ell=a^T\operatorname{LeakyReLU}_{0.2}\!\left(W_rh_j^{\ell-1}+W_rh_i^{\ell-1}+b_a\right)+\beta_r,$$
$$\alpha_e^\ell=\operatorname{softmax}_{e':\,dst(e')=i}(q_{e'}^\ell),$$
$$h_i^\ell=\tanh\!\left(W_0h_i^{\ell-1}+\sum_{e:\,dst(e)=i}\alpha_e^\ell m_e^\ell+b\right),\qquad g=h_{\mathrm{RelativeState}}^2.$$

$W_r\in\mathbb R^{8\times8}$는 세 관계별 학습 행렬이다. attention 파라미터는 8차원 점수 벡터 $a$, 8차원 공동 bias $b_a$, 세 관계 bias $\beta_r$의 총 19개다. 관계 one-hot의 선형 계수로 $\beta_r$를 해석할 수 있다. 코드의 `params.a`는 이 세 항을 이어 저장한다. $W_0$는 root 변환이다. 두 집계는 같은 가중치를 사용한다. softmax는 도착 노드별 최대 점수를 빼고 계산하며 정확히 정규화한다.

입력 사영은 메시지 전달 층이 아니다. 서로 다른 관측 행의 정보를 같은 8차원 공간으로 옮긴 다음 관계별 변환을 적용한다. 기저 분해·의미 코드북·곱셈 게이트·잔차 혼합·학습 readout은 없다. 모든 학습 가중치는 fan-in 기준 무작위 초기화, bias는 0이다. 고른 제어기나 항등 경로를 초기값에 넣지 않는다.

Actor와 Critic은 같은 구조의 독립 인코더를 쓴다. Actor는 $g\to\mathrm{MLP}_{32}\to\mu$, Critic은 $g\to\mathrm{MLP}_{32}\to V$이다. PPO 손실·가우시안 탐색·tanh 행동 제한은 공통 코드다.

| 파라미터 | 개수 |
|---|---:|
| $P,b_P$ | 88 |
| 세 $W_r$ | 192 |
| 공유 $a,b_a,\beta$ | 19 |
| $W_0,b$ | 72 |
| 인코더 하나 | **371** |
| 그래프 모델: Actor 인코더·head + Critic 인코더·head + logσ | **371+354+371+321+2 = 1,419** |
| PPO: Actor 10→58→2 + Critic 10→55→1 + logσ | **756+661+2 = 1,419** |

PPO 폭 58/55는 위 예산을 정확히 맞추기 위한 산술 선택이며 성능 탐색으로 고른 값이 아니다. 두 번의 집계가 같은 가중치를 사용하므로 파라미터 수는 한 홉 v3와 동일하다. 계산량은 증가한다. 보관 `rgat_minimal_v1`은 기존 한 홉 식을 그대로 실행한다.

## 관계 교란의 정확한 의미

정상 관계열은 `[qualifiesEstimate, informsMotion, informsMotion]`이다. 교란은 이를 `[informsMotion, qualifiesEstimate, informsMotion]` 또는 `[informsMotion, informsMotion, qualifiesEstimate]`로 바꾼다. self·출발/도착·특징·관계별 간선 수는 그대로이며 세 의미 간선 중 정확히 두 개가 바뀐다. 전역 이름 교환과 다르게 **어떤 두 출발 노드가 변환을 공유하는지**가 달라진다.

`graphSeed=trainSeed`, `minChangedFraction=2/3`으로 고정하고 결과와 무관하게 선택한다. 두 그래프 비교군은 같은 학습 시드에서 초기 파라미터가 정확히 같다. 관계 이름 자체가 추론 규칙을 실행하지 않으며, attention이나 가중치 크기를 인과적 중요도로 해석하지 않는다. 현재 기여는 이 작은 관계 분할의 학습상 유효성을 검증하는 것이다.
