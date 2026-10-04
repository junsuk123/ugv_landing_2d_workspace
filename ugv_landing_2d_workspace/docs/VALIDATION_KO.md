# 최종 검증 범위와 결과

## 결론

- MATLAB R2025b 비그래픽 28/28·그래픽 포함 33/33 통과
- 최종 checkpoint 기반 3개 고정 시나리오 실행 성공
- 논문 그림 PNG·PDF·FIG 생성 확인
- fresh test 100 seed 결과 저장 확인
- R-GAT 전체 성능 우월성 미확인
- 최종 R-GAT checkpoint 관계 경로 활성 확인
- 관계 활성화 전후 test 결과율 동일 확인
- 실제 비행 안전성 검증 제외

## 실행 명령

```matlab
run_tests(false)
run_activate_rgat_checkpoint
[study,figures] = run_paper(struct('figureVisible',false));
```

결과 위치:

```text
results/paper/
```

## 최종 held-out 결과

평가 조건:

- checkpoint 선택과 분리된 test seed 100개
- 동일 task fingerprint
- 동일 reward·environment·action·safety contract
- deterministic policy 평가

| 모델 | 평균 return | 성공 | 위험 | 안전 중단 | 시간 초과 | 파라미터 | 정책 추론 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Low-level MLP PPO | 19.139 | 74% | 2% | 23% | 1% | 7,445 | 0.320 ms |
| Semantic-flat MLP PPO | 18.496 | **75%** | 9% | **13%** | 3% | 15,317 | **0.149 ms** |
| Ontology R-GAT PPO | 17.930 | 72% | 9% | 14% | 5% | 17,001 | 0.196 ms |

판정:

- baseline 대비 semantic-flat 성공률 +1%p
- semantic-flat 대비 R-GAT 성공률 -3%p
- baseline의 위험 접촉률 최저
- semantic-flat의 평균 추론 시간 최저
- 단일 학습 seed 기반 통계적 우월성 판정 제외

## 대표 시나리오

### S1 정상 정렬

- 목적: `PadVisibility → RelativeTracking → DescentEligibility` 확인
- peak pad speed 2.4 m/s
- speed margin 7.1 m/s
- acceleration margin 1.9 m/s²
- 물리적 착륙 가능 판정

| 모델 | 결과 | 안정성 지수 |
|---|---|---:|
| Low-level | 성공 | 88.7 |
| Semantic-flat | 비허가 접촉 | 85.0 |
| R-GAT | 성공 | **93.5** |

### S2 급가속

- 목적: `PadMotion → RelativeTracking → TrackingCorrection` 확인
- peak pad speed 4.375 m/s
- speed margin 5.125 m/s
- acceleration margin 1.0 m/s²
- 물리적 착륙 가능 판정

| 모델 | 결과 | 안정성 지수 |
|---|---|---:|
| Low-level | 안전 중단 | 37.9 |
| Semantic-flat | 성공 | **75.9** |
| R-GAT | 성공 | 74.3 |

### S3 가시성 손실

- 목적: `PadVisibility → ViewRecovery → LandingInhibit` 확인
- detector dropout 0.8 s
- peak pad speed 4.3 m/s
- speed margin 5.2 m/s
- acceleration margin 1.3 m/s²
- 물리적 착륙 가능 판정

| 모델 | 결과 | 안정성 지수 | LandingInhibit |
|---|---|---:|---:|
| Low-level | 안전 중단 | 47.6 | 73.1% |
| Semantic-flat | 성공 | 70.8 | 1.7% |
| R-GAT | 성공 | **80.6** | 1.8% |

![고정 시나리오 궤적](assets/paper/paper_trajectories.png)

## 안정성 지표

구성 요소:

$$
S_x=\exp\left[-\left(\frac{\mathrm{RMSE}(e_x)}{L_{pad}}\right)^2\right]
$$

$$
S_v=\exp\left[-\left(\frac{\mathrm{RMSE}(\Delta v_x)}{v_{x,td}}\right)^2\right]
$$

$$
S_{fov}=1-f_{fovloss},\qquad
S_{sup}=1-f_{supervisor}
$$

$$
S_\theta=\exp\left[-\left(\frac{\mathrm{RMS}(\theta)}{\theta_{td}}\right)^2\right]
$$

$$
S_j=\frac{1}{1+J_{rms}/J_{ref}}
$$

최종 지수:

$$
S_{stability}=\frac{100}{6}
\left(S_x+S_v+S_{fov}+S_{sup}+S_\theta+S_j\right)
$$

해석:

- 범위 0–100
- 큰 값 우수
- return·terminal outcome 제외
- 성공률과 별도 보고
- 가중치 임의 튜닝 제외

![안정성 지표](assets/paper/paper_stability.png)

## 착륙 불가능성과 LandingInhibit

물리 authority margin:

$$
m_v=(v_{sustain}-v_{reserve})-v_{pad,peak}
$$

$$
m_a=a_{x,max}-a_{pad}
$$

$$
m_T=T_{max}-T_{deadline}
$$

물리 가능 조건:

$$
m_v\ge0,\qquad m_a>0,\qquad m_T\ge0
$$

구분:

- `PhysicalFeasible=false`: speed·acceleration·mission-time authority 부족
- `LandingInhibit=true`: 현재 시점 하강 금지
- `LandingInhibit`: 영구적 임무 불가능 판정 제외

원인 audit:

- sensor dropout
- trajectory/FOV loss
- excessive relative speed
- uncertainty/gate

![물리 가능성과 하강 금지](assets/paper/paper_feasibility.png)

## 구조 감사

| 모델 | Policy $\lVert W_g\rVert_F$ | Value $\lVert W_g\rVert_F$ | 관계 경로 |
|---|---:|---:|---|
| Ontology R-GAT | 0.0001665 | 0.0006056 | 활성 |

추가 수치:

- Policy relation head norm 0.1517
- Value relation head norm 0.4792
- calibration scale 0.001
- test 평균 절대 residual: 수평 $1.27\times10^{-5}$·수직 $3.86\times10^{-5}$

판정:

- raw semantic Actor/Critic 기준점 고정
- 관계 전용 PPO와 100-seed validation 성능 가드 적용
- test 성공·위험·중단·시간초과율 변화 0
- test 평균 return +0.058
- 활성 경로 확인·성능 우월성 주장 제외

![온톨로지 신호와 관계 감사](assets/paper/paper_ontology.png)

## 회귀 테스트 범위

| 범주 | 검증 |
|---|---|
| 레거시 보존 | PD 기준 수치 동일성 |
| 동역학 | PN·CV/CA/CV·접촉 interpolation |
| 센서 | body-fixed projection·가시성 경계 |
| 정보경계 | 비가시 hidden truth 누수 차단 |
| 추정기 | causal 갱신·불확실성·재포착 |
| 보상 | terminal 1회·progress shaping·순서 |
| PPO | gradient·GAE·rollout·checkpoint |
| R-GAT | 순전파·역전파·typed relation |
| 관계 성능 가드 | raw policy 불변·비영 readout·결과율 비열화 차단 |
| 그래프 | 9노드·26간선·context tensor |
| 논문 실행 | 고정 시나리오 주입·metric 범위 |

## 미검증 범위

- 다중 학습 seed 평균·표준편차
- 활성 relation checkpoint 성능
- 실제 ROS 2 transport
- 실제 센서 latency·dropout 분포
- 실제 기체 공력·제어 지연
- 실제 비행 안전성
- 보편적 온톨로지 우월성
