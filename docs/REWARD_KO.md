# 공통 보상 reward_v5

## 목적

전방 하향 카메라 광축을 유지하면서 이동 UGV의 수평 상대속도와 하강 속도를 동시에 맞춘다. 세 비교군(일반 PPO, TOSM–R-GAT PPO, 관계 교란 R-GAT PPO)에 완전히 동일하게 적용한다. 보상 변경은 비교군 공통이어야 하고, 근거와 측정 결과를 이 문서에 남긴다.

## 목표 곡면

$$
m=\tan(-\theta_C),\qquad e_x^*=mh.
$$

$$
v_{rel,x}^*=mv_z-0.35(e_x-mh),\qquad
v_z^*=-\min(0.4,0.8h).
$$

## 비용과 potential

$$
c_g=0.65q\!\left(\frac{e_x-mh}{3}\right)+
0.35q\!\left(\frac{h}{4}\right),\qquad
q(x)=\frac{x^2}{1+x^2}.
$$

$$
c_v=q\!\left(\frac{v_{rel,x}-v_{rel,x}^*}{1.0}\right),\qquad
c_z=q\!\left(\frac{v_z-v_z^*}{0.5}\right).
$$

$$
\Phi=-4c_g-4c_v-4c_z.
$$

Potential shaping은 $\gamma\Phi(s_{t+1})-\Phi(s_t)$이다. 원거리 수평 running goal에는 pseudo-Huber를 사용해 큰 오차에서도 복귀 gradient를 유지한다.

## 나머지 항

- running goal/view/control: 2/1/0.25
- readiness 변화: 8
- SUCCESS: +25
- TASK_TIMEOUT: −12
- 기계적 failure: −40

평면 direct-policy에는 SAFE_ABORT guard가 없다.
