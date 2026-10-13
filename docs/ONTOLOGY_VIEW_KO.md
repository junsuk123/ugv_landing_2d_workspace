# 최종 그림 안내

기준 폴더: `docs/assets/paper/latest_parameter_matched/`

| 파일 | 용도 |
|---|---|
| `parameter_matched_ontology_evidence.png/.pdf/.fig` | held-out 성능, 파라미터, return, 학습 곡선 종합 |
| `parameter_matched_consistency.png/.pdf/.fig` | validation 20×20 착륙률과 궤적 분산 |
| `parameter_matched_learning_curve.png/.pdf/.fig` | 현재 4,500-episode validation 학습 곡선 |
| `trajectory_mc_world_absolute.png/.pdf/.fig` | V2015 절대 착륙 궤적, pad-relative spread, 성공률 |
| `current_pipeline.svg` | 최종 v3.19 공정 비교 파이프라인 |
| `current_ontology.svg` | 7노드·4관계·16간선 온톨로지 |

색상은 일반 PPO 파랑, v3.19 보라로 통일한다. Monte Carlo 왼쪽 가로축은 실제 m를 유지하고 표시 종횡비만 0.15배이다. 패드는 실제 폭 직사각형이다.

수치 원자료는 같은 폴더의 `parameter_matched_ontology_summary.csv`, `heldout_test_v319.csv`, `validation_trajectory_robustness_v319.csv`, `validation_per_seed_v319.csv`, `trajectory_mc_world_absolute_summary.csv`를 사용한다.
