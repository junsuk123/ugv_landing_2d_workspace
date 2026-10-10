# 공통 reward_v5

## 목적

전방 하향 카메라의 광축을 유지하면서 이동 UGV의 속도와 하강 속도를 동시에 맞추는 공통 보상. 두 비교군에 완전히 동일하게 적용.

## 목표 곡면

$$m=\tan(-\theta_C),\qquad e_x^*=mh.$$

$$v_{rel,x}^*=mv_z-0.35(e_x-mh).$$

$$v_z^*=-\min(0.4,0.8h).$$

## 비용과 potential

bounded goal cost:

$$c_g=0.65\,q\!\left(\frac{e_x-mh}{3}\right)+0.35\,q\!\left(\frac{h}{4}\right),
\quad q(x)=\frac{x^2}{1+x^2}.$$

수평·수직 속도 cost:

$$c_v=q\!\left(\frac{v_{rel,x}-v_{rel,x}^*}{1.0}\right),\qquad
c_z=q\!\left(\frac{v_z-v_z^*}{0.5}\right).$$

potential:

$$\Phi=-4c_g-4c_v-4c_z.$$

shaping은 $\gamma\Phi(s_{t+1})-\Phi(s_t)$ 형태. 수평 running goal에는 pseudo-Huber를 사용해 큰 오차에서도 복귀 gradient 유지.

## 나머지 항

- running goal/view/control 가중치 2/1/0.25
- readiness 변화 가중치 8
- SUCCESS +25
- TASK_TIMEOUT −12
- UNSAFE_CONTACT·MISSED_PAD_CONTACT·envelope failure −40

평면 direct-policy에서는 SAFE_ABORT guard가 없으므로 정상 평가 결과의 abort는 0. 3차원 옵션은 별도 reward_v2 계약.

## 검증 결과

동일 reward에서 PPO 95%, R-GAT PPO 96% held-out 착륙. reward 차이가 아니라 상태 표현 차이를 비교하도록 통제.
