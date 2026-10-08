# 공통 관측 $o_t=[G_t;D_t;H_t]\in\mathbb R^{24}$

## 요약

- 핵심: 인지 모듈의 최종 출력을 착륙 패드를 운반하는 UGV의 위치·속도 추정값으로 정의, 드론과 UGV를 같은 물리량으로 비교
- 구성: UGV 추정 상태 $G_t$ 6 + 드론 융합 측위 $D_t$ 9 + 직전 운동 기록 $H_t$ 9 = 24차원, 마커 개수와 무관한 고정 차원
- 인지 경로: ArUco 코너 → 마커 보드 평면 PnP → 드론 측위·장착 관계로 로컬 UGV 위치 관측 → 등속 칼만 필터
- 미검출 처리: 참값 미사용, 예측만 수행, 영상 보정 여부·경과시간으로 표시
- 환경 연동: 같은 UGV 추정이 안전 감독기·착륙 승인을 구동, 평면 실험의 카메라는 마커 카메라 하나, 드론은 패드가 광축 위에 놓이는 위치에서 시작
- 부가 정보 분리: 카메라 내·외부 파라미터, 마커 구성·기하, UGV 장착 관계, 추정기·좌표계·정규화 설정은 $\Gamma$, 관측 벡터 미포함
- 범위: 평면 계약(x–z 운동, 드론 pitch) 전용, UGV는 수평 지면 직선 주행 가정(pitch·pitch rate 0), 버전 `common_observation_v2`
- 비교 원칙: 기준 강화학습과 온톨로지–R-GAT에 동일한 관측 생성 규칙·추정기·오차 설정·$\Gamma$ 제공
- 정책 입력: 2차원 세 비교군(일반 PPO·온톨로지-RGAT PPO·관계 교란 RGAT PPO) 공통, 일반 PPO는 24차원 벡터, RGAT 비교군은 같은 $o_t$에서 만든 문맥 그래프 (`landing2d.graphstate.observationGraph`)
- 계약: `experiment.commonObservation`이 task fingerprint·학습 서명에 포함, 평면 계약 변경으로 기존 2차원 체크포인트 재학습 필요
- 3차원 옵션: 공통 관측 제거, 하향 원뿔 카메라·패드 바로 위 시작·tracker 기반 감독기 유지 (수치·fingerprint·서명 불변)

## 1. 상태 정의

- 좌표: 모든 위치·속도는 동일한 로컬 좌표계 $W$ ($x$ 주행 방향, $z$ 위쪽)

| 상태 | 드론 | UGV |
|---|---|---|
| 위치 | $\hat x_D,\hat z_D$ | $\hat x_G,\hat z_G$ |
| 속도 | $\hat v_{Dx},\hat v_{Dz}$ | $\hat v_{Gx},\hat v_{Gz}$ |
| 피치 | $\hat\theta_D$ | 수평 주행 가정으로 고정, 정책 입력 제외 |
| 피치 각속도 | $\hat\omega_D$ | 0으로 고정 |
| 추정 원천 | 융합 측위 | 마커 관측·드론 측위·시간 이력 |

- UGV 기준점: 패드 중심 아래 지면, 착륙 목표와 구분

$$
\mathbf p^W_{\mathrm{landing}}=\mathbf p^W_G+{}^WR_G\,\mathbf r_{G\rightarrow P},\qquad
{}^WR_G=I,\quad \mathbf r_{G\rightarrow P}=[0,\;0.6]^\top\,\mathrm m
$$

- UGV 형식: 실제 $z_G$ 일정·$v_{Gz}=0$이어도 추정 결과의 위치 2축·속도 2축 형식 유지, 평면 조건의 추정기 강제 적용 없음

## 2. 관측 벡터

| 인덱스 | 이름 | 내용 | 그룹 |
|---:|---|---|---|
| 1–2 | `ugv_x`, `ugv_z` | $\hat x_G,\hat z_G$ | $G_t$ |
| 3–4 | `ugv_vx`, `ugv_vz` | $\hat v_{Gx},\hat v_{Gz}$ | $G_t$ |
| 5 | `ugv_visionUpdated` | $m^{vision}_t$: 현재 주기에 유효한 영상 측정으로 보정 여부 | $G_t$ |
| 6 | `ugv_visionAge` | $\tau^{vision}_t$: 마지막 영상 보정 후 경과시간 | $G_t$ |
| 7–8 | `drone_x`, `drone_z` | $\hat x_D,\hat z_D$ | $D_t$ |
| 9–10 | `drone_vx`, `drone_vz` | $\hat v_{Dx},\hat v_{Dz}$ | $D_t$ |
| 11–12 | `drone_sinTheta`, `drone_cosTheta` | $\sin\hat\theta_D,\cos\hat\theta_D$ | $D_t$ |
| 13 | `drone_pitchRate` | $\hat\omega_D$ | $D_t$ |
| 14 | `drone_navigationValid` | $m^{nav}_t$ | $D_t$ |
| 15 | `drone_navigationAge` | $\tau^{nav}_t$: 결정 시각 - 측위 시각 | $D_t$ |
| 16–19 | `prev_ugv_*` | 직전 결정 시점 $\hat x_G,\hat z_G,\hat v_{Gx},\hat v_{Gz}$ | $H_t$ |
| 20–23 | `prev_drone_*` | 직전 결정 시점 $\hat x_D,\hat z_D,\hat v_{Dx},\hat v_{Dz}$ | $H_t$ |
| 24 | `prev_valid` | $m^{history}_t$: 직전 기록 존재 여부 | $H_t$ |

### 2.1 정규화

- 구조체 $o_t$: 로컬 좌표 그대로 보존, 정규화는 벡터 생성 단계 한정
- $x$ 위치: 현재 드론 $\hat x_D(t)$ 기준 상대값, 로컬 $x$가 에피소드 중 수백 m로 커져도 UGV–드론 위치 차의 cm 분해능 유지 (병진 불변)

$$
\bar x=\frac{x-\hat x_D(t)}{|x-\hat x_D(t)|+3\,\mathrm m}
$$

- 결과: `drone_x` = 0, `ugv_x` = UGV–드론 수평 차, `prev_drone_x` = 직전 대비 드론 이동량
- $z$ 위치·속도·각속도: $x/(|x|+s)$ ($s$: $z$ 8 m, $v_x$ `vxMax`, $v_z$ `vzMax`, $\omega$ `pitchRateLimit`)
- 경과시간: $t/(t+3\,\mathrm s)$, 한 번도 영상 보정되지 않은 UGV 추정은 1
- 초기화 전 UGV 추정(현재·직전): 위치·속도 슬롯 0, 빈 직전 기록: 전 슬롯 0
- 제외: 원본 timestamp, 마커 ID·코너, $\Gamma$ 전체

### 2.2 이력

- 내용: 직전 결정 시점의 드론·UGV 위치·속도만 기록, 드론 자세·각속도는 $D_t$에만 포함, 고정 주기 $\Delta t=0.1$ s라 시간 간격 항목 생략
- 활용 예: 추종 속도 차이 $\hat v_{Gx,t}-\hat v_{Dx,t}$, 속도 변화 추세 $(\hat v_{Gx,t}-\hat v_{Gx,t-1})/\Delta t$ (잡음 포함 추정값의 차분, 실제 가속도 정답 아님)

## 3. 인지 경로

```text
ArUco 마커 ID·코너 (왜곡 포함 픽셀)
   ├── K, d                      왜곡 보정
   ├── 마커 실제 크기·패드 기준 배치
   ▼
마커 보드 평면 PnP: CT_P
   ├── BT_C                      카메라–드론 장착 관계
   ├── WT_B                      촬영 시각 드론 융합 측위
   ├── PT_G                      패드–UGV 고정 장착 관계
   ▼
로컬 UGV 위치 관측 y_t = [x_G, z_G]
   ▼
등속 칼만 필터
   ▼
UGV 위치·속도 추정 [x_G, z_G, v_Gx, v_Gz]
```

$$
{}^WT_G={}^WT_B\;{}^BT_C\;{}^CT_P\;{}^PT_G,\qquad
\mathbf p^W_P=\mathbf p^W_B+R_{WB}(\hat\theta_D)\left(t_{BC}+R_{BC}\,t_{CP}\right),\qquad
\mathbf p^W_G=\mathbf p^W_P-{}^WR_G\,\mathbf r_{G\rightarrow P}
$$

- PnP: 검출된 등록 마커의 네 코너와 $\Gamma$의 패드 기준 코너를 ID로 대응, 일부 마커만 보여도 같은 패드 원점 추정, 코너 평균 미사용
- PnP 절차: 왜곡 보정 → 정규화 DLT 호모그래피 $[r_1\;r_2\;t]$ 분해 초기값 → 재투영 오차 Gauss–Newton 정련
- PnP 채택: 모든 코너가 카메라 앞, 카메라가 패드 앞면 쪽, 재투영 RMS ≤ 2 px (재투영 오차는 기하 일치 정도, 위치 오차 아님)
- 오차 공유: UGV 위치 관측이 촬영 시각 드론 측위를 사용하므로 드론 측위 오차가 UGV 관측에 전달
- 관측 공분산: $R_t=[R_{WC}\Sigma_{t_{CP}}R_{WC}^\top]_{xz}+\sigma_\theta^2 J_\theta J_\theta^\top$, $\Sigma_{t_{CP}}=\sigma_{px}^2(J^\top J)^{-1}$의 이동 성분
- 속도: 한 프레임은 위치 관측, 속도는 칼만 필터가 시계열로 추정

$$
F(\Delta t)=\begin{bmatrix}I_2&\Delta t\,I_2\\0&I_2\end{bmatrix},\qquad
Q(\Delta t)=\begin{bmatrix}\frac{\Delta t^3}{3}A&\frac{\Delta t^2}{2}A\\\frac{\Delta t^2}{2}A&\Delta t\,A\end{bmatrix},\quad
A=\mathrm{diag}(\sigma_{ax}^2,\sigma_{az}^2),\qquad
C=\begin{bmatrix}I_2&0\end{bmatrix}
$$

$$
\hat s_{t|t-1}=F\hat s_{t-1|t-1},\qquad
\hat s_{t|t}=\hat s_{t|t-1}+K_t\left(y_t-C\hat s_{t|t-1}\right)
$$

- 초기화: 첫 유효 관측에서 위치 = 관측, 속도 = 드론 융합 속도 (속도 정합 reset 계약의 인과적 사전값)
- 구성 의미: 위치로 변환된 관측을 선형 모델에 넣는 KF 구성은 이번 설계의 선택, $Q$·$R$·$K_t$ 수치는 논문 공개값 아님

| 상황 | UGV 상태추정 | 관측 표시 |
|---|---|---|
| 유효 마커 관측 | 영상 기반 측정으로 보정 | $m^{vision}=1$, $\tau^{vision}=0$ |
| 마커 미검출·PnP 기각·영상 없음 | 운동 모델로 예측, 0으로 바꾸지 않음 | $m^{vision}=0$, $\tau^{vision}$ 증가 |
| 재검출 | 새 측정으로 보정 | 보정 여부·경과시간 갱신 |
| 아직 초기화 전 | 참값으로 생성하지 않음 | $m^{vision}=0$, $\tau^{vision}=\infty$ (정규화 1) |

- 미검출 중 오차: 등속 예측 중 실제 UGV가 가속도 $a_G$로 시간 $T$ 동안 움직이면 $e_v=a_GT$, $e_x=\frac12a_GT^2$

### 3.1 추정기 설정

| 항목 | 값 | 근거 |
|---|---|---|
| 백색 가속도 $[\sigma_{ax},\sigma_{az}]$ | [0.5, 0.05] m/s² | 검증 시드 조정 (아래) |
| 코너 잡음 가정 $\sigma_{px}$ | 1.0 px | 검증 시드 조정 |
| 초기 속도 표준편차 | 0.5 m/s | 검증 시드 조정, 속도 정합 reset 계약 |
| 측위 자세 잡음 가정 $\sigma_\theta$ | 0.5° | 논문 측위 잡음과 동일 |
| PnP 재투영 RMS 상한·정련 반복 | 2 px, 20회 | 설계 선택 |

- 조정 방법: 검증 시드 2001–2040, 진리 기반 스크립트 비행으로 궤적 생성(추정기 입력 아님), 고정 난수열 관측의 KF 오프라인 재생, 위치 RMSE + 속도 RMSE 최소 격자점
- 격자: $\sigma_{ax}\in\{0.25,0.5,1,1.5\}$, $\sigma_{az}\in\{0.02,0.05,0.1,0.3\}$, $\sigma_{px}\in\{0.5,1,2\}$, 초기 속도 표준편차 $\in\{0.5,1,3\}$
- 선택 규칙: $\sigma_{az}$는 0.02와 0.05의 차이가 무시 가능해 격자 경계가 아닌 0.05 선택
- 시험 시드: 조정 미사용
- $\sigma_{az}$ 의미: 수평 주행 UGV의 수직 가속도가 작다는 사전값, $z$ 위치·속도 고정 아님

## 4. 환경 연동

### 4.1 단일 카메라

- 핵심: 평면 실험의 물리 카메라는 마커 카메라 하나, tracker 측정·보상 시야 항·시각화가 같은 광축·시야 사용
- 계산: `landing2d.sensing.planarCameraGeometry`가 $K$, ${}^BT_C$에서 `sensor.fov`(영상 세로 시야각 약 64°)와 `sensor.cameraPitchOffset`(-30°, 수직 하향 대비 전방 기울기) 산출
- 검증: `validatePrimaryConfig`가 평면 tracker 기하와 마커 카메라 보정의 일치 확인

### 4.2 시작 위치

- 규칙: 수평 자세에서 패드 중심이 카메라 광축 위에 놓이는 위치, 속도는 기존과 같이 패드 속도 정합

$$
x_D(0)=x_P(0)+h_0\tan(\text{cameraPitchOffset})
$$

- 결과: 평면 실험은 패드 뒤 $h_0\tan30^\circ$ (4–8 m 고도에서 2.3–4.6 m), 3차원 옵션(기울기 0)은 기존과 같이 패드 바로 위
- 효과: reset 시점 UGV 추정 초기화 (스크립트 비행 검증 시드 40/40)

### 4.3 안전 감독기·착륙 승인

- 핵심: 정책 관측과 같은 마커 카메라 UGV 추정으로 결정 문맥·감독기 구동 (`landing2d.environment.perceptionView`)
- 결정 문맥: 추정 초기화 여부, 마지막 영상 보정 후 경과시간(초기화 전 $\infty$), 신뢰도(채택된 PnP 관측이 있으면 1)를 기존 `updateDecisionContext` 규칙에 입력 → 최근 0.5 s 보정 시 착륙 허용, 3 s 손실 시 복구 backup
- 감독기 입력: 패드 기준 고도(알려진 패드 높이), 착륙 금지·중단 요청, 결정 시각 UGV 추정을 현재 시각까지 등속 예측한 패드 상대 위치·속도
- 갱신 주기: 영상·측위 주기(결정 주기 0.1 s), 결정 간에는 마지막 추정 유지·예측

### 4.4 최종 하강 단계

- 원인: 전방 아래 60° 카메라는 패드 위 약 0.3–0.45 m 아래에서 마커 코너를 영상에 담지 못하는 사각지대
- 규칙: 최근 영상 보정 상태로 진입 고도 이하에 들어오면 접촉까지 승인 유지, 3차원 옵션의 최종 하강과 같은 로직

| 항목 | 값 |
|---|---|
| 진입 고도 | 0.5 m (패드 면 기준) |
| 해제 고도 | 0.7 m |
| 최대 유지 시간 | 3.0 s (`prolongedLoss` 이하) |

- 설정 위치: `experiment.commonObservation.finalDescent`
- 실현 가능성: 래치 없이 스크립트 비행 검증 시드 20/20 TASK_TIMEOUT, 래치와 최소 하강 속도 0.2 m/s에서 40/40 SUCCESS

## 5. 오차 설정

### 5.1 논문 명시값 (설계 문서 인용, IV-A Simulation Setup)

| 항목 | 값 | 적용 |
|---|---|---|
| 드론 속도 | 0.05 m/s 가우시안 | 기체 좌표계 속도, 1σ·평균 0·축 독립 해석 |
| 드론 자세 | 0.5° 소각 잡음 | pitch 각도에 더한 뒤 sin/cos 계산, 1σ 해석 |
| 카메라 | 512×320, 수평 FOV 90° | 마커 카메라 영상 모델 |
| 카메라 장착 | 전방축 기준 아래 60° | ${}^BT_C$ 회전 |
| 제어 주기 | 0.1 s | 기존 $\Delta t_p$와 동일 |

- 적용 금지: 0.05 m/s의 UGV 속도 추정 오차 사용, 0.5°의 pitch 각속도 잡음 사용
- 미제시 항목: 드론 위치·각속도 잡음(없음 유지), 코너 픽셀 잡음, 검출 지연

### 5.2 상태추정 성능 참조값 (설계 문서 인용, Table IV)

| 방법 | 위치 RMSE | 속도 RMSE |
|---|---:|---:|
| 논문 제안: keypoint + 학습형 상태추정 | 0.474 m | 0.589 m/s |
| Hybrid EKF+RL: 검출기 + 필터 | 1.331 m | 1.501 m/s |

- 사용 방식: 비교용 참조 지표, 관측 잡음으로 추가 금지 (코너 → PnP → KF 경로가 오차를 직접 생성, 중복 금지)
- 기록: 산출 RMSE는 `landing2d.metrics.perceptionError`(평가 전용, 추정 - 참값)로 별도 집계

### 5.3 시뮬레이터 측 가정

| 항목 | 값 | 위치 |
|---|---|---|
| 코너 픽셀 잡음 | 0.5 px | `detector.pixelNoiseStd` |
| 최소 변 길이·경계 여유 | 10 px, 2 px | `detector` |
| 렌즈 왜곡 | 0 (보정 자료 미확보) | `camera.distortion` |
| 마커 배치 | 중앙 0.50 m + 모서리 0.15 m ×4 (중심 ±0.375 m) | `pad` |
| 잡음 색인 | 시간 기준 표준정규 잡음표 (`time_indexed_v1`), reset에서 전용 난수열로 1회 생성 | `randomStreams` |

- 시간 기준 잡음 (`landing2d.sensing.exogenousNoise`): 결정 시점 $k$(0 = reset)·물리 스텝 $j$로 색인, 마커 코너 $2\times4\times M$·융합 측위 3(pitch, 기체 $v_x$, $v_z$)·평면 tracker 2(상대 $x$, bearing)
- 효과: 같은 시각의 잡음 실현값이 검출된 마커·정책·조기 종료와 무관, 세 비교군·폐루프 쌍·고정 probe가 같은 외생 잡음 공유
- 난수열: 마커 `markerOffset`, 측위 `navigationOffset`, tracker `trackerOffset`, 외생 사건(dropout·pitch 외란)은 기존 `sensorOffset`
- 관측오차 배율: `reset(c,seed,struct('sensorNoiseScale',s))`, 같은 표준정규 표본 × $s$ (공분산 $s^2$배), 추정기 잡음 가정(`estimator`)·검출 조건·dropout 일정 불변
- 검출 판정: 실제 검출기처럼 잡음이 더해진 관측 코너로 영상 경계·최소 변 길이 판정 (T03 전 수정), 배율이 경계 근처 검출 여부·PnP 채택(재투영 오차 2 px)·추정값에 영향
- PnP 퇴화: 야코비안 열 랭크 부족(코너 붕괴·비유한값) 시 자세 기각, 솔버 경고 없음
- 변경 이력: 이전 구현(검출된 마커만 순차 추출)과 같은 분포, 실현값 상이 → 평면 task fingerprint·학습 서명 변경

## 6. 부가 정보 $\Gamma$

$$
\Gamma=\{K,\mathbf d,{}^BT_C,\mathcal M,\mathbf r_{G\rightarrow P},\text{추정기·좌표계·정규화·이력 설정}\}
$$

- 생성: `landing2d.observation.staticContext`, 환경 `env.observationContext`·`reset` 정보 `info.observationContext`
- 제외: 시뮬레이션 검출기(`detector`)·측위 잡음(`navigation`)·난수열·최종 하강 설정(감독기 설정)

| 부가 정보 | `Gamma` 필드 | 내용 |
|---|---|---|
| 카메라 내부 파라미터 | `camera.intrinsicMatrix` | $f_x=f_y=255.5$ px, $(c_x,c_y)=(255.5,159.5)$ |
| 렌즈 왜곡계수 | `camera.distortionModel`, `camera.distortion` | `plumb_bob`, $\mathbf d=[k_1,k_2,p_1,p_2,k_3]$ |
| 카메라 외부 파라미터 | `camera.bodyToCamera` | 광축 = 기체 전방 아래 60°, 영상 오른쪽 = 기체 우측, $t_{BC}=\mathbf 0$ |
| 보정 식별자·영상 설정 | `camera.calibrationId`, `imageSize`, `pixelOrigin` | `sim_paper_forward60_v1`, 512×320, 0 기준 픽셀 |
| 마커 구성·기하 | `pad.markerIds`, `markerSides`, `markerCenters`, `markerCorners`, `cornerOrder` | ID 순서 = 슬롯, 패드 기준 코너 $(M\times4\times3)$ |
| UGV 장착 관계 | `ugv.padOffset`, `referencePoint`, `attitude` | $\mathbf r_{G\rightarrow P}$, 기준점 정의, 수평 직선 주행 |
| 추정기 설정 | `estimator` | PnP·KF 수치와 모델 정의 |
| 좌표계 정의 | `frames` | local·body·camera·pad·ugv 원점·축·단위 |
| 이력·정규화 설정 | `history`, `normalization` | 직전 1개 기록, 상대 $x$ 규칙·척도 |

- 외부 파라미터 의미: 카메라와 드론 사이의 고정 장착 관계, 패드와 카메라의 현재 상대 자세 아님

## 7. 공통 관측 단계에서 만들지 않는 정보

| 제외 항목 | 이후 위치 |
|---|---|
| 패드 가속 중 판단 | 관측 이력을 활용하는 모델 |
| 드론 추종 속도 부족 판단 | 온톨로지·정책 단계 |
| 시야 회복 필요도·하강 허용도·착륙 위험도 | 온톨로지 기반 의미 표현 단계 |
| R-GAT 문맥 벡터·attention 값 | 신경망 내부 계산 |
| UGV·패드 시뮬레이터 참값 | 정책 관측에서 제외 |

- 입력 경계: `capture`의 입력은 검출 결과·융합 측위·기억·$\Gamma$뿐, 등록되지 않은 입력 필드 거부
- 참값 사용 범위: 시뮬레이터 측 마커 검출기·융합 측위 모사, 동역학·접촉·보상·평가

## 8. 구현 위치

| 파일 | 역할 |
|---|---|
| `src/orchestration/+landing2d/+config/defaultCommonObservationConfig.m` | 카메라·검출기·측위 잡음·마커·UGV 장착·최종 하강·추정기·정규화 기본값 |
| `src/orchestration/+landing2d/+config/defaultPlanarVisibilityConfig.m` | 마커 카메라 기하로 평면 `sensor.fov`·`cameraPitchOffset` 설정 |
| `src/simulations/+landing2d/+sensing/planarCameraGeometry.m` | 카메라 보정 → 평면 카메라 기하 |
| `src/simulations/+landing2d/+sensing/detectMarkers.m` | 카메라·ArUco 검출기 모사 (참값 사용) |
| `src/simulations/+landing2d/+sensing/navigationEstimate.m` | 융합 측위 모사, 논문 잡음 (참값 사용) |
| `src/simulations/+landing2d/+sensing/exogenousNoise.m` | 시간 기준 표준정규 잡음표·관측오차 배율 |
| `src/simulations/+landing2d/+sensing/markerGeometry.m` | 패드 기준 마커 코너 단일 정의 |
| `src/simulations/+landing2d/+sensing/distortPoints.m`, `undistortPoints.m` | 렌즈 왜곡 모델·보정 |
| `src/simulations/+landing2d/+observation/staticContext.m` | 부가 정보 $\Gamma$ |
| `src/simulations/+landing2d/+observation/estimatePadPose.m` | 마커 보드 평면 PnP ${}^CT_P$ |
| `src/simulations/+landing2d/+observation/ugvPositionMeasurement.m` | ${}^WT_G$ 변환 사슬·관측 공분산 |
| `src/simulations/+landing2d/+observation/updateUgvEstimate.m` | 등속 칼만 필터 |
| `src/simulations/+landing2d/+observation/initialMemory.m` | 추정기·직전 기록 초기화 |
| `src/simulations/+landing2d/+observation/capture.m` | $o_t$ 생성·기억 갱신 |
| `src/simulations/+landing2d/+observation/vectorSchema.m`, `toVector.m` | 24차원 이름·순서·정규화 |
| `src/simulations/+landing2d/+environment/perceptionView.m` | UGV 추정 → 감독기 입력·결정 문맥 요약 |
| `src/simulations/+landing2d/+environment/updateDecisionContext.m` | 착륙 승인·복구 요청·최종 하강 단계 (평면·3차원 공용) |
| `src/simulations/+landing2d/+metrics/perceptionError.m` | 평가 전용 UGV 추정 오차 |

- 환경 연동: `reset`·`step`의 `env.observationContext`, `env.commonMemory`, `env.commonObservation`, `info.commonObservation`, `info.perceptionError`
- 생략 조건: 3차원 옵션, `commonObservation` 설정이 없는 저장 설정 (tracker 기반 결정 문맥 유지)

## 9. 검증

- self-test `common-observation`: 24차원 이름·필드 구성, $\Gamma$의 관측 미포함, 논문 카메라 $K$·장착 방향, 평면 tracker 기하 = 마커 카메라, 광축 기준 시작 위치·reset 시점 초기화·승인, 상대 $x$ 정규화, `capture` 입력 경계, 잡음 없는 코너에서 변환 사슬을 통한 UGV 기준점 복원(복수·단일 마커, 검출 순서 무관, 미등록 ID 무시, 왜곡 보정), ${}^BT_C$ 이동·회전 효과, 미초기화 표시, 등속 UGV 추적, 미검출 중 예측, 직전 기록, 논문 측위 잡음 통계, 인지 기반 착륙 허용·금지·복구 요청, 최종 하강 진입·유지·만료·해제, 공통 관측 설정의 fingerprint·학습 서명 포함, 3차원 옵션 분리
- self-test `spatial-3d`: 공통 관측이 없는 평면 tracker 계약에 최종 하강 단계 부재

## 10. 미결 사항

- 그래프 표현: 기존 9개 의미 노드·관계를 유지하고 원천만 $o_t$로 교체, UGV–드론 운동 상태 차이·관측 단절 시간 중심의 노드·관계 재설계는 별도 결정
- 그래프 노드 특징 (2026-10-08 수정, `forward_camera_v2`): packet graph의 고정 척도(수평 오프셋 3 m 경성 절단)·경과시간 정규화(커리큘럼 중단 기준)·연령만으로 만든 착륙 억제가 전방 하향 카메라·인지 기반 감독기와 맞지 않아 RGAT 파일럿이 착륙 0%, 연성 척도·Γ 고정 경과시간 척도·최종 하강 규칙 반영으로 수정 (T03 문서 7절)
- 재학습: 정책 입력 전환으로 전 비교군 재학습 필요
- 기존 결과: 평면 계약 변경으로 `results/`의 2차원 체크포인트·논문 수치는 변경 전 계약 기준, 재학습 필요
- 학습 커리큘럼: 초기 고도 0.025–1.0 m 커리큘럼은 전방 카메라 사각지대(약 0.3–0.45 m 이하)에서 시작 시 첫 관측 불가, 조정 여부 미정
- 최종 하강 설정: 진입·해제 고도·유지 시간은 기하 분석과 스크립트 비행 기반, 학습 정책에서의 적정성 미검증
- 추정기: 혁신 게이트 미적용, 지속 dropout 중 예측 오차 증가(UGV 가속 구간)
- 미지원: Simulink 블록 신호, 3차원 옵션, 카메라·측위 시각 차이(지연 실험)
# 현재 계약 주의 (2026-10-08)

현재 정책 입력은 `minimal_common_observation_v3` 12차원이다. 아래의 24차원 `common_observation_v2` 설명은 마커/PnP/KF 인지 경로의 이력 참고용으로 남겨 두었다. 현재 스키마·온톨로지·학습 계약은 [최소 핵심 파이프라인](refactor/MINIMAL_CORE_PIPELINE_KO.md)을 따른다.

