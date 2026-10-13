# 3차원 선택 옵션

현재 최종 연구 결과와 그림은 2차원 `planar_visibility_v2`의 v3.19에 한정한다. 3차원은 호환성 유지용 선택 옵션이며 held-out 95%/98%, validation 20×20, V2015 Monte Carlo 수치에 포함하지 않는다.

## 실행

```matlab
run(struct('spatialDimension',3))
run_scenario('S3',struct('spatialDimension',3))
run_live('S3',struct('spatialDimension',3))
```

## 별도 계약

- 행동 `[a_x,a_y,a_z]`
- causal sensor packet과 packet graph
- 하향 원뿔 카메라
- tracker 기반 감독기·착륙 승인
- `reward_v2`와 action-change cost
- lateral roll 동역학과 접촉 조건
- 체크포인트·결과 `results/spatial3d` 분리

2차원 12차원 공통 관측, 7노드 v3.19 feature, direct-policy 결과를 3차원 옵션에 혼합하지 않는다.
