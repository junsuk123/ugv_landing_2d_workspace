# 온톨로지–R-GAT PPO v3.19 최종 자산

2026-10-13 MATLAB 실행으로 생성·검증한 현재 최종 자료만 둔다.

## 그림

| 파일 | 설명 |
|---|---|
| `parameter_matched_ontology_evidence.*` | held-out 100회 성능, 6,101개 파라미터 정합, return, validation 학습 곡선 |
| `parameter_matched_consistency.*` | v3.19 validation 20×20 착륙률과 공간 궤적 분산 |
| `parameter_matched_learning_curve.*` | 현재 4,500-episode validation 학습 곡선 |
| `trajectory_mc_world_absolute.*` | V2015 1,000회 절대 착륙 궤적, pad-relative 분산, 착륙률 |
| `current_pipeline.svg` | 최종 v3.19 공정 비교 파이프라인 |
| `current_ontology.svg` | 최종 7노드·4관계·16간선 온톨로지 |

`.*` 그림 묶음은 PNG, PDF, MATLAB FIG를 뜻한다.

## 원자료

| 파일 | 내용 |
|---|---|
| `parameter_matched_ontology_summary.csv` | held-out 종합 그림 수치 |
| `parameter_matched_consistency.csv` | validation 20×20 종합 그림 수치 |
| `parameter_matched_learning_curve.csv` | validation 학습 곡선 |
| `heldout_test_v319.csv` | 최종 held-out 결과 |
| `validation_trajectory_robustness_v319.csv` | validation 20×20 집계 |
| `validation_per_seed_v319.csv` | validation seed별 결과 |
| `trajectory_mc_world_absolute_summary.csv` | V2015 1,000회 집계 |

## 그림 해석 계약

V2015 그림 왼쪽은 드론 월드 절대좌표이며 가로축 수치는 실제 m다. `horizontalDisplayScale=0.15`는 표시 종횡비만 바꾼다. 패드는 평균 접지 시점 UGV 위치에 실제 폭 직사각형으로 그린다. 오른쪽 spread와 CSV 분산은 움직이는 패드에 대한 pad-relative 좌표로 계산한다.

Held-out, validation 20×20, V2015 조건부 스트레스 결과는 서로 다른 평가 범위이므로 하나의 성공률로 합치지 않는다.
