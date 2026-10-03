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
are Perception, Tracking, Vehicle, and Safety. It uses one 16-wide relation
layer and four-dimensional relation embeddings; there are no empty query nodes.

## What changed in v2.6

- Causal masked-node pretraining uses **train seeds and same-time packet data
  only**. It does not use actions, rewards, outcomes, future samples, teacher
  commands, or hidden pad truth.
- Actor and Critic start from the same pretrained static relation transforms.
  During PPO those invariant transforms are frozen; only state-dependent
  attention gates, grouped readouts, and policy/value heads adapt.
- A common `minimumLogStd=-2.5` prevents exploration collapse in every PPO arm.
- Checkpoint selection uses 20 validation seeds. The final reported result uses
  100 held-out test seeds and never feeds back into checkpoint selection.
- The lightweight proposed agent has 14,917 parameters in the current config
  (below the semantic-flat agent's 15,317) and no runtime backpropagation.

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

See the [v2.6 design note](ugv_landing_2d_workspace/docs/refactor/REALTIME_CAUSAL_RGAT_V26.md),
[system specification](ugv_landing_2d_workspace/docs/refactor/SYSTEM_SPEC.md),
and [implementation report](ugv_landing_2d_workspace/docs/refactor/FINAL_REPORT.md).

## Verification status

- MATLAB R2025b: 26/26 non-graphics regression tests passed.
- A/B/C smoke and four-stage graph ablation smoke passed.
- Measured proposed policy path in the bounded smoke: approximately 0.16 ms per
  decision (machine-dependent; the policy period is 100 ms).
- v2.6 invalidates older checkpoints. A fresh 2,500-iteration run is required
  before making comparative performance claims.
- Simulation parameters are not a real-flight safety certificate.
