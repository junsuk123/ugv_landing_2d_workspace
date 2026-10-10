# 평면 공통 관측

## 정의

정책 입력은 `landing2d.observation.capture`와 `toVector`가 생성하는 12차원 `minimal_common_observation_v3`.

$$
o_t=[e_x,h,v_{rel,x},\hat v_{G,x},v_z,\sin\theta,\cos\theta,\dot\theta,
I_G,\tau_G,I_D,\tau_D]^T.
$$

| 순서 | 필드 | 의미 |
|---:|---|---|
| 1 | `relative_x` | 추정 UGV 기준 수평 상대 위치 |
| 2 | `relative_height` | 추정 패드 기준 드론 고도 |
| 3 | `relative_vx` | 추정 수평 상대속도 |
| 4 | `ugv_vx` | UGV 수평 속도 추정 |
| 5 | `drone_vz` | 드론 수직 속도 |
| 6–8 | `sinTheta`, `cosTheta`, `pitchRate` | 드론 자세 |
| 9–10 | `visionUpdated`, `visionAge` | 영상 보정 여부·경과시간 |
| 11–12 | `navigationValid`, `navigationAge` | 융합 측위 유효도·경과시간 |

## 생성 경로

1. 마커 코너 검출과 왜곡 보정
2. 평면 PnP와 좌표 변환 $^WT_G={}^WT_B{}^BT_C{}^CT_P{}^PT_G$
3. 등속 KF의 UGV 위치·속도 갱신, 미검출 시 예측
4. 융합 측위와 직전 결정 기록 결합
5. 드론 현재 $x$를 원점으로 한 상대 좌표 벡터화

카메라 내부행렬·왜곡·장착 변환·마커 기하·정규화 척도는 정적 문맥 $\Gamma$이며 관측 벡터에 포함되지 않음.

## 정보 경계

허용: 현재/과거 마커 측정, 인과적 UGV 추정, 드론 융합 측위, 원본 timestamp 기반 age.

금지: UGV 참값, 미래 상태, reward, outcome, 성공 라벨, tracker 판단 특징, 감독기 모드, 착륙 승인, 절대 수평 위치.

일반 PPO는 12차원 벡터 직접 사용. 온톨로지–R-GAT PPO는 동일 벡터의 결정론적 7노드 그래프만 사용. 추가 센서 입력이나 raw bypass 없음.

## 잡음 재현성

- `time_indexed_v1` 외생 잡음표
- reset 시 전용 난수열로 1회 생성
- 결정 시점·물리 시점으로 색인
- 검출 여부와 조기 종료에 따라 난수 소비량이 바뀌지 않음
- 평가의 `sensorNoiseScale`은 같은 표준정규 표본에 배율만 적용

## 구현

- 설정: `landing2d.config.defaultCommonObservationConfig`
- 생성: `landing2d.observation.capture`
- 스키마: `landing2d.observation.vectorSchema`
- 벡터화: `landing2d.observation.toVector`
- 그래프 변환: `landing2d.graphstate.observationVectorGraph`
