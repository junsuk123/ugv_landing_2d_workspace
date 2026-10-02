# Common reward rationale

The primary experiment uses one fixed reward for all policy representations:

$$
r_t=B(e_t)-\frac{\Delta t}{T_{ref}}
\left(w_g c_{goal}+w_v c_{view}+w_u c_{control}\right)
+\frac{\Delta t}{T_{ref}}w_r q_{ready}
+ \gamma_{\Delta t}\Phi(s_{t+1})-\Phi(s_t),
$$

where $\Phi(s)=-w_p c_{goal}(s)$, $\gamma_{\Delta t}=\exp(-\Delta t/70)$,
and terminal states have zero potential. The shaping terms telescope under the
same variable-time discount used by PPO, so they redistribute progress credit
without changing the terminal-task optimum. The default is `wp=2.0`.

The three bounded running costs are

$$
\zeta=(e_x/L_x)^2+(h/L_h)^2,\qquad c_{goal}=\frac{\zeta}{1+\zeta},
$$

$$
c_{view}=\begin{cases}
\min(1,(\beta/(FOV/2))^2), & \text{valid detection},\\
1, & \text{otherwise},
\end{cases}
\qquad
c_{control}=\tfrac12\|a_{norm}\|_2^2.
$$

`q_ready` is an exponential landing-readiness score. It is largest when
horizontal error follows a bounded closing-speed target, vertical speed follows
a height-dependent safe descent target, and relative speed, pitch, and pitch
rate approach their touchdown limits. Unlike the potential difference, this is
a genuine dense task preference and therefore addresses the observed one-success
in roughly 15,000 episodes sparse-reward collapse.

Defaults are `Tref=70 s`, `Lx=3 m`, `Lh=4 m`, and running weights
`[goal,view,control,readiness]=[2,1,0.25,8]`. Terminal bonuses are success `+25`,
safe abort `-4`, timeout `-12`, and unsafe/unauthorized outcomes `-40`. During
training only, unsafe penalties start at `-5` and tighten with the common
performance-gated curriculum; evaluation always uses `-40`. The discount is
`exp(-dt/70 s)`.

This is a literature-informed engineering design, not an equation copied from a
paper and not a proof of optimal behavior. PPO supplies the policy optimization
method ([Schulman et al., 2017](https://arxiv.org/abs/1707.06347)); the explicit
safety/termination separation follows the general need to distinguish learned
control from safety constraints in safe-control benchmarks
([Yuan et al., 2022](https://arxiv.org/abs/2109.06325)). The thrust/attitude
separation mirrors the acceleration-to-thrust/attitude layering documented by
[PX4](https://docs.px4.io/v1.15/en/flight_stack/controller_diagrams), while the
values here remain unvalidated simulation defaults. Vision-based landing on a
moving platform is an established experimental problem
([Lee et al., 2020](https://arxiv.org/abs/2008.05699)), but that work does not
validate this simulator's estimator, reward, or safety thresholds.

Truth kinematics are isolated inside the simulator reward and evaluator. They are not an
actor, critic, ontology, estimator, or supervisor feature. There is no positive
attention reward, adaptive ontology weight, or remaining-horizon absorption
multiplier. All three learned arms use exactly the same readiness and terminal
reward. Terminal reward is paid exactly once.

The code verifies local bounds, terminal ordering, and representative fixtures;
the long audit-trajectory sensitivity study remains future validation work.
