# Simulink backend

## 범위

MATLAB 환경 함수와 동일한 동역학·센서·인지·12차원 관측·reward·기계적 종료 로직을 Simulink System block에서 호출. 로직 복제 금지.

## 실행

```matlab
run(struct('trainingBackend','simulink'))
run_scenario('S1',struct('backend','simulink'))
```

모델은 `results/.../models`에 생성. `landing2d.simulink.signalCodec`이 신호 형식의 단일 정의.

## 정책 변환

- PPO MLP: RL Toolbox fully connected network
- 온톨로지–R-GAT: `FactorizedRelationalContextLayer`
- Actor/Critic 파라미터와 `grouped_factorized` readout 보존
- 전체 파라미터 6,101개 보존

## 등가성 결과

온톨로지–R-GAT checkpoint, seed 2001:

- MATLAB/Simulink 종료: 모두 SUCCESS
- replay reward 차이: 0
- replay observation 차이: 0
- reference driver reward/observation 차이: 0
- closed-loop 최대 reward 차이: $9.89\times10^{-6}$
- 결정 수: 192 동일

검증 함수: `landing2d.simulink.verifyEquivalence`.
