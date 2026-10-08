# 정책 일관성·실행시간 우선순위 개선 검토

검토일: 2026-10-09  
활성 비교: 일반 PPO 대 온톨로지-RGAT PPO, train seed 1

## 반영한 변경

1. Monte Carlo 궤적 그림은 모든 결과의 world 좌표 혼합을 중단하고, 두 정책이 모두 성공한 paired seed만 패드 상대좌표로 표시한다. 타원은 정규화된 episode progress에서의 1-sigma 공분산이다.
2. 실행시간 그림은 Critic을 제외한 배포 경로만 표시한다. 일반 PPO는 관측 벡터화와 Actor, R-GAT은 관측 벡터화·graph 구성·Actor를 포함한다.
3. 평면 rollout은 환경이 이미 반환한 12차원 관측 벡터를 graph 구성에 재사용한다. 같은 구조체를 다시 벡터화하지 않는다.
4. 활성 구조와 맞지 않던 `Raw 108-D bypass` 시각화 문구를 12차원 공통 관측 → 7×6 graph → 32차원 graph embedding으로 교정했다.
5. 실행시간 측정에는 MATLAB JIT warm-up을 넣고 전체 비교의 반복 수를 25회에서 500회로 높였다.

## clipping 변경 실험과 기각

`crossTrack`과 `closureError`의 사후 clipping을 없애고 이론적 최대 범위로 선형 스케일링한 `minimal_sensor_v2`를 동일한 750 update × 6 episode로 학습했다. validation 선택 checkpoint는 update 725에서 착륙 94%, unsafe 0%였고, held-out test 100 seed에서는 착륙 92%, unsafe 2%, timeout 6%, 평균 return 29.817이었다.

이는 기존 `minimal_sensor_v1`의 held-out 착륙 95%, unsafe 0%, timeout 5%, 평균 return 30.406보다 나쁘다. 따라서 정보 보존의 이론적 장점만으로 변경을 채택하지 않았고 활성 설정과 공식 checkpoint는 v1으로 복원했다. 기각 실험은 `results/rgat_v2_validation.mat`과 `results/checkpoints/experiments/onto_rgat_ppo_s01_minimal_sensor_v2_rejected.mat`에 남겼다.

## 고정 test probe 일관성

동결 판정기: horizon 0.50 s, kappa 0.75. test probe 2,858개 중 적용 가능한 probe는 2,263개였다. 아래 값은 명목 센서 잡음 배율 1이다.

| 방법 | C_valid [%] | D_obs 평균 | D_obs P95 |
|---|---:|---:|---:|
| 일반 PPO | 77.329 | 0.031909 | 0.074238 |
| 온톨로지-RGAT PPO | 97.479 | 0.030912 | 0.069280 |

폐루프 test 100 seed의 pooled `J_policy`는 일반 PPO 4.0996, R-GAT 3.7366이었다. 두 정책의 착륙률은 모두 95%, unsafe는 모두 0%였다. episode별 단순 평균 jerk는 PPO 3.8553, R-GAT 3.8672로 거의 같으므로 pooled 값만으로 큰 우위를 주장하지 않는다.

이 결과는 R-GAT이 동일한 도달 가능 관측 문맥에서 더 자주 독립 유효 판정기의 허용 행동을 만들고, 관측 잡음에 대한 행동 변화가 소폭 작았다는 근거다. 반면 임무 성공률·return·착륙 시간에서 일반 PPO를 이긴 근거는 아니다. train seed가 하나이므로 `D_seed`와 알고리즘 수준의 분산 결론은 보류한다.

원자료: `results/consistency/priority_review_test.mat`

## 배포 실행시간

JIT warm-up 후 공식 재평가에서 일반 PPO는 0.0349 ms, R-GAT은 0.1705 ms였다. R-GAT은 약 4.9배 느리지만 절대 증가는 약 0.136 ms이며 100 ms 정책 주기의 약 0.17%다. 파라미터 수는 6,101 대 16,565다. 학습시간은 기존 공식 실행에서 약 875.5 s 대 1,382.5 s로 R-GAT이 약 58% 길었다.

## 남은 검증 한계

- 독립 train seed가 하나뿐이므로 `D_seed`는 계산할 수 없다.
- 관계 교란 checkpoint는 현재 학습 서명과 호환되는 것이 없어 이번 공식 비교에 넣지 않았다.
- 다음 통계 단계는 최소 5개 train seed와 3개 graph seed의 관계 교란 절제 실험이다. test seed는 checkpoint 선택에 사용하지 않는다.
