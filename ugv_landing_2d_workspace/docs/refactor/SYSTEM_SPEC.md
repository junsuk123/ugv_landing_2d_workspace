# Planar Visibility PPO v2 최종 시스템 명세

## 결론

- 연구 환경: CV–CA–CV 이동 패드와 pitch/thrust 기반 2차원 드론
- 정책 입력: causal 26필드 packet 또는 동일 packet 기반 9노드 그래프
- 정책 출력: 수평·수직 가속도 2개
- 공통 계층: 동역학·센서·추정기·보상·안전 감독기·종료 판정
- 비교 계층: Actor/Critic 상태 표현
- 정책 주기 0.10 s, 물리 주기 0.01 s

![시스템 파이프라인](../assets/pipeline.svg)

## 좌표계와 상태

- world $x$: 패드 진행 방향
- world $z$: 위쪽 방향
- 패드 표면 고도: $z_p$
- 상대 수평 오차: $e_x=x_p-x_d$
- 패드 기준 고도: $h=z_d-z_p$

물리 상태:

$$
q_t=[x_d,z_d,v_{x,d},v_{z,d},\theta,\dot\theta,T]^\top
$$

제외 상태:

- $y$ 위치·속도
- roll·yaw
- 6자유도 공력
- 실제 비행 제어기 내부 상태

## 패드 궤적

세 구간:

1. CV1: 초기 속도 $v_1$
2. CA: 일정 가속도 $a_2$
3. CV3: 최종 속도 $v_3=v_1+a_2T_2$

연속성:

$$
x_p(t_1^-)=x_p(t_1^+),\qquad
x_p(t_2^-)=x_p(t_2^+)
$$

$$
v_p(t_1^-)=v_p(t_1^+),\qquad
v_p(t_2^-)=v_p(t_2^+)
$$

## 행동과 동역학

정책의 raw Gaussian 명령:

$$
u_t\sim\mathcal{N}(\mu_t,\mathrm{diag}(\sigma_t^2))
$$

정규화 행동:

$$
\bar a_t=\tanh(u_t)
$$

요청 가속도:

$$
a_x=a_{x,\max}\bar a_{t,1},\qquad
a_z=a_{z,\max}\bar a_{t,2}
$$

자세·추력 setpoint:

$$
\theta_{sp}=\mathrm{atan2}(a_x,g+a_z)
$$

$$
T_{sp}=m\sqrt{a_x^2+(g+a_z)^2}
$$

실제 병진 동역학:

$$
\ddot x=\frac{T\sin\theta}{m},\qquad
\ddot z=\frac{T\cos\theta}{m}-g
$$

- pitch: 감쇠 2차 응답
- thrust: 1차 지연 응답
- PPO likelihood: supervisor 적용 전 raw $u_t$ 기준

## 카메라와 가시성

상대 벡터:

$$
d=[e_x,-h]^\top
$$

Body-fixed 카메라 축:

$$
b_{cam}=[-\sin\theta,-\cos\theta]^\top
$$

Image-right 축:

$$
b_{right}=[\cos\theta,-\sin\theta]^\top
$$

투영:

$$
d_{cam}=d^\top b_{cam},\qquad
\ell=d^\top b_{right},\qquad
\beta=\mathrm{atan2}(\ell,d_{cam})
$$

가시 조건:

$$
d_{cam}>0,\qquad \lVert d\rVert\le R_{max},\qquad
|\beta|<\frac{\mathrm{FOV}}{2}
$$

## Causal observation memory

- 패드 위치·속도·가속도 추정 유지
- 마지막 검출 시각 유지
- 위치·속도·가속도 불확실성 유지
- 비가시 구간 예측만 사용
- 현재 hidden pad truth 참조 제외
- 재검출 innovation gate 적용

## 상태 표현 비교

| 모델 | 상태 | 차원 |
|---|---|---:|
| Baseline | normalized causal packet | 26 |
| Semantic-flat | $\mathrm{vec}(X_t)$ | 108 |
| Ontology R-GAT | $\mathrm{vec}(X_t)$ + relation context | 108+4 |

## 안전 감독기

입력:

- own-state
- causal packet
- 요청 가속도

기능:

- 패드 미관측 시 하강 차단
- 장기 미관측 시 상승·정지 복구
- causal track 기반 수평 추종
- 재포착 시 abort 요청 해제
- 복구 제한시간 초과 시 `SAFE_ABORT`
- hidden pad truth 사용 제외

## 종료 사건

| 사건 | 의미 | terminal bonus |
|---|---|---:|
| `SUCCESS` | 허가·기계적 안전 접촉 | +25 |
| `SAFE_ABORT` | 복구 실패 후 안전 중단 | -15 |
| `TASK_TIMEOUT` | 임무 제한시간 초과 | -12 |
| `UNSAFE_CONTACT` 계열 | 위험·비허가·패드 이탈 접촉 | -40 |
| `SAFETY_ENVELOPE_VIOLATION` | 물리 안전영역 위반 | -40 |

- 모든 named outcome: `terminated=true`
- terminal bootstrap: 0
- 외부 수집 한계만 `truncated=true`
- 접촉 시점 interpolation 적용

## 실행 흐름

```text
reset
→ scenario·sensor event 사전 결정
→ causal packet 구성
→ 상태 표현 분기
→ Actor/Critic 순전파
→ tanh·가속도 scaling
→ 공통 안전 감독기
→ 0.01 s 물리 적분
→ 센서·track 갱신
→ 보상·종료 판정
→ 다음 0.10 s 정책 결정
```

## 비실시간 작업

- PPO 역전파
- R-GAT masked reconstruction 사전학습
- validation checkpoint 선택
- Monte Carlo 평가
- 논문용 시각화

## 제한

- 연구용 2D 시뮬레이션
- 실제 로봇 메시지 형식 모사 수준
- 실제 통신 지연·패킷 손실 미검증
- 실제 비행 안전성 인증 제외
