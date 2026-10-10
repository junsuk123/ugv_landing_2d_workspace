# 현행 설정표

## 환경

| 키 | 값 |
|---|---:|
| schema | `planar_visibility_v2` |
| physics/policy dt | 0.01/0.10 s |
| max mission | 70 s |
| initial height | 4–8 m |
| action limit | 2.5/2.0 m/s² |
| action application | `direct_policy_v1` |

## PPO

| 키 | 값 |
|---|---:|
| updates × episodes | 750 × 6 |
| epochs/minibatch | 8/256 |
| actor/value LR | 2e-4/5e-4 |
| entropy | 0.004 |
| initial log std | −1.0 |
| evaluation interval | 25 updates |
| input normalization | disabled |

## R-GAT

| 키 | 값 |
|---|---:|
| observation source | `commonObservation` |
| feature version | `minimal_sensor_v1` |
| nodes/features | 7/6 |
| relations/edges | 4/16 |
| hidden/graph | 16/16 |
| readout | `grouped_factorized` |
| actor hidden | 38, 37 |
| critic hidden | 35, 34 |
| encoder LR | 1e-4 |
| pretraining/freeze/warmup | off/off/0 |

## Reward

| 항목 | 값 |
|---|---:|
| goal/view/control | 2/1/0.25 |
| readiness | 8 |
| goal/velocity/vertical potential | 4/4/4 |
| target descent speed | 0.4 m/s |
| SUCCESS/TIMEOUT/failure | +25/−12/−40 |

단일 정의: `primaryConfig.m`, `defaultPlanarVisibilityConfig.m`.
