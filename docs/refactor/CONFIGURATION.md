# 온톨로지–R-GAT PPO v3.19 설정표

## 환경

| 키 | 최종 값 |
|---|---:|
| schema | `planar_visibility_v2` |
| physics/policy dt | 0.01/0.10 s |
| max mission | 70 s |
| initial height | 4–8 m |
| action limit | 2.5/2.0 m/s² |
| action application | `direct_policy_v1` |
| observation | 12-D `minimal_common_observation_v3` |

## PPO

| 키 | 최종 값 |
|---|---:|
| updates × episodes | 750 × 6 |
| epochs/minibatch | 8/256 |
| actor/value LR | 2e−4/5e−4 |
| entropy | 0.004 |
| initial log std | −1.0 |
| evaluation interval | 25 updates |
| input normalization | disabled |
| curriculum replay contract | `current` |

## R-GAT v3.19

| 키 | 최종 값 |
|---|---:|
| observation source | `commonObservation` |
| feature version | `minimal_sensor_v1`, v3.19 semantics |
| nodes/features | 7/6 |
| relations/edges | 4/16 |
| hidden/relation/graph | 16/4/16 |
| readout | `grouped_factorized` |
| actor hidden | 38, 37 |
| critic hidden | 35, 34 |
| encoder LR | 1e−4 |
| reliability age weight | 0.5 |
| temporal consistency weight | 0.03 |
| pretraining/freeze/warmup | off/off/0 |
| parameter count | 6,101 |

## Reward

| 항목 | 최종 값 |
|---|---:|
| version | `reward_v5` |
| running goal/view/control | 2/1/0.25 |
| readiness | 8 |
| goal/velocity/vertical potential | 4/4/4 |
| target max descent speed | 0.4 m/s |
| SUCCESS/TIMEOUT/failure | +25/−12/−40 |

## Monte Carlo 그림

| 키 | 기본값 |
|---|---:|
| trajectory frame | `world` |
| metric frame | `ugv_relative` |
| horizontal display scale | 0.15 |
| pad | actual-width rectangle |
| conditional scenario | validation seed 2015 |
| repeats | 1,000 |

단일 정의는 `primaryConfig.m`, `defaultPlanarVisibilityConfig.m`, `defaultCommonObservationConfig.m`, `run_trajMC.m`이다.
