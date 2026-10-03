# UGV Landing 2D — Causal Ontology R-GAT PPO

MATLAB research simulator for landing on a continuously accelerating moving
platform under body-fixed-camera visibility loss. The controlled study keeps
the environment, causal sensing, action space, safety supervisor, reward, and
termination identical and changes only the Actor/Critic state representation.

| Arm | Actor/Critic input |
|---|---|
| Baseline | named causal observation vector → MLP |
| Semantic-flat | the same nine semantic-node features, flattened → MLP |
| Proposed | nine-node typed situation graph → lightweight R-GAT → grouped Actor/Critic heads |

The proposed graph has 9 meaningful nodes and 26 edges. Its four readout groups
are Perception, Tracking, Vehicle, and Safety. It uses one 8-wide relation
layer and four-dimensional relation embeddings; there are no empty query nodes.

## What changed in v2.8

- Causal masked-node pretraining uses **train seeds and same-time packet data
  only**. It does not use actions, rewards, outcomes, future samples, teacher
  commands, or hidden pad truth.
- The complete 108-value semantic-flat state now bypasses the graph unchanged.
  R-GAT adds four relation-context values through separate residual heads, so
  graph pooling can no longer erase the successful flat-policy information.
- The first 90% of PPO trains the exact semantic-flat base policy on paired
  random streams. The last 10% freezes that base and tunes only the relational
  residual. A relation checkpoint must clear a validation improvement margin.
- A common `minimumLogStd=-2.5` prevents exploration collapse in every PPO arm.
- Negative vertical relation residuals are gated by the causal
  `DescentEligibility` node. When landing is inhibited the graph cannot add
  descent, while braking/climb and horizontal recovery remain available.
- Checkpoint selection uses 100 validation seeds and weights unsafe contact 2.5
  times more strongly than success. Final reporting uses the fresh held-out
  test manifest `3001:3200` and never feeds it back into selection.
- The proposed agent has 17,001 parameters and no runtime backpropagation.

## Quick start

Open MATLAB in `ugv_landing_2d_workspace/`:

```matlab
run_tests(false)
run_all                                      % full A/B/C training and evaluation
run_all(struct('executionMode','smoke', ...  % bounded integration check
    'figureVisible',false,'animate',false,'saveResults',false))
run_graph_ablation(struct('executionMode','smoke', ...
    'figureVisible',false,'animate',false,'saveResults',false))
run_finalTest                                % compare saved final agents
run_multiseed_study(struct('executionMode','full')) % five PPO seeds
```

Force fresh full training after an algorithm change:

```matlab
run_all(struct('executionMode','full','rlRetrain',true))
```

The sequential ablation order is:

```text
semantic-flat → node pooling → single-relation GAT → typed R-GAT
```

This separates gains from semantic features, graph grouping/connectivity, and
typed relations instead of attributing all differences to the final model.

## Primary pipeline

```text
CV–CA–CV pad + planar pitch/thrust drone
  → body-fixed camera measurement
  → shared causal observation memory and synchronized packet
  → baseline vector OR nine-node ontology situation graph
  → one-layer relation attention and four-group readout
  → Gaussian command → tanh → requested [ax, az]
  → common causal safety supervisor and physical environment
  → common reward and terminal event
```

The information-leakage guard rejects unregistered packet fields. Train,
validation, and test manifests are disjoint. At deployment, the graph path is
forward-only; self-supervised reconstruction and PPO backpropagation are
training-time operations.

See the [v2.8 design note](ugv_landing_2d_workspace/docs/refactor/SEMANTIC_RESIDUAL_RGAT_V28.md),
[system specification](ugv_landing_2d_workspace/docs/refactor/SYSTEM_SPEC.md),
and [implementation report](ugv_landing_2d_workspace/docs/refactor/FINAL_REPORT.md).

## Verification status

- MATLAB R2025b: 26/26 non-graphics regression tests passed.
- A/B/C smoke and four-stage graph ablation smoke passed.
- Measured proposed policy path in the bounded smoke: approximately 0.18 ms per
  decision (machine-dependent; the policy period is 100 ms).
- v2.8 invalidates older checkpoints. A fresh 2,500-iteration run is required
  before making comparative performance claims.
- Simulation parameters are not a real-flight safety certificate.
