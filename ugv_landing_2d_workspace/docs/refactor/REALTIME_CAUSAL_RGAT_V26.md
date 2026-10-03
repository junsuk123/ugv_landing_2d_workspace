# Real-time causal R-GAT PPO v2.6

## Objective

The v2.5 result showed that semantic-flat PPO outperformed the two-layer R-GAT,
while R-GAT was slower, collapsed exploration further, and triggered more
safety-supervisor overrides. Version 2.6 keeps the research hypothesis—typed
ontology relations directly shape policy state—but removes avoidable depth,
unused query nodes, homogeneous readout edges, and continuous optimization of
invariant knowledge.

## State and graph contract

All graph features are computed from the synchronized causal packet produced by
the online observation memory. The graph contains these nine nodes:

1. PadVisibility
2. PadMotion
3. DroneTranslation
4. DroneAttitude
5. RelativeTracking
6. TrackingCorrection
7. ViewRecovery
8. DescentEligibility
9. LandingInhibit

The graph uses 17 directed semantic edges plus 9 self edges. Five relation
types remain: `informs`, `affects_visibility`, `supports`, `inhibits`, and
`self`. Each node belongs to exactly one readout group:

| Group | Nodes |
|---|---|
| Perception | PadVisibility, ViewRecovery |
| Tracking | PadMotion, RelativeTracking, TrackingCorrection |
| Vehicle | DroneTranslation, DroneAttitude |
| Safety | DescentEligibility, LandingInhibit |

There are no PolicyNode/ValueNode placeholders and no `contributes` fan-in
bottleneck. Semantic-flat and graph arms receive the same 108 raw values.

## Lightweight encoder

For node feature matrix \(X_t\), relation type \(r\), and edge \(i\to j\):

\[
e_{ij}^{(r)}=\operatorname{LReLU}\!\left(
a_r^\top[W_r x_i\Vert W_r x_j\Vert E_r]\right),\qquad
\alpha_{ij}^{(r)}=\operatorname{softmax}_{i\in\mathcal N(j)}e_{ij}^{(r)}
\]

\[
h_j=\tanh\!\left(W_0x_j+b_0+
\sum_{(i,r)\in\mathcal N(j)}\alpha_{ij}^{(r)}W_rx_i\right)
\]

The four group means are concatenated and projected to the 32-dimensional
Actor/Critic input. The encoder has one layer, hidden width 16, and relation
embedding width 4.

## Fixed knowledge versus online adaptation

Masked-node pretraining optimizes \(W_r,E_r,W_0,b_0\) from current-time graph
states. PPO then freezes those invariant transforms. PPO updates only the
state-dependent attention scorer \(a_r\), grouped readout, and Actor/Critic
heads. Actor and Critic start from identical pretrained static transforms.

No optimization occurs during simulator inference. Runtime executes graph
construction, one relation forward pass, grouped pooling, and the Actor MLP.

## Leakage controls

- `assertCausalPacket` rejects any field outside the registered online packet.
- `contextGraph` does not read previous actions even though the common packet
  carries them for other components.
- Pretraining targets masked features from the same time step only.
- Pretraining metadata explicitly records no action, reward, outcome, future,
  or teacher use.
- Pretraining seeds must be in the train manifest and must not overlap
  validation or test manifests.
- Checkpoint selection uses 20 validation seeds; 100 held-out test seeds are
  evaluated only after training.

## Sequential evaluation

```matlab
run_graph_ablation(struct('executionMode','full','rlRetrain',true))
```

This runs semantic-flat, node-pool, single-relation GAT, and typed R-GAT in
order. The normal three-arm study remains:

```matlab
run_all(struct('executionMode','full','rlRetrain',true))
```

The common exploration floor is `minimumLogStd=-2.5`. Full v2.6 training must
be rerun because the new schema and encoder invalidate v2.5 checkpoints.
