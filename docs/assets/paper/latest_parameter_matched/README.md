# Latest parameter-matched results

2026-10-10 기준 일반 PPO와 온톨로지–R-GAT PPO의 6,101개 동일 파라미터 비교 결과 모음.

## 발표·논문용 파일

- `parameter_matched_ontology_evidence.*`: 임무 성능·모델 크기·추론시간 종합 그림
- `parameter_matched_consistency.*`: `C_valid`, `D_obs`, `J_policy` 비교 그림
- `parameter_matched_learning_curve.*`: 고해상도 학습 곡선
- `parameter_matched_unsafe_failures.*`: 위험 실패 궤적·종료 원인
- 각 CSV: 해당 그림의 원자료

## 로컬 원시 결과

Git 저장 용량 증가를 피하기 위해 MAT 체크포인트와 평가 결과는 아래 ignored 폴더에 별도로 모음.

`results/latest_parameter_matched/`

- `ppo_s01.mat`
- `onto_rgat_ppo_s01.mat`
- `planar_visibility_full.mat`
- `planar_visibility_full_summary.csv`
- `parameter_matched_consistency.mat`
- `parameter_matched_unsafe_failures.mat`

표준 실행 경로의 체크포인트와 결과 파일은 파이프라인 호환성을 위해 그대로 유지한 복사본임.
