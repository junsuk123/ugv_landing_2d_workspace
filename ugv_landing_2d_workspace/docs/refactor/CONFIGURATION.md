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

Nine semantic nodes are followed by label-free `PolicyNode` and `ValueNode`.
Each node has the same 12-channel feature layout:

`primary, signedPrimary, secondary, signedSecondary, validity, confidence,
uncertainty, trend, urgency, remainingTime, bias, typeId`.

The exact raw `12 x 11` tensor goes to both the semantic-flat and R-GAT arms.
The R-GAT arm alone uses the typed directed edge table. No edge is silently
symmetrized. Query features contain bias/type only; they contain no action,
terminal outcome, reward, or future label.

## Random streams and fair comparison

Scenario, sensor, and policy random streams use separate deterministic seed
offsets. A/B/C must reuse the same scenario/sensor seeds. `taskFingerprint`
excludes representation-specific parameters and fails if the shared task differs.

`run_all` defaults to the full A/B/C PPO experiment. Use
`executionMode='smoke'` explicitly for a one-iteration bounded integration
check. The full study should use at least five independent training seeds and
checkpoint selection on validation seeds only.

Pure-RL training uses three common curricula for all three learned arms.
Iteration 1 scales the nominal 4--8 m height range to 0.4--0.8 m, allowing a
random policy to discover sparse but genuine safe touchdowns without a
teacher. Height and pad motion then expand to the full nominal distribution,
while the prolonged-loss timeout contracts from 12 s to the nominal 3 s.
Validation/test always use the nominal task; the curriculum never changes
evaluation or one method independently.

At nominal evaluation, `prolongedLoss=3 s` starts a common supervised recovery,
not an immediate terminal. The recovery follows only the causal pad-track
estimate while climbing/holding. Reacquisition clears the request; only a full
`backupDurationLimit=8 s` without reacquisition produces `SAFE_ABORT`.
