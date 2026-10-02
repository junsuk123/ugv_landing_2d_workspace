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
| T09 bounded validation | passed | 24/24 tests and bounded three-arm run; long study not run |
| T10 docs/handoff | passed | root/project README, system/config/reward/module docs |

## Commands actually executed

```matlab
run_tests(false)
[cmp,t,cfg] = run_all(struct('executionMode','smoke','figureVisible',false, ...
    'animate',false,'saveResults',false));
```

Results:

- Existing pre-change baseline: 19/19 non-graphics tests passed.
- Final suite: 24/24 non-graphics tests passed in MATLAB R2025b.
- Bounded A/B/C smoke: completed one PPO iteration per arm with finite results.
- Smoke outcomes happened to be `SAFE_ABORT` for the single validation scenario
  in all three arms. This is expected from untrained/random policies and is not
  comparative performance evidence.

No long training, push, global MATLAB configuration change, process termination,
or real-vehicle action was performed.

## Post-handoff integration fixes

- `run_all` now defaults to `executionMode='full'`.
- All three V2 PPO arms use the same 2,500-iteration scratch schedule without
  behavior cloning. A training-only initial-height curriculum expands to the
  nominal scenario range; validation and test manifests remain unchanged.
- `run_finalTest` now loads the three V2 checkpoint names and no longer routes
  through the incompatible legacy environment.
- The V2 visualization supports unequal terminal times, fixed full-trajectory
  bounds, body-fixed-camera FOV geometry, CV/CA/CV phase backgrounds, R-GAT
  relation attention, learning curves, inference cost, and Monte Carlo mean
  trajectories with 1-sigma covariance ellipses.

## Compatibility changes

- `run_all` defaults to `planar_visibility_v2`; pass
  `experimentVersion='legacy_v1'` for the previous workflow.
- Algorithm version is `planar-visibility-ppo-v2`; old checkpoints are rejected.
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
