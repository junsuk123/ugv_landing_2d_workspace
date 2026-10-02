# Final refactor report

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
| T07 compact ontology | passed | 9 semantic + 2 query nodes, 6 typed relations, C01–C12 support |
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
- Algorithm version is `planar-visibility-ppo-v2.3`; old checkpoints are rejected.
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
