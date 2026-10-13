# v3.19 평면 시스템 명세

## 상태와 동역학

드론 상태는 $[x,h,v_x,v_z,\theta,\dot\theta]$, UGV는 구간별 속도·가속 일정이다. pitch 2차 응답과 thrust 1차 응답을 0.01 s로 적분한다.

## 센서와 추정

전방 하향 marker camera의 corner projection, 왜곡, pixel noise와 dropout을 모델링한다. 평면 PnP와 등속 KF로 UGV 상태를 추정하고 드론 navigation estimate를 별도로 사용한다. 잡음은 `time_indexed_v1` 외생 표본이다.

## 정책

결정 주기 0.10 s. $u_t\in[-1,1]^2$를 `[2.5,2.0]` m/s² 축 한계로 변환한다. 평면은 direct application이다.

일반 PPO는 12차원 관측을 직접 사용하고 v3.19는 같은 관측에서 만든 7노드 graph만 사용한다. v3.19 graph에는 부드러운 제곱 에너지, age confidence weight 0.5, typed R-GAT과 factorized grouped readout을 사용한다.

## 접촉과 종료

SUCCESS는 pad footprint, $|v_{rel,x}|\le0.35$ m/s, $|v_z|\le0.30$ m/s, $|\theta|\le5^\circ$, $|\dot\theta|\le10^\circ$/s를 동시에 만족해야 한다. 위반 접촉은 원인별 unsafe 종료이며 70 s 도달은 TASK_TIMEOUT이다.

## 학습·평가 분리

- train: 전용 episode stream, 공통 curriculum, v3.19 temporal consistency weight 0.03
- validation: checkpoint 선택과 20×20 trajectory robustness
- held-out test: 선택 이후 seed 3001–3100 1회 평가
- V2015 Monte Carlo: validation hard case의 조건부 sensor-noise 스트레스 평가

상세: [현재 시스템 단일 명세](../CURRENT_SYSTEM_KO.md).
