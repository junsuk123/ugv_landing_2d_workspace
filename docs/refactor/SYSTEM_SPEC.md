# 평면 시스템 명세

## 상태와 동역학

드론 상태 $[x,h,v_x,v_z,\theta,\dot\theta]$, UGV는 구간별 속도·가속 일정. 드론의 pitch 2차 응답과 thrust 1차 응답을 0.01 s로 적분.

## 센서

전방 하향 marker camera의 corner projection·왜곡·pixel noise·dropout. 평면 PnP와 등속 KF. 드론 navigation estimate 별도. 잡음은 시간 색인 외생 표본.

## 정책

결정 주기 0.10 s. 행동 $u_t\in[-1,1]^2$를 $[2.5,2.0]$ m/s² 가속도 한계로 변환. 평면은 direct application.

## 접촉·종료

SUCCESS는 pad footprint, $|v_{rel,x}|\le0.35$ m/s, $|v_z|\le0.30$ m/s, $|\theta|\le5^\circ$, $|\dot\theta|\le10^\circ$/s 동시 충족. 위반 접촉은 원인별 unsafe 종료. 70 s 도달 시 TASK_TIMEOUT.

## 정책 입력

12차원 causal common observation. 일반 PPO 직접 입력, R-GAT PPO는 7노드 그래프로만 입력.

## 학습·평가 분리

- train: 전용 episode stream, 공통 curriculum
- validation: checkpoint 선택
- test: 선택 이후 1회 held-out 평가
- consistency probes: 평가 전용, 학습 signature와 task fingerprint 밖

전체 상세: `docs/CURRENT_SYSTEM_KO.md`.
