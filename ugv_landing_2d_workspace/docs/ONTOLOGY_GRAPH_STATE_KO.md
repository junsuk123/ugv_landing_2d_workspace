# 온톨로지 상황 그래프와 R-GAT 정책 상태 설계

## 결론

- 온톨로지 역할: 보상 가중치 조절이 아닌 Actor/Critic 상태 표현
- 입력 원천: baseline과 동일한 causal sensor packet
- 구조: 9개 의미 노드, 17개 의미 간선, 9개 자기 간선
- 특징: 노드당 12개, 전체 108개
- 정책 결합: raw semantic bypass + 4차원 relation context residual
- 실시간 처리: 순전파만 적용
- 정보 누수: hidden truth·보상·미래·성공 라벨 제외
- 최신 체크포인트 상태: Policy/Value relation readout 비영점·관계 경로 활성

![온톨로지 상황 그래프](assets/ontology_graph.svg)

## 설계 목표

- 패드 가시성·상대운동·기체상태·하강 안전성의 명시적 분리
- 방향과 크기의 동시 보존
- 미관측 시 uncertainty와 observation age 보존
- 불필요 노드·고립 노드·중복 관계 제외
- R-GAT 관계 유형별 message passing 적용
- semantic-flat 비교군과 동일 정보량 유지
- 그래프 병목 발생 시 raw semantic 정보 보존

## 입력 경계

정책 입력 packet:

$$
o_t=[o_t^{\mathrm{own}},o_t^{\mathrm{track}},o_t^{\mathrm{visibility}},o_t^{\mathrm{memory}}]\in\mathbb{R}^{26}
$$

| 그룹 | 필드 수 | 내용 |
|---|---:|---|
| `own_motion` | 6 | 고도, $v_x$, $v_z$, $\sin\theta$, $\cos\theta$, pitch rate |
| `pad_track` | 8 | 상대위치·상대속도·패드 운동 추정, 공분산 대용 표준편차, 초기화 mask |
| `visibility` | 7 | 검출, bearing, confidence, 미관측 시간, 예측 bearing·FOV margin |
| `task_memory` | 5 | 잔여시간, 직전 행동, `LandingInhibit`, abort 요청 |

허용 입력:

- 현재 own-state
- 현재 카메라 검출
- causal pad-track 추정
- 검출 age와 uncertainty
- 직전 정책 행동
- 공통 안전 감독기의 공개 상태

금지 입력:

- 비가시 시점의 실제 패드 위치·속도
- 예정된 CV/CA/CV phase 번호
- 미래 패드 궤적
- reward·return·advantage
- 성공·실패·terminal label
- PN 교사 행동
- 평가용 truth metric

## 노드 설계

| 번호 | 노드 | 그룹 | 핵심 입력 | 정책 의미 |
|---:|---|---|---|---|
| 1 | `PadVisibility` | Perception | detected, bearing, predicted margin, confidence | 현재·예측 시야 상태 |
| 2 | `PadMotion` | Tracking | $\hat v_p$, $\hat a_p$, uncertainty | 패드 운동 추세 |
| 3 | `DroneTranslation` | Vehicle | $h,v_x,v_z$ | 드론 병진 상태 |
| 4 | `DroneAttitude` | Vehicle | $\theta,\dot\theta$ | 카메라·추력 방향 상태 |
| 5 | `RelativeTracking` | Tracking | $\hat e_x,\widehat{\Delta v_x}$, uncertainty | 상대 추종 오차 |
| 6 | `TrackingCorrection` | Tracking | signed correction, braking demand | 수평 복구 방향 |
| 7 | `ViewRecovery` | Perception | loss age, predicted bearing, FOV urgency | 재포착 필요도 |
| 8 | `DescentEligibility` | Safety | confidence, position·speed·attitude risk | 추가 하강 허용도 |
| 9 | `LandingInhibit` | Safety | inhibit, abort, age, uncertainty | 현재 하강 금지 |

노드 선택 기준:

- 제어 결정에 직접 연결되는 의미만 유지
- 실제 센서·추정 필드로 계산 가능한 의미만 유지
- 동일 의미를 반복하는 노드 제외
- 보상항 전용 노드 제외
- PolicyNode·ValueNode 같은 빈 query node 제외

## 관계 설계

### 의미 간선 17개

| 출발 | 도착 | 관계 |
|---|---|---|
| `PadMotion` | `RelativeTracking` | `informs` |
| `DroneTranslation` | `RelativeTracking` | `informs` |
| `DroneAttitude` | `PadVisibility` | `affects_visibility` |
| `DroneTranslation` | `PadVisibility` | `affects_visibility` |
| `PadMotion` | `TrackingCorrection` | `informs` |
| `RelativeTracking` | `TrackingCorrection` | `informs` |
| `PadVisibility` | `ViewRecovery` | `informs` |
| `DroneAttitude` | `ViewRecovery` | `informs` |
| `RelativeTracking` | `ViewRecovery` | `informs` |
| `PadVisibility` | `DescentEligibility` | `supports` |
| `RelativeTracking` | `DescentEligibility` | `informs` |
| `DroneTranslation` | `DescentEligibility` | `informs` |
| `DroneAttitude` | `DescentEligibility` | `informs` |
| `PadVisibility` | `LandingInhibit` | `informs` |
| `RelativeTracking` | `LandingInhibit` | `informs` |
| `DroneTranslation` | `LandingInhibit` | `informs` |
| `LandingInhibit` | `DescentEligibility` | `inhibits` |

추가 구조:

- 각 노드 자기 간선 1개
- 전체 자기 간선 9개
- 전체 간선 26개
- 간선 방향 보존
- 자동 대칭화 제외
- relation embedding 적용

## 노드 특징 텐서

그래프 상태:

$$
G_t=(V,E,R,X_t),\qquad X_t\in\mathbb{R}^{12\times9}
$$

노드 $i$의 특징:

$$
x_i=[p_i,\tilde p_i,s_i,\tilde s_i,m_i,c_i,u_i,\tau_i,q_i,T_i,1,\kappa_i]^\top
$$

| 채널 | 의미 | 범위 |
|---|---|---|
| `primary` | 주요 의미 크기 | $[-1,1]$ |
| `signedPrimary` | 주요 방향 | $[-1,1]$ |
| `secondary` | 보조 의미 크기 | $[-1,1]$ |
| `signedSecondary` | 보조 방향 | $[-1,1]$ |
| `validity` | 측정·추정 유효성 | $[0,1]$ |
| `confidence` | 검출·track 신뢰도 | $[0,1]$ |
| `uncertainty` | 위치·속도·가속도 불확실성 | $[0,1]$ |
| `trend` | 속도·가속도·변화 방향 | $[-1,1]$ |
| `urgency` | FOV·복구·금지 긴급도 | $[0,1]$ |
| `remainingTime` | 정규화 잔여시간 | $[0,1]$ |
| `bias` | 상수 1 | 1 |
| `typeId` | 노드 식별자 | $(0,1]$ |

설계 효과:

- 위험 크기와 좌우 방향 분리
- confidence와 uncertainty 분리
- 가시 상태와 예측 FOV 상태 분리
- 현재 상태와 변화 추세 분리
- semantic-flat과 R-GAT의 동일 raw 정보 보장

## R-GAT 부호화

관계 $r$의 선형 변환과 relation embedding:

$$
z_i^{(r)}=W_r x_i,\qquad E_r\in\mathbb{R}^{d_r}
$$

Attention logit:

$$
e_{ij}^{(r)}=\mathrm{LeakyReLU}\left(
a_r^\top[z_i^{(r)}\Vert z_j^{(r)}\Vert E_r]
\right)
$$

수신 노드별 정규화:

$$
\alpha_{ij}^{(r)}=
\frac{\exp(e_{ij}^{(r)})}
{\sum_{(k,r')\in\mathcal{N}(j)}\exp(e_{kj}^{(r')})}
$$

단일층 노드 갱신:

$$
h_j=\tanh\left(
\sum_{(i,r)\in\mathcal{N}(j)}\alpha_{ij}^{(r)}W_rx_i
+W_0x_j+b_0
\right)
$$

설정:

- hidden dimension 8
- relation embedding dimension 4
- message-passing layer 1개
- local residual $W_0x_j+b_0$
- Actor encoder와 Critic encoder 분리

## 그룹 readout

| 그룹 | 포함 노드 |
|---|---|
| Perception | `PadVisibility`, `ViewRecovery` |
| Tracking | `PadMotion`, `RelativeTracking`, `TrackingCorrection` |
| Vehicle | `DroneTranslation`, `DroneAttitude` |
| Safety | `DescentEligibility`, `LandingInhibit` |

그룹 평균:

$$
\bar h_g=\frac{1}{|V_g|}\sum_{i\in V_g}h_i
$$

4차원 관계 문맥:

$$
c_t=\tanh\left(W_g[\bar h_1\Vert\bar h_2\Vert\bar h_3\Vert\bar h_4]+b_g\right)
$$

## Actor/Critic 입력

Raw semantic bypass:

$$
s_t=\mathrm{vec}(X_t)\in\mathbb{R}^{108}
$$

Actor 평균:

$$
\mu_t=f_{\pi}(s_t)+W_{\pi}c_t
$$

Critic 값:

$$
V_t=f_V(s_t)+w_V^\top c_t
$$

목적:

- 그래프 readout 실패 시 raw semantic 정보 보존
- semantic-flat 정책과 동일한 base 표현 확보
- 관계 구조의 추가 기여만 residual로 분리
- Actor와 Critic의 관계 기여 별도 학습

## 의미 제약 하강 gate

관계 residual $\delta_t=W_\pi c_t$의 수직 성분:

$$
\delta_{z,t}^{\mathrm{gate}}=
\begin{cases}
\delta_{z,t}, & \delta_{z,t}\ge0,\\
E_t\delta_{z,t}, & \delta_{z,t}<0
\end{cases}
$$

여기서:

$$
E_t=\mathrm{clip}(X_t[\mathrm{DescentEligibility},1],0,1)
$$

의미:

- 음의 수직 residual: 추가 하강
- 양의 수직 residual: 상승·제동
- `LandingInhibit` 활성 시 $E_t\rightarrow0$
- 추가 하강 차단
- 상승·제동 residual 유지
- 동일 piecewise slope 기반 역전파

## 사전학습

목표:

$$
\min_{\theta,\psi}
\frac{1}{|M|}\sum_{(i,k)\in M}
\left\|D_\psi(H_{i,k})-X_{i,k}\right\|_2^2
$$

조건:

- train seed만 사용
- 현재 시점 특징만 사용
- masked feature 복원
- 방문용 random action 즉시 폐기
- action target 제외
- reward target 제외
- outcome target 제외
- future target 제외
- hidden simulator truth 제외

## PPO 단계

- 1~90% 반복: 관계 readout adaptation 비활성
- raw semantic base policy 학습
- 마지막 10%: base MLP 고정
- attention·group readout·relation head 최적화
- validation 개선 margin 5.0 적용
- unsafe outcome 가중 checkpoint 선택
- 비활성 선택 시 raw 정책 고정 관계 전용 PPO 25회 적용
- validation 결과율 비열화 가드와 residual trust region 적용
- test seed의 선택 과정 사용 제외

## 최신 체크포인트 감사

| 감사 항목 | Policy | Critic |
|---|---:|---:|
| $\lVert W_g\rVert_F$ | 0.0001665 | 0.0006056 |
| relation head norm | 0.1517 | 0.4792 |
| relation path | 활성 | 활성 |
| calibration scale | 0.001 | 0.001 |

판정:

- raw semantic Actor/Critic 기준점 완전 고정
- attention·readout·relation head만 추가 최적화
- test 결과율 72%/9%/14%/5% 유지
- 평균 return 17.873→17.930
- 평균 절대 행동 residual 수평 $1.27\times10^{-5}$·수직 $3.86\times10^{-5}$
- 관계 경로 활성 확인·관계 영향량의 작은 신뢰구간 확인

![R-GAT 정책 추적](assets/paper/paper_ontology.png)

## 관련 코드

| 기능 | 코드 |
|---|---|
| 노드·간선 스키마 | `src/+landing2d/+graphstate/contextSchema.m` |
| 노드 특징 구성 | `src/+landing2d/+graphstate/contextGraph.m` |
| R-GAT 순전파 | `src/+landing2d/+rgat/relationForward.m` |
| R-GAT 역전파 | `src/+landing2d/+rgat/relationBackward.m` |
| graph encoder | `src/+landing2d/+graphstate/encoderForward.m` |
| Actor relation residual | `src/+landing2d/+rl/relationPolicyResidual.m` |
| Critic relation residual | `src/+landing2d/+rl/valueForward.m` |
| causal 사전학습 | `src/+landing2d/+graphstate/pretrainCausalEncoder.m` |
| 관계 전용 미세조정 | `src/+landing2d/+rl/ensureRelationalPath.m` |
| 성능 보존 가드 | `src/+landing2d/+rl/guardRelationalCandidate.m` |
| 체크포인트 감사 | `run_paper_validation.m` |

## 주장 범위

- 온톨로지 그래프 구성 검증
- causal 정보경계 검증
- R-GAT 순전파·역전파 구현 검증
- Actor/Critic 연결 구조 검증
- 최종 체크포인트 relation path 활성 확인
- 동일 test 결과율 유지 확인
- 활성 R-GAT 성능 우월성 주장 제외
