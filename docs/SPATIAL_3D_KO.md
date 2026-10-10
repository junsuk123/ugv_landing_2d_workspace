# 3차원 선택 옵션

기본 연구 결과는 2차원 `planar_visibility_v2`. 3차원은 호환성 유지용 선택 옵션이며 최종 6,101개 파라미터 비교 결과에 포함하지 않음.

## 실행

```matlab
run(struct('spatialDimension',3))
run_scenario('S1',struct('spatialDimension',3))
run_live('S1',struct('spatialDimension',3))
```

## 별도 계약

- 행동 `[a_x,a_y,a_z]`
- causal sensor packet 기반 정책 입력과 packet graph
- 하향 원뿔 카메라
- tracker 기반 안전 감독기·착륙 승인 유지
- reward_v2와 action-change cost
- lateral roll 동역학·접촉 조건 추가
- 체크포인트·결과 `results/spatial3d` 분리

2차원 공통 관측·7노드 `minimal_sensor_v1`·direct-policy 결과를 3차원 옵션에 혼합하지 않음. 3차원 성능 수치는 현행 최종 결과로 보고하지 않음.
