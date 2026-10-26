> 2026-10-26: 현재 개발 후보의 구조·비교·실행 계약은 [관계 문맥 잔차 v5](RELATIONAL_RESIDUAL_V5_KO.md)를 따른다. 이 문서는 이전 minimal v3 설계의 재현 기록이다.

# 귀납적 편향: 공유 구조 → 학습 → 일반화 검증

2026-10-24 사용자 설명을 반영했다. 귀납적 편향은 별도 점수가 아니라 **어떤 정보를 연결하고 어떤 가중치를 공유하도록 설계했는가**에 있다. 그 유효성은 새로운 조건에서의 정책 성능으로 검증한다. 구조에 사전 가정을 반영한다는 관점은 [Battaglia 등의 관계적 귀납적 편향 논문](https://arxiv.org/abs/1806.01261)과 일치한다.

## 코드에서 구현되는 위치

1. minimal.features: 같은 $o_t$를 네 증거 노드에 중복 없이 배치한다.
2. minimal.schema: 관측 품질은 qualifiesEstimate, 목표 운동과 자기 운동은 informsMotion으로 RelativeState에 연결한다.
3. minimal.encoderForward: 입력 사영 $P$와 attention 파라미터를 공유한다. 같은 관계의 간선은 같은 $W_r$를 사용한다. v3.1은 두 집계에서도 같은 가중치를 공유하고 최종 RelativeState를 정책 입력으로 쓴다. 첫 집계의 품질 문맥이 두 번째 집계의 동적 query에 전달된다.
4. rl.policyLossGradient/valueLossGradient → minimal.encoderBackward → rl.ppoTrain의 encoderStep: 공통 손실의 기울기로 가중치를 갱신한다. 그래프의 연결과 관계 배치는 학습하지 않는다.

일반 PPO의 MLP도 여러 상태에서 가중치를 공유한다. 따라서 '귀납적 편향의 유무'가 아니라 **일반 MLP의 공유 방식과 관계별 공유 방식**을 비교한다. 각 방법의 전체 파라미터는 1,419개다.

## 공유가 업데이트에 반영되는 수식

Actor 손실을 최소화 형식으로 쓰면

$$g_t=f_{\theta_\pi}(o_t,G),\qquad \mu_t=\mathrm{MLP}_{\psi}(g_t),$$
$$\nabla_{\theta_\pi}L_\pi=\sum_{t\in B}\left(\frac{\partial g_t}{\partial\theta_\pi}\right)^T\frac{\partial L_\pi}{\partial g_t}.$$

서로 다른 상태의 학습 신호가 **같은 인코더 파라미터**에 누적된다. 목표 운동과 자기 운동 간선의 변환을 설명 목적으로 $W_T,W_D$로 풀어 쓴 손실을 $\widetilde L$이라 하면, 실제 모델은 $W_T=W_D=W_{\mathrm{motion}}$이고

$$\frac{\partial L}{\partial W_{\mathrm{motion}}}
=\left.\left(\frac{\partial\widetilde L}{\partial W_T}+\frac{\partial\widetilde L}{\partial W_D}\right)\right|_{W_T=W_D=W_{\mathrm{motion}}}.$$

각 항에는 메시지뿐 아니라 변환이 attention 점수에 미치는 경로도 포함한다. 어떤 간선의 기울기가 같은 행렬에 모이는지가 핵심이다. Shuffled는 이 공유 묶음을 바꾸고 처음부터 학습하는 대조군이다.

다른 관측 $\tilde o$의 출력 변화는 인코더에 대한 작은 SGD 한 단계의 1차 근사로

$$\Delta\mu(\tilde o)\simeq-\eta J_{\mu,\theta_\pi}(\tilde o)\nabla_{\theta_\pi}L_\pi$$

라고 설명할 수 있다. 이는 사용자 예시에서 공유 특징이 다른 상태의 Q값 업데이트를 연결하는 원리와 대응한다. **비선형 PPO에서 선형 Q함수의 특징 내적 식이 그대로 성립하지는 않는다.** 실제 코드는 gradient clipping과 Adam을 사용하므로 이 SGD 식을 실제 업데이트의 정확한 수치식으로 쓰지 않는다. PPO의 공통 clipped surrogate를 그대로 사용한다. [PPO 원 논문](https://arxiv.org/abs/1707.06347)

Actor와 Critic은 독립 인코더다. Critic 손실은 $\theta_V$를 갱신하며 Actor 인코더 $\theta_\pi$에 직접 더해지지 않는다. 현재 logσ는 상태 독립이므로 엔트로피의 직접 기울기는 logσ로 가고 인코더로 가지 않는다. 가치 추정이 advantage 구성에 미치는 영향과 직접 역전파를 구분한다.

## 이번 개선

앞선 개정은 평가·검증만 보완했다. 사용자의 성능 개선 요청에 따라 현재 **v3.1에서는 인코더 자체를 동적 attention·공유 두 홉으로 변경**했다. 원인 측정과 새 수식은 [v3.1 설계](MINIMAL_V31_DESIGN_KO.md)에 있다. 공통 PPO 손실·물리·센서·보상은 그대로다.

- minimal.checkLearningPath: 실제 PPO 손실에서 관계 행렬 192개와 attention 19개 미분을 유한차분으로 검사한다. 여러 관측의 기울기가 같은 파라미터에 누적되는지, Actor/Critic의 공통 Adam 경로에서 $W_{\mathrm{motion}}$과 $a$가 바뀌는지 검사한다. 원본 agent는 바꾸지 않는 TEST ONLY 검사다.
- minimal.generalization: 학습 범위 밖 가속·누락·잡음에서 동결 정책을 평가한다. 귀납적 편향 점수·추가 보상·추가 손실은 없다.
- [실험 설계](EXPERIMENT_DESIGN_KO.md): 주 지표는 세 OOD 조건의 동등 가중 착륙률, 주 비교는 TOSM−Shuffled와 TOSM−PPO다. 학습 효율은 보조 지표다.

검사 통과는 공유 구조에 학습 신호가 도달한다는 구현 근거다. attention/gradient의 크기나 공유 자체가 좋은 일반화를 보장하지 않는다. 부정적 전이의 가능성까지 비교 실험으로 판별한다.
