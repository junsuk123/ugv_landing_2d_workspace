# Semantic-residual R-GAT PPO v2.7

## Evidence from the completed v2.6 run

The 100-seed held-out result was:

| Model | Success | Safe abort | Timeout | Mean return |
|---|---:|---:|---:|---:|
| Baseline | 73% | 13% | 4% | 17.64 |
| Semantic-flat | 78% | 12% | 0% | 19.86 |
| v2.6 R-GAT | 15% | 47% | 29% | -8.03 |

The v2.6 R-GAT output had an effective participation rank near 2–3 despite a
nominal dimension of 32. It compressed 108 raw semantic values through four
group averages, and its masked reconstruction loss remained 0.125. Freezing
that lossy backbone prevented PPO from recovering task-relevant detail.

## v2.7 architecture

The ontology encoder no longer replaces the semantic-flat input:

\[
z_t=[s_t^{\mathrm{flat}};c_t^{\mathrm{R\text{-}GAT}}],\qquad
\mu_t=f_{\mathrm{flat}}(s_t^{\mathrm{flat}})
      +W_{\mathrm{rel}}c_t^{\mathrm{R\text{-}GAT}}.
\]

The full 108-dimensional semantic state passes to the base Actor/Critic without
projection, pooling, or quantization. The one-layer R-GAT adds only four
Perception/Tracking/Vehicle/Safety context values through a separate residual
head. The base Actor/Critic has exactly the same initialization and computation
as semantic-flat PPO when the relation context is zero.

## Staged optimization

1. For the first 90% of PPO iterations, the R-GAT output is zero and its
   parameters are frozen. The proposed agent therefore learns the same base
   policy on the same episode/minibatch random stream as semantic-flat PPO.
2. For the final 10%, the complete raw Actor/Critic and exploration variance
   are frozen. Only the relation message transform, attention, four-value
   readout, and small residual heads are optimized.
3. The flat-equivalent checkpoint remains a candidate. A relational checkpoint
   replaces it only when validation selection score improves by at least 5.

This does not mathematically guarantee superior held-out performance, but it
removes the failure mode in which graph compression destroys an already useful
flat policy. Any claimed ontology gain must still be established by a fresh
full run and paired confidence intervals.

## Runtime and leakage

The current proposal has 17,001 parameters and measured about 0.16–0.18 ms per
100-ms policy decision in bounded local tests. Runtime remains forward-only.
Pretraining and PPO use no teacher action, future state, reward target, outcome
label, or hidden simulator truth in the graph input.

## Required experiment

```matlab
run_all(struct('executionMode','full','rlRetrain',true))
```

Older v2.6 checkpoints are rejected by the v2.7 algorithm signature.
