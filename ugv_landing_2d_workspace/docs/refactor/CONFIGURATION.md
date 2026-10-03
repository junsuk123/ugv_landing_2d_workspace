# Configuration and data contracts

## Versions

| Contract | Value |
|---|---|
| Experiment | `planar_visibility_v2` |
| Observation | `causal_packet_v2` |
| Ontology | `compact_context_graph_v2` |
| Environment | `environment_v2` |
| Checkpoint algorithm | `planar-visibility-ppo-v2` |

`landing2d.config.primaryConfig` creates the primary experiment. Saved policies
hash the dynamics, sensing, observation schema, reward, supervisor, timing, PPO,
and graph settings. A legacy checkpoint therefore fails compatibility checks.

## Observation packet (26 fields)

| Group | Fields |
|---|---|
| own_motion | `h`, `vx`, `vz`, `sinTheta`, `cosTheta`, `pitchRate` |
| pad_track | `exEstimate`, `relativeVxEstimate`, `padVxEstimate`, `padAxEstimate`, `positionStd`, `velocityStd`, `accelerationStd`, `trackInitialized` |
| visibility | `detected`, `measuredBearing`, `bearingValid`, `detectionConfidence`, `timeSinceLastDetection`, `predictedBearing`, `predictedFovMargin` |
| task_memory | `remainingMissionTime`, `previousNormalizedActionX`, `previousNormalizedActionZ`, `landingInhibited`, `abortRequested` |

The dimension is derived by `sensing.observationSchema`; code must not duplicate
the number 26. Missing numerical measurements are zero-filled only alongside a
validity field. Signs are retained.

## Pad scenario

Default duration mode independently samples `v1,a2,T1,T2,T3` and derives
`v3=v1+a2*T2`. The three exact phases are CV, CA, CV. Position and velocity are
continuous and there is no fourth phase. `scenario.createManifest` provides
disjoint train/validation/test/stress seed lists and records SI units.

## Compact graph

Version 2.7 uses nine semantic nodes only. It has no query placeholders; four
explicit Perception/Tracking/Vehicle/Safety groups form the Actor/Critic readout.
Each node has the same 12-channel feature layout:

`primary, signedPrimary, secondary, signedSecondary, validity, confidence,
uncertainty, trend, urgency, remainingTime, bias, typeId`.

The exact raw `12 x 9` tensor goes to both the semantic-flat and R-GAT arms.
The R-GAT arm preserves that tensor as its base input and adds four typed
relation-context residuals. No edge is silently symmetrized. The graph contains
no action, terminal outcome, reward, future label, or hidden simulator truth.

## Random streams and fair comparison

Scenario, sensor, and policy random streams use separate deterministic seed
offsets. A/B/C must reuse the same scenario/sensor seeds. `taskFingerprint`
excludes representation-specific parameters and fails if the shared task differs.

`run_all` defaults to the full A/B/C PPO experiment. Use
`executionMode='smoke'` explicitly for a one-iteration bounded integration
check. The full study should use at least five independent training seeds and
checkpoint selection on validation seeds only.

Pure-RL training uses one shared performance-gated curriculum for all learned
arms. It starts at 0.4--0.8 m, 15% pad motion, a 12 s loss threshold, and a
training-only `-5` unsafe penalty. Three consecutive evaluation windows with at
least 1% training landings promote difficulty by 4%. Height lower and upper
bounds then converge to the nominal 4--8 m range, pad motion reaches 100%, the
loss threshold contracts to 3 s, and the unsafe penalty reaches `-40`.
Validation/test always use the nominal task and `-40` penalty.

At reset, the first causal pad-velocity prior equals measured own velocity,
consistent with the matched-velocity reset contract. This removes the former
false initial relative speed (for example `-2.44 m/s` while truth was zero).

At nominal evaluation, `prolongedLoss=3 s` starts a common supervised recovery,
not an immediate terminal. The recovery follows only the causal pad-track
estimate while climbing/holding. Reacquisition clears the request; only a full
`backupDurationLimit=8 s` without reacquisition produces `SAFE_ABORT`.
