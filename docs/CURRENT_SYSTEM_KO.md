# 현재 시스템·실험 단일 명세

## 1. 최종 범위

- 실험: `planar_visibility_v2`
- 제안 모델: 온톨로지–R-GAT PPO v3.19
- 공식 비교군: `ppo`, `onto_rgat_ppo`
- 진입점: `run.m`, `run_scenario.m`, `run_live.m`, `run_trajMC.m`
- 학습 backend: MATLAB PPO 기본, Simulink 선택
- 최종 결과 범위: 2차원 $x$–$z$, train seed 1
- 비교 원칙: 환경·센서·관측 원자료·보상·행동·종료·학습 예산 동일, Actor/Critic 상태 표현만 상이

`shuffled_rgat_ppo`는 관계 절제 실험 구현으로만 남으며 최종 비교·수치·그림에 포함하지 않는다.

## 2. 환경과 행동

| 항목 | 값 |
|---|---:|
| 물리/정책 주기 | 0.01/0.10 s |
| 최대 임무 시간 | 70 s |
| 초기 상대 고도 | 4–8 m |
| UGV 초기 속도 | 0.5–2.5 m/s |
| UGV 가속도 | 0.3–1.5 m/s² |
| 정책 행동 | `[a_x,a_z]` |
| 행동 한계 | 2.5/2.0 m/s² |
| 착륙 위치 한계 | pad half width 0.5 m |
| 착륙 속도 한계 | 수평 0.35, 수직 0.30 m/s |
| 자세/각속도 한계 | 5°, 10°/s |

평면 정책은 `direct_policy_v1`이다. 정책 명령을 안전 감독기·착륙 승인·SAFE_ABORT guard가 수정하지 않는다. 접촉은 footprint, 상대속도, pitch와 pitch-rate의 기계적 조건으로 판정한다.

## 3. 공통 12차원 관측

$$
o_t=[e_x,h,v_{rel,x},\hat v_{G,x},v_z,\sin\theta,\cos\theta,\dot\theta,
I_G,\tau_G,I_D,\tau_D]^\top.
$$

마커 코너→평면 PnP→등속 KF로 UGV 위치·속도를 추정하고, 드론은 융합 측위를 사용한다. 미검출 시 KF 예측만 수행한다. 절대 수평 위치, UGV 참값, 미래 상태, reward, outcome, tracker 판단과 감독기 문맥은 정책 입력에서 제외한다.

- 일반 PPO: $o_t$ 직접 입력
- v3.19: 동일 $o_t$의 결정론적 7노드 graph만 입력
- 입력 표준화: 비활성
- raw observation bypass: 없음

## 4. v3.19 온톨로지 특징

접근 곡면:

$$
m=\tan(-\theta_C),\qquad e_c=e_x-mh,\qquad
v_c=v_{rel,x}-mv_z.
$$

age 기반 연속 confidence:

$$
c_G=\max(0,1-0.5\tau_G),\qquad
c_D=\max(0,1-0.5\tau_D).
$$

노드 특징은 $[primary,signed,secondary,validity,age,typeId]^\top$이며 최종 $[-1,1]$로 제한한다.

| 노드 | 최종 물리 특징의 핵심 |
|---|---|
| RelativePosition | $c_G[\tfrac12(e_c^2+h^2),e_c,h]$ |
| RelativeVelocity | $c_G[\tfrac12(v_c^2+v_{rel,x}^2),v_c,v_{rel,x}]$ |
| PadVelocity | $c_G[\hat v_{G,x}^2,\hat v_{G,x},0]$ |
| VerticalMotion | $c_D[v_z^2,v_z,0]$ |
| Attitude | $c_D[\tfrac12(\sin^2\theta+\dot\theta^2),\sin\theta,\dot\theta]$ |
| VisionQuality | $[I_G,1-\tau_G,\cos\theta,1,\tau_G]$ |
| NavigationQuality | $[I_D,1-\tau_D,0,1,\tau_D]$ |

물리 노드에는 품질 스칼라를 반복 삽입하지 않고 전용 품질 노드와 `conditions` 관계를 사용한다. 제곱 에너지는 `abs`/`max`의 비미분 모서리를 없애며, confidence는 graph 입력을 연속적으로 약화할 뿐 행동을 차단하거나 재작성하지 않는다.

## 5. 관계와 R-GAT

- 노드: 7개
- 특징: 노드당 6채널
- 관계: `informs`, `conditions`, `couples`, `self`
- 간선: 의미 간선 9개 + 자기 간선 7개 = 16개
- hidden/relation/graph dimension: 16/4/16
- readout: `grouped_factorized`

$$
\ell_{ji}^{(r)}=\operatorname{LReLU}_{0.2}
\left(a_r^\top[W_rx_j\Vert W_rx_i\Vert e_r]\right),
$$

$$
\alpha_{ji}^{(r)}=
\frac{\exp\ell_{ji}^{(r)}}{\sum_{(k\to i,r')}\exp\ell_{ki}^{(r')}+10^{-9}}.
$$

각 노드를 분리해 유지하는 readout:

$$
U_k=W_ch_k,\qquad
g_t=\tanh\left(b_g+\sum_{k=1}^{7}U_k\odot w_k\right)
\in\mathbb R^{16}.
$$

| 망 | 일반 PPO | v3.19 |
|---|---|---|
| Actor | 12–48–48–2 | R-GAT–16–38–37–2 |
| Critic | 12–48–48–1 | R-GAT–16–35–34–1 |
| 전체 파라미터 | 6,101 | 6,101 |

Actor와 Critic encoder는 독립이다.

## 6. 학습

| 항목 | 값 |
|---|---:|
| PPO update × episode | 750 × 6 = 4,500 |
| epoch/minibatch | 8/256 |
| Actor/Critic/R-GAT LR | 2e−4/5e−4/1e−4 |
| clip/GAE λ | 0.2/0.95 |
| entropy/gradient norm | 0.004/1.0 |
| v3.19 temporal consistency weight | 0.03 |

temporal consistency는 on-policy 연속 decision의 결정론적 `tanh(mean)` 차이를 raw-state proximity로 가중한다. PPO 학습 손실에만 작용하며 추론 시 메모리·재귀 상태·후처리를 추가하지 않는다.

공통 성능 curriculum, episode 난수 흐름과 training-only descent-prefix를 사용한다. prefix 구간은 PPO transition에서 제외하며 평가에는 사용하지 않는다. checkpoint는 validation으로만 고르고 held-out test seed는 선택에 쓰지 않는다.

## 7. 최종 평가

| 평가 | 일반 PPO | v3.19 |
|---|---:|---:|
| Held-out 착륙, n=100 | 95% | **98%** |
| Held-out unsafe | 0% | 0% |
| Held-out timeout | 5% | **2%** |
| Held-out return | 31.8186 | **33.4215** |
| Validation 착륙, 20×20 | 93.50% | **98.75%** |
| Validation 평균 위치 분산 | 4.116811 | **0.009430 m²** |
| V2015 착륙, n=1,000 | 70.2% | **100.0%** |
| V2015 평균 위치 분산 | 66.732568 | **0.002233 m²** |

Held-out는 일반화 임무 성능, validation 20×20은 여러 물리 조건의 반복 분산, V2015는 고정된 어려운 조건의 sensor-noise 스트레스 시험이다.

## 8. 최종 시각화 계약

`run_trajMC`의 왼쪽 패널은 월드 절대 궤적 $(x_D,z_D)$이다. 가로축 수치는 실제 m를 유지하고 `horizontalDisplayScale=0.15`로 표시 비율만 압축한다. 패드는 실제 폭 직사각형으로 표시한다. 분산 수치는 움직이는 패드 기준 오차를 측정해야 하므로 pad-relative frame에서 계산한다.

최종 수치와 플롯: [VALIDATION_KO.md](VALIDATION_KO.md), [latest_parameter_matched](assets/paper/latest_parameter_matched/README.md).
