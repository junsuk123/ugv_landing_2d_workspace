# 온톨로지–R-GAT PPO v3.19

## 최종 구조

- 입력: 공통 관측 $o_t\in\mathbb R^{12}$
- 노드/특징: 7개 × 6채널
- 관계/간선: 4유형, 16개
- hidden/relation/graph: 16/4/16
- readout: `grouped_factorized`
- Actor/Critic encoder: 독립
- 전체 파라미터: 6,101개

## 노드 특징

접근 곡면 오차와 closure:

$$
m=\tan(-\theta_C),\qquad e_c=e_x-mh,\qquad
v_c=v_{rel,x}-mv_z.
$$

영상·측위 confidence:

$$
c_G=\max(0,1-0.5\tau_G),\qquad
c_D=\max(0,1-0.5\tau_D).
$$

노드 $i$의 특징은 $x_i=[p_i,s_i,q_i,v_i,\tau_i,i/7]^\top$이다.

$$
\begin{aligned}
x_1&=[c_G(e_c^2+h^2)/2,\;c_Ge_c,\;c_Gh,\;0,\;0,\;1/7]^\top,\\
x_2&=[c_G(v_c^2+v_{rel,x}^2)/2,\;c_Gv_c,\;c_Gv_{rel,x},\;0,\;0,\;2/7]^\top,\\
x_3&=[c_G\hat v_{G,x}^2,\;c_G\hat v_{G,x},\;0,\;0,\;0,\;3/7]^\top,\\
x_4&=[c_Dv_z^2,\;c_Dv_z,\;0,\;0,\;0,\;4/7]^\top,\\
x_5&=[c_D(\sin^2\theta+\dot\theta^2)/2,\;c_D\sin\theta,\;c_D\dot\theta,\;0,\;0,\;5/7]^\top,\\
x_6&=[I_G,\;1-\tau_G,\;\cos\theta,\;1,\;\tau_G,\;6/7]^\top,\\
x_7&=[I_D,\;1-\tau_D,\;0,\;1,\;\tau_D,\;1]^\top.
\end{aligned}
$$

최종 특징은 $[-1,1]$로 제한한다. 모든 항은 등록된 12차원 $o_t$의 결정론적 함수이다. hidden truth, future state, reward와 outcome은 사용하지 않는다.

제곱 에너지는 `abs`/`max` 크기 특징의 모서리를 제거한다. $c_G,c_D$는 오래된 추정치를 연속적으로 낮추는 estimator-style weighting이며 행동 gate나 안전 guard가 아니다.

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

모든 노드에 `self` 간선을 추가해 총 16간선을 구성한다.

## Typed attention

$$
\ell_{ji}^{(r)}=\operatorname{LReLU}_{0.2}
\left(a_r^\top[W_rx_j\Vert W_rx_i\Vert e_r]\right),
$$

$$
\alpha_{ji}^{(r)}=\frac{\exp\ell_{ji}^{(r)}}
{\sum_{(k\to i,r')}\exp\ell_{ki}^{(r')}+10^{-9}},
$$

$$
h_i=\tanh\left(W_0x_i+b_0+
\sum_{(j\to i,r)}\alpha_{ji}^{(r)}W_rx_j\right).
$$

## Factorized grouped readout

$$
U_k=W_ch_k,\qquad
g_t=\tanh\left(b_g+\sum_{k=1}^{7}U_k\odot w_k\right)
\in\mathbb R^{16}.
$$

노드 정체성을 유지하면서 dense concatenation보다 적은 파라미터를 사용한다.

## PPO 결합

- Actor: graph 16 → 38 → 37 → 2
- Critic: graph 16 → 35 → 34 → 1
- encoder LR: $10^{-4}$
- graph pretraining/freeze/warmup: off/off/0
- temporal consistency weight: 0.03, 학습 전용
- raw bypass·relation residual·descent gate·inference guard: 없음

구현: `observationVectorGraph`, `contextSchema`, `relationForward`, `encoderForward`, `encoderBackward`, `FactorizedRelationalContextLayer`.
