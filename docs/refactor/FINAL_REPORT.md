# 최종 연구 보고서

## 제안

이동 UGV 착륙의 최소 12차원 센서 관측을 물리 상태 5개 노드와 센서 품질 2개 노드로 분해하고, `informs`, `conditions`, `couples`, `self` 관계를 typed attention으로 추론하는 PPO 상태 표현.

## 공정 비교

- 일반 PPO와 동일한 환경·센서·관측 원자료·보상·행동·종료
- 동일 4,500 episode와 seed 흐름
- 동일 trainable parameter 6,101개
- 평면 direct policy, 보조 gate·guard·raw bypass 없음

## 구조

- 7노드 × 6채널
- 4관계, 16간선
- 16차원 relation state와 graph embedding
- 노드별 정보를 유지하는 factorized grouped readout
- Actor 16–38–37–2, Critic 16–35–34–1

## 결과

| 지표 | PPO | 제안 |
|---|---:|---:|
| 착륙 | 95% | 96% |
| unsafe | 0% | 1% |
| timeout | 5% | 3% |
| return | 31.819 | 32.372 |
| `C_valid` | 77.329% | 80.799% |
| `D_obs` P95 | 0.074238 | 0.095983 |
| `J_policy` | 4.0996 | 6.6914 |

## 결론

동일 모델 크기에서 임무 성능과 물리적 유효행동 일관성의 소폭 개선 확인. 잡음 민감도·명령 평활성·unsafe는 개선되지 않음. 단일 학습 seed이므로 통계적 우월성·안전성 보장 미확립. 후속 연구는 다중 seed 신뢰구간, pitch-rate 실패 감소, 잡음 안정화 정규화에 한정.

## 산출물

결과 그림·CSV·MATLAB FIG: `docs/assets/paper/latest_parameter_matched/`.
