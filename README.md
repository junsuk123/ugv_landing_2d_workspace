# UGV Landing 2D — Planar Visibility PPO v2

MATLAB research simulator for landing on a continuously accelerating moving
platform under body-fixed-camera visibility loss. The primary controlled study
compares three PPO state representations while sharing the same scenario,
causal observation memory, two-axis action mapping, safety supervisor, reward,
and episode boundary:

| Arm | Actor/Critic input |
|---|---|
| A | 26-field named causal packet → MLP |
| B | compact ontology node features flattened without edges → MLP |
| C | the same node features + typed relations → two independent R-GAT encoders |

The environment remains planar: world `x-z`, with exactly two policy actions
requesting world-frame `[ax, az]`. Pitch and collective thrust are internal
lagged physical states, and the camera rotates with actual pitch. No imitation
learning, adaptive reward weighting, PBRS, gimbal action, or hidden pad truth is
used in the primary experiment.

## Quick start

Open MATLAB in `ugv_landing_2d_workspace/`:

```matlab
run_tests(false)                         % 24 non-graphics tests
run_all                                  % bounded A/B/C integration smoke
full_study_commands                      % print long-run commands only
```

`run_all` intentionally performs one PPO iteration per arm. This proves
integration only; it is not convergence or comparative-performance evidence.
An explicit long run is:

```matlab
run_all(struct('executionMode','full','rlRetrain',true))
```

The previous simulator remains available through:

```matlab
run_all(struct('experimentVersion','legacy_v1'))
```

## Primary pipeline

```text
CV–CA–CV pad + planar pitch/thrust drone
  -> body-fixed camera measurement
  -> shared causal pad-track memory (named 26-field packet)
  -> A: packet MLP | B: semantic-flat MLP | C: typed ontology R-GAT
  -> raw Gaussian command -> tanh -> requested [ax, az]
  -> common causal safety supervisor and lagged inner loop
  -> environment / contact / terminal event / common reward
```

The active ontology has nine semantic nodes, two label-free query nodes, and
six relation types. Every semantic node has an explicit directed path to both
`PolicyNode` and `ValueNode`; the flat control receives the identical raw node
feature tensor.

See [system specification](ugv_landing_2d_workspace/docs/refactor/SYSTEM_SPEC.md),
[configuration guide](ugv_landing_2d_workspace/docs/refactor/CONFIGURATION.md),
and [implementation report](ugv_landing_2d_workspace/docs/refactor/FINAL_REPORT.md).

## Status

- MATLAB R2025b: 24/24 non-graphics tests passed.
- Bounded `run_all` A/B/C smoke passed.
- No long PPO training was launched; no performance advantage is claimed.
- Simulation defaults are not identified vehicle parameters or a real-flight
  safety certificate.
