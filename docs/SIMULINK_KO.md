# v3.19 Simulink 선택 backend

## 범위

Simulink는 MATLAB 환경 함수와 동일한 동역학·센서·인지·12차원 관측·`reward_v5`·기계적 종료를 System block에서 호출한다. 환경·보상·종료 로직을 복제하지 않는다.

## 실행

```matlab
run(struct('trainingBackend','simulink'))
run_scenario('S3',struct('backend','simulink'))
```

생성 모델은 `results/.../models`에 저장하고 신호 형식은 `landing2d.simulink.signalCodec`을 단일 정의로 사용한다.

## 정책 변환

- 일반 PPO: RL Toolbox fully connected network
- v3.19: `FactorizedRelationalContextLayer`
- 7노드 graph, age confidence 0.5, `grouped_factorized` readout 유지
- Actor/Critic 합계 6,101 parameter 유지

## 검증 계약

`landing2d.simulink.verifyEquivalence`로 다음을 확인한다.

- reference-driver replay reward 차이 0
- observation 차이 0
- 폐루프 종료 사유 동일
- direct-policy 행동 적용 동일

최종 논문 수치는 MATLAB backend 결과만 사용한다. v3.19 Simulink 수치는 별도 등가성 실행을 통과한 경우에만 보고한다.
