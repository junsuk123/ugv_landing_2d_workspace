# Semantic-Constrained Residual R-GAT v2.8

## Why v2.8 was required

The v2.7 held-out run improved high-speed recovery but converted several
mechanically aligned approaches into `UNAUTHORIZED_CONTACT`. Inspection of the
saved policy showed that the learned Safety context added a negative vertical
residual while `landingInhibited=1`. Relation names such as `inhibits` were
descriptive metadata; an unconstrained neural transform could reverse their
intended action meaning.

## Action decomposition

The semantic-flat MLP remains the lossless base policy. The R-GAT produces four
small contexts: Perception, Tracking, Vehicle, and Safety. Its action correction
is split into horizontal recovery and vertical landing channels:

\[
\mu_x=\mu_{x,flat}+w_x^\top c,
\]

\[
\tilde{\Delta\mu_z}=w_z^\top c,
\qquad
\Delta\mu_z=\max(\tilde{\Delta\mu_z},0)
+e_{desc}\min(\tilde{\Delta\mu_z},0),
\]

\[
\mu_z=\mu_{z,flat}+\Delta\mu_z.
\]

Positive vertical commands are braking/climb and always pass. Negative commands
add descent and are multiplied by the causal `DescentEligibility` value
\(e_{desc}\in[0,1]\). The graph construction makes \(e_{desc}=0\) whenever
`LandingInhibit` is active. Gradients use the same piecewise slope, so training
and inference implement exactly the same constrained policy.

No reward, action label, future value, terminal outcome, scenario phase, or
simulator truth enters this gate.

## Safer selection and fresh evaluation

The checkpoint score shared by all arms is now

\[
J_{select}=1000p_{success}-2500p_{unsafe}-100p_{abort}
-10p_{timeout}+\bar R.
\]

Validation increases from 20 to 100 fixed validation seeds. Final reporting uses
the fresh test manifest `3001:3200`, which is disjoint from training,
validation, and stress manifests. Five independent PPO seeds can be run with
`run_multiseed_study`; it reports per-seed results and aggregate mean/standard
deviation.

## Diagnostics

Each V2 rollout now records the base policy mean, relation residual,
DescentEligibility, and semantic-gate activation. Evaluation reports mean
absolute relation residual and gate fraction. The live dashboard displays
validation unsafe rate next to landing, abort, and capture trajectories.

## Claim status

The implementation and bounded smoke tests are verified. Performance is not
verified until fresh v2.8 checkpoints complete multi-seed training and the new
test split is evaluated once.
