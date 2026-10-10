# 최소 관측 온톨로지–R-GAT

## 구조

- 입력: 공통 관측 $o_t\in\mathbb R^{12}$
- 노드: 7개
- 노드 특징: 6채널
- 관계: 4유형
- 간선: 의미 간선 9개 + 자기 간선 7개
- hidden/graph embedding: 16/16
- readout: `grouped_factorized`

## 노드와 특징

노드: RelativePosition, RelativeVelocity, PadVelocity, VerticalMotion, Attitude, VisionQuality, NavigationQuality.

특징 열:

$$x_i=[p_i,s_i,q_i,v_i,\tau_i,i/7]^T.$$

전방 카메라 접근 곡면의 cross-track과 closure:

$$m=\tan(-\theta_C),\quad e_c=e_x-mh,\quad v_c=v_{rel,x}-mv_z.$$

모든 $x_i$는 `o_t`만으로 계산되고 $[-1,1]$로 제한.

## 관계 배치

| 출발 | 도착 | 관계 |
|---|---|---|
| PadVelocity | RelativeVelocity | informs |
| RelativeVelocity | RelativePosition | informs |
| VisionQuality | RelativePosition | conditions |
| VisionQuality | RelativeVelocity | conditions |
| NavigationQuality | VerticalMotion | conditions |
| NavigationQuality | Attitude | conditions |
| RelativePosition | VisionQuality | couples |
| Attitude | VisionQuality | couples |
| VerticalMotion | RelativePosition | couples |

각 노드에 `self` 추가.

## Typed attention

$$q_{ij}^{(r)}=\operatorname{LReLU}(a_r^T[W_rh_i\Vert W_rh_j\Vert e_r]),$$

$$\alpha_{ij}^{(r)}=\frac{\exp q_{ij}^{(r)}}{\sum_{(k,r')\in\mathcal N(j)}\exp q_{kj}^{(r')}}.$$

$$z_j=\sum_{(i,r)\in\mathcal N(j)}\alpha_{ij}^{(r)}W_rh_i.$$

구현의 leaky-ReLU 기울기 0.2. 관계 embedding 차원 4. local transform과 typed message를 결합한 단일 관계 층.

## Factorized grouped readout

7개 노드를 개별 그룹으로 유지:

$$U_k=W_ch_k,$$

$$g=\tanh\left(b_g+\sum_{k=1}^{7}U_k\odot w_k\right),\quad g\in\mathbb R^{16}.$$

$W_c\in\mathbb R^{16\times16}$, $W_n=[w_1,\ldots,w_7]\in\mathbb R^{16\times7}$. 평균 pooling에 의한 노드 정보 소실을 피하면서 dense concatenation보다 적은 파라미터 사용.

## PPO 결합

- Actor: graph 16 → 38 → 37 → 2
- Critic: graph 16 → 35 → 34 → 1
- Actor/Critic encoder 독립
- 전체 6,101개, 일반 PPO와 동일
- raw bypass·relation residual·descent gate·inference guard 없음

구현: `contextSchema`, `observationVectorGraph`, `relationForward`, `encoderForward`, `encoderBackward`, `FactorizedRelationalContextLayer`.
