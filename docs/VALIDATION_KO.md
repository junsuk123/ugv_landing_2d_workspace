# 최종 검증 결과

## Held-out test 100회

| 지표 | PPO | 온톨로지–R-GAT PPO |
|---|---:|---:|
| 착륙률 | 95% | 96% |
| unsafe | 0% | 1% |
| timeout | 5% | 3% |
| 평균 return | 31.8186 | 32.3719 |
| 파라미터 | 6,101 | 6,101 |
| Actor inference | 0.035257 ms | 0.169261 ms |

## 일관성

| 잡음 배율 | PPO `C_valid` | R-GAT `C_valid` | PPO `D_obs` P95 | R-GAT `D_obs` P95 |
|---:|---:|---:|---:|---:|
| 0 | 78.003 | 82.925 | 0 | 0 |
| 0.5 | 77.735 | 81.821 | 0.038167 | 0.046716 |
| 1 | 77.329 | 80.799 | 0.074238 | 0.095983 |
| 2 | 74.895 | 76.812 | 0.137256 | 0.180597 |

공칭 pooled `J_policy`: PPO 4.0996, R-GAT 6.6914.

## 위험 실패

R-GAT 1건: seed 3076, `UNSAFE_CONTACT`, 종단 pitch-rate −11.643 deg/s, 허용 한계의 1.164배.

## 실행 검증

- `landing2d.orchestration.selfTest`: 13/13 PASS
- 표준 smoke pipeline: PASS
- S1: PPO/R-GAT 모두 SUCCESS
- Simulink 등가성: replay reward/observation 차이 0, driver 차이 0, closed-loop 최대 reward 차이 $9.89\times10^{-6}$, 종료 사유 동일

## 해석 한계

동일 파라미터에서 임무 성능과 `C_valid` 개선 확인. `D_obs`, `J_policy`, unsafe는 일반 PPO보다 불리. 학습 seed 1개이므로 신뢰구간·통계적 유의성·안전성 우월성 미확립.
