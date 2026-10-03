# Final refactor report

## v2.7 semantic-residual R-GAT correction

The completed v2.6 held-out result was 78% success for semantic-flat versus 15%
for R-GAT. R-GAT produced 47% safe abort and 29% timeout, and its nominal
32-dimensional output had only about 2–3 effective dimensions. The lossy group
compression and frozen reconstruction backbone—not missing sensor information—
were the primary failure.

Version 2.7 keeps all 108 semantic-flat values unchanged and adds only four
R-GAT relation-context residuals. Actor/Critic base networks and PPO random
streams are paired exactly with semantic-flat. The base trains for 90% of the
run; it is then frozen while only the relational residual is fine-tuned. A
relational checkpoint must exceed the flat-equivalent validation anchor by a
configured margin. Bounded tests confirm exact flat/R-GAT equality before the
relation stage, 17,001 parameters, and approximately 0.18 ms policy inference.

## v2.6 real-time causal R-GAT update

The proposed encoder is now a one-layer 16-wide typed R-GAT over nine meaningful
nodes and 26 edges, followed by Perception/Tracking/Vehicle/Safety group
readout. Empty query nodes, homogeneous `contributes` edges, and the second
message-passing layer were removed. The resulting agent has 14,917 parameters.

Current-time masked-node pretraining uses train seeds only and explicitly has no
action, reward, outcome, future, teacher, or hidden-truth target. Actor and
Critic begin from the same pretrained static transforms; PPO freezes those
transforms and adapts only dynamic attention gates and small heads. All arms use
the same exploration floor. Selection now uses 20 validation seeds, and final
reporting uses 100 held-out test seeds.

The 26/26 non-graphics suite, A/B/C smoke, and four-stage ablation smoke pass.
The bounded proposed control-path profile was approximately 0.16 ms per 100 ms
decision period. This is integration/runtime evidence, not a performance claim;
a fresh v2.6 full training run is still required.

## Outcome

The primary path is now a versioned planar visibility experiment rather than the
legacy 11-D/double-integrator/reward-weight design. A/B/C share one reset/step
environment and differ only in policy/value state representation. Legacy code
and immutable reference tests remain available behind `legacy_v1`.

## Task record

| Task | Status | Main evidence |
|---|---|---|
| T00 audit/preserve | passed | isolated worktree, starting HEAD and baseline 19/19 recorded |
| T01 contracts/config | passed | versioned configs and named 26-field schema |
| T02 CV–CA–CV pad | passed | sampled/derived parameters, exact continuous evaluator, manifests |
| T03 pitch/thrust/camera | passed | lagged inner loop and actual-attitude projection |
| T04 causal memory | passed | timestamped track, uncertainty, masks, idempotence and 2 s differencing fixture |
| T05 safety/boundaries | passed | physical contact separated from authorization, interpolation, terminal enum |
| T06 common reward | passed | pure three-cost reward and one terminal bonus |
| T07 compact ontology | passed | v2.6: 9 semantic nodes, 26 edges, 5 relation types, 4 readout groups |
| T08 PPO integration | passed | raw command likelihood, variable-time GAE, stored raw graph, terminal stop |
| T09 bounded validation | passed | 26/26 non-graphics tests, bounded three-arm run, and scratch-PPO diagnostic |
| T10 docs/handoff | passed | root/project README, system/config/reward/module docs |

## Commands actually executed

```matlab
run_tests(false)
[cmp,t,cfg] = run_all(struct('executionMode','smoke','figureVisible',false, ...
    'animate',false,'saveResults',false));
```

Results:

- Existing pre-change baseline: 19/19 non-graphics tests passed.
- Final suite: 26/26 non-graphics tests passed in MATLAB R2025b.
- Bounded A/B/C smoke: completed one PPO iteration per arm with finite results.
- The former smoke result in which every arm immediately reached `SAFE_ABORT`
  exposed an irreversible abort latch, not comparative model performance.

No long training, push, global MATLAB configuration change, process termination,
or real-vehicle action was performed.

## Post-handoff integration fixes

- `run_all` now defaults to `executionMode='full'`.
- All three V2 PPO arms use the same 2,500-iteration scratch schedule without
  behavior cloning. The former 60-iteration legacy fine-tuning default is no
  longer used by the primary path.
- A common training-only curriculum begins 0.4--0.8 m above the pad, scales pad
  motion from 15% to 100%, and contracts the prolonged-loss threshold from 12 s
  to the nominal 3 s. Validation and test manifests/configuration remain nominal.
- Prolonged loss now starts a bounded common recovery maneuver instead of an
  immediate irreversible terminal. The supervisor climbs and follows only the
  causal pad-track estimate; reacquisition within 8 s clears the abort request,
  otherwise the episode terminates as `SAFE_ABORT`.
- A policy-invariant potential-difference term redistributes the shared reward
  toward measurable approach progress without changing A/B/C reward parity.
- Live/history logging now reports evaluation landing plus windowed training
  landing and safe-abort rates, rather than only the last six episodes.

## Sparse-reward correction (v2.3)

The completed v2.2 baseline checkpoint exposed a real objective collapse: only
one training success appeared in roughly 15,000 episodes, validation success
remained zero, and the final windows were 98.7--100% `SAFE_ABORT`. Inspection
found that the potential-difference term telescoped to a per-initial-state
constant, while the only successful terminal was too rare to compete with a
`-40` random-contact penalty.

Version 2.3 therefore:

- initializes the first pad-velocity estimate from causal own velocity under
  the matched-velocity reset contract, removing a false initial relative speed;
- fixes both height bounds so the curriculum really converges to 4--8 m;
- adds a common dense landing-readiness reward using safe closing/descent speed,
  relative speed, pitch, and pitch rate;
- advances a common curriculum only after three consecutive windows exceed 1%
  training landing rate, in 4% increments;
- tightens the training-only unsafe penalty from `-5` to the nominal `-40` as
  curriculum difficulty rises; evaluation is always nominal;
- replaces a non-executing `functiontests` wrapper with a directly executed
  regression test.

A 100-iteration baseline diagnostic produced landings in four training windows
(maximum 1.67%, mean 0.67%) and promoted curriculum from 0% to 4%. This verifies
that the all-abort sampling lock was broken, but it is not nominal convergence
evidence. Full 2,500-iteration v2.3 multi-arm training remains required.
- `run_finalTest` now compares causal V2 PN guidance with the V2 baseline and
  ontology R-GAT checkpoints and no longer routes through the incompatible
  legacy environment.
- The V2 visualization supports unequal terminal times, fixed full-trajectory
  bounds, body-fixed-camera FOV geometry, CV/CA/CV phase backgrounds, R-GAT
  relation attention, learning curves, inference cost, and Monte Carlo mean
  trajectories with 1-sigma covariance ellipses.

## Compatibility changes

- `run_all` defaults to `planar_visibility_v2`; pass
  `experimentVersion='legacy_v1'` for the previous workflow.
- Algorithm version is `planar-visibility-ppo-v2.7`; old checkpoints are rejected.
- Primary observation size is schema-derived 26, not legacy 11.
- Primary reward and termination semantics intentionally invalidate old policies.

## Changed-file summary

- Entrypoints: `run_all.m`, `run_planar_visibility.m`, `full_study_commands.m`.
- Versioned config: `+config/defaultPlanarVisibilityConfig.m`,
  `primaryConfig.m`, `validatePrimaryConfig.m`.
- Scenario/physics: new `+scenario/sampleParameters.m`,
  `evaluateTrajectory.m`, `createManifest.m`, and new planar dynamics functions.
- Causal sensing: named schema, body-fixed projection, measurement generation,
  event schedule, pad tracker, packet builder, and normalization under `+sensing`.
- Environment/safety/reward: common `reset/step`, supervisor, interpolated
  termination, task fingerprint, reward function, and audit fixtures.
- State/PPO: compact context schema/graph, behavior support values, V2 rollout,
  variable-time GAE, V2 evaluation/profiling, and context encoder modes.
- Verification/docs: five V2 test files, updated test runner, root/project README,
  AGENTS override, module map, and the files in `docs/refactor/`.

## Remaining limitations

- The estimator is deliberately small and ideal own-state measurements are used.
- Detector dropouts/pitch disturbances have interfaces but need a persisted event
  manifest before the full study.
- The supervisor is tested simulation logic, not a formal barrier-function proof
  or real-flight certificate.
- Full multi-seed training, validation selection, held-out tests, confidence
  intervals, runtime profiling, and the complete reward audit trajectory sweep
  have not been run.
- No universal optimality or guaranteed ontology advantage is claimed.

## Full-run failure analysis and correction (v2.4)

The completed 2,500-iteration v2.3 run did not validate performance. All three
held-out success rates were zero. Estimated training success was 0.68% for the
baseline, 0.98% for semantic-flat, and 0.69% for R-GAT. The curriculum stopped
at 8%, 16%, and 12%, respectively.

Three implementation defects explained the misleading final policies:

- checkpoint selection penalized `SAFE_ABORT` by 100 points but gave
  `TASK_TIMEOUT` no event penalty, so hovering until the deadline was preferred;
- low-curriculum checkpoints were eligible as final models even though they had
  only seen approximately 0.4--1.95 m starts rather than nominal 4--8 m starts;
- absolute per-step landing-readiness reward could be accumulated by hovering
  near the pad without making physical contact.

Version 2.4 corrects these issues by ordering checkpoint outcomes as
`SUCCESS > SAFE_ABORT > TASK_TIMEOUT > UNSAFE`, admitting final checkpoints
only at 100% curriculum, and replacing absolute readiness with signed readiness
progress. A hybrid curriculum now guarantees nominal-difficulty exposure while
retaining easy and bridge replay episodes to prevent touchdown forgetting. The
initial discovery range is 0.1--0.4 m, touchdown speed tolerance tightens from
2x to nominal, and all three learned arms share exactly the same schedule.

Verification after the correction:

- 26/26 non-graphics and 31/31 graphics-inclusive tests pass in MATLAB R2025b;
- a 120-iteration baseline diagnostic reached 13.3% windowed training landing,
  compared with at most 5.3% in the prior bounded configuration;
- the diagnostic reached 100% curriculum and selected iteration 110 at
  curriculum 100%, never the easy initial checkpoint;
- nominal held-out success remained zero in this intentionally short diagnostic,
  so complete 2,500-iteration v2.4 training is still required before making a
  comparative performance claim.

## Constant-altitude failure analysis and correction (v2.5)

The repeated partial descent followed by constant-height flight was a safety
intervention, not a plotting defect. Horizontal tracking error pushed the pad
outside the body-fixed camera FOV, confidence fell below the landing threshold,
and the common supervisor correctly cancelled further descent. Four upstream
defects made that behavior dominant: the 1.2 m/s^2 drone command limit was below
the 1.5 m/s^2 UGV acceleration range; the 100-Hz tracker amplified 2-cm position
noise into velocity/acceleration oscillation; V2 ignored the configured 4-cm
touchdown contact plane; and the combined goal cost allowed altitude progress to
mask growing horizontal error.

V2.5 restores horizontal authority (2.5 m/s^2), retunes the causal tracker,
uses the declared contact height, separates horizontal and vertical goal costs,
starts the UGV acceleration during easy episodes, and promotes curriculum using
success at the active difficulty rather than replay successes. It also removes
the cheap `SAFE_ABORT` shortcut: a visible `TASK_TIMEOUT` now ranks above a
self-induced abort, while every unsafe contact remains worst. Training history
and the live dashboard separately expose overall, active-curriculum, and nominal
landing rates.

With the same causal packet, a 20-seed PN feasibility check improved from 0%
landing / 80% safe abort to 65% landing / 15% safe abort. A deliberately
compressed 200-iteration scratch-PPO diagnostic did not establish nominal
convergence, but validation capture rose to 100%, safe abort fell to 21%, and a
landing occurred at 90% curriculum. The required next evidence is a fresh full
2,500-iteration v2.5 run followed by held-out multi-seed evaluation.
