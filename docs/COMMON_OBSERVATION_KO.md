# 평면 공통 관측

## 정의

정책 입력은 `landing2d.observation.capture`와 `toVector`가 생성하는 10차원 공통 관측이다(`relational-policy-v2.3`부터).

$$
o_t=[e_x,h,v_{rel,x},\hat v_{G,x},v_z,\sin\theta,\cos\theta,\dot\theta,
I_G,\tau_G]^T.
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

- v2.2까지 있던 11–12번 `navigationValid`·`navigationAge`(융합 측위 유효도·경과시간)는 v2.3에서 뺐다.
  - 이 연구의 항법 추정(`landing2d.sensing.navigationEstimate`)은 항상 유효하고 결정 시각에 찍힌다. 그래서 두 값이 구조상 언제나 1과 0이었다. 실측(validation 20 에피소드, 2,988 결정)에서도 상수였다.
  - 세 비교군 모두에서 정보가 없는 입력이었다. 감지 기록 `O.drone`에는 그대로 남기고, 정책 입력에서만 뺐다.
- `visionUpdated`는 `visionAge = 0`과 구조상 같은 정보(측정 갱신 여부의 계단 표현)다. 상수가 아니고 결함도 확인되지 않아 유지한다.

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

일반 PPO는 10차원 벡터를 직접 사용한다. MLP 48-51 / 47-50으로 파라미터를 6,101개로 맞췄다. TOSM–R-GAT PPO와 관계 교란 R-GAT PPO는 같은 벡터의 결정론적 7노드×6채널 `tosm7_v2` 그래프만 사용한다(`TOSM7_ONTOLOGY_KO.md`). 추가 센서 입력이나 raw bypass는 없다.

## 잡음 재현성

- `time_indexed_v1` 외생 잡음표
- reset 시 전용 난수열로 1회 생성
- 결정 시점·물리 시점으로 색인
- 검출 여부와 조기 종료에 따라 난수 소비량이 바뀌지 않음
- 평가의 `sensorNoiseScale`은 같은 표준정규 표본에 배율만 적용 (학습 범위 밖 일반화의 noise 조건 ×2)
- 마커 검출 누락 중에도 벡터를 0으로 만들지 않는다. `visionUpdated = 0`, `visionAge`가 증가하고 추정기는 예측한다

## 구현

- 설정: `landing2d.config.defaultCommonObservationConfig`
- 생성: `landing2d.observation.capture`
- 스키마: `landing2d.observation.vectorSchema`
- 벡터화: `landing2d.observation.toVector`
- 그래프 변환: `landing2d.graphstate.observationVectorGraph`
