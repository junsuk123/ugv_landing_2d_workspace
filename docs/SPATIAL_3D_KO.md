# 3차원 확장 옵션

## 요약

- 목적: 평면 $x$–$z$ 모델에 측방 $y$축과 roll 축을 더한 3차원 착륙 실험 옵션
- 선택: `spatialDimension=3` (기본 2), 2차원 기본 실행의 수치·체크포인트 서명 불변
- 공통 계약: 세 비교군(baseline·semantic-flat·R-GAT)의 3차원 환경·센서·보상·행동·종료·감독기 동일, task fingerprint 동일
- 행동: $\bar a_t\in[-1,1]^3$, $a_t=\mathrm{diag}(a_{x,\max},a_{y,\max},a_{z,\max})\bar a_t$, 수직 성분 마지막
- 관측: causal packet $o_t\in\mathbb{R}^{37}$ (`causal_packet_v3_spatial`), 그래프 노드 특징 14채널
- 결과 위치: `results/spatial3d` (2차원 체크포인트와 분리)
- 학습 백엔드: MATLAB PPO 한정, Simulink 백엔드 조합 거부
- 설정 파일: [defaultSpatialConfig.m](../src/orchestration/+landing2d/+config/defaultSpatialConfig.m), 적용 [applySpatialDimension.m](../src/orchestration/+landing2d/+config/applySpatialDimension.m)

## 1. 실행

```matlab
run(struct('spatialDimension',3))
run(struct('executionMode','smoke','spatialDimension',3,'runSelfTest',false, ...
    'generatePaper',false,'figureVisible',false,'saveResults',false,'showLiveDashboard',false))
run_scenario('S3',struct('spatialDimension',3))
run_live('S3',struct('spatialDimension',3))
```

- `run`: 3차원 세 비교군 학습·검증·시험·논문 그림, 체크포인트 `results/spatial3d`
- `run_scenario`: `results/spatial3d` 체크포인트로 고정 시나리오 평가, 그림 `results/spatial3d/scenario`
- `run_live`: 3차원 축에 기체 자세·원뿔 시야 바닥 투영·UGV 패드 실시간 표시
- 학습 전 `run_scenario`·`run_live`: 3차원 체크포인트 부재 오류

## 2. 상태와 동역학

- 기체 상태: $\xi=[x,y,z,v_x,v_y,v_z,\theta,\phi,\omega_\theta,\omega_\phi,F]^\top\in\mathbb{R}^{11}$, roll $\phi$·roll rate $\omega_\phi$ — 신규 기호
- 자세 setpoint: 추력 방향 $n=[\cos\phi\sin\theta,\;\sin\phi,\;\cos\phi\cos\theta]^\top$의 $[a_x,a_y,g+a_z]$ 정렬

$$
\theta^{sp}=\mathrm{sat}_{\theta_{\max}}\!\big(\mathrm{atan2}(a_x,\,g+a_z)\big),\qquad
\phi^{sp}=\mathrm{sat}_{\theta_{\max}}\!\Big(\mathrm{atan2}\big(a_y,\sqrt{a_x^2+(g+a_z)^2}\big)\Big)
$$

$$
F^{sp}=\mathrm{clip}\!\left(m\sqrt{a_x^2+a_y^2+(g+a_z)^2},\;0,\;\kappa_F mg\right)
$$

- roll 루프: pitch와 같은 임계감쇠 2차 응답·각도 한계·각속도 한계
- pitch rate 외란: pitch 축 한정 (평면 모델과 동일 사건 일정)
- 병진 가속도: $\ddot x=F\cos\phi\sin\theta/m$, $\ddot y=F\sin\phi/m$, $\ddot z=F\cos\phi\cos\theta/m-g$
- 평면 환원: $a_y=0$, $\phi=\omega_\phi=0$이면 $x,z,\theta,\omega_\theta,F$가 평면 모델과 비트 동일 (self-test `spatial-3d`)
- 초기 상태: 패드 바로 위, 수평·측방 속도 정합, $\phi=\omega_\phi=0$

## 3. UGV 패드 운동

- 진행 방향: 평면 모델과 같은 CV–CA–CV $(v_1,a_2,T_1,T_2,T_3)$
- 측방: 같은 구간 시각의 CV–CA–CV, $v_{y1}\sim\mathcal U[-0.5,0.5]$ m/s, $a_{y2}\sim\mathcal U[-0.6,0.6]$ m/s², $v_{y3}=v_{y1}+a_{y2}T_2$ — 신규 기호
- 지면 궤적: 직선–포물선–직선 (CA 구간 방향 전환)
- 허용 조건: $\sqrt{v_3^2+v_{y3}^2}\le\bar v_d-v_{res}$
- 표본 순서: 평면 변수 표본 이후 측방 변수 표본
- 학습 커리큘럼: 측방 범위도 진행 방향과 같은 운동 배율 적용
- 고정 시나리오 측방 값 $(v_{y1},a_{y2})$: S1 $(0.30,0)$, S2 $(0,0.50)$, S3 $(-0.20,-0.40)$, 평면 변수·센서 사건 동일

## 4. 카메라·측정·추정

- 카메라 축: $-n$, 영상 축: 기체 전방 $b_f=[\cos\theta,0,-\sin\theta]^\top$, 기체 측방 $b_s=[-\sin\phi\sin\theta,\cos\phi,-\sin\phi\cos\theta]^\top$
- bearing: $\beta=\mathrm{atan2}(d^\top b_f,d_{cam})$, $\beta_y=\mathrm{atan2}(d^\top b_s,d_{cam})$ — 신규 기호 $\beta_y$
- 시야: 원뿔, off-axis 각 $\beta_{off}=\mathrm{atan2}\big(\lVert[d^\top b_f,d^\top b_s]\rVert,d_{cam}\big)<\varphi/2$, 여유 $m_\beta=\varphi/2-\beta_{off}$
- 측정: $\tilde e_x,\tilde e_y,\tilde\beta,\tilde\beta_y$ 각각 독립 Gaussian 잡음
- 신뢰도: $c_k=\max\big(c_{fl},1-\min(1,(\lVert[\tilde\beta,\tilde\beta_y]\rVert/(\varphi/2))^2)\big)$
- 추정기: 측방 축에 같은 이득 $k_p,k_v,k_a$·같은 감쇠의 등가속도 추정, 불확실성 $\hat\sigma_p,\hat\sigma_v,\hat\sigma_a$ 축 공통
- innovation gate: 수평 innovation 노름 $\lVert[\nu_x,\nu_y]\rVert$ 기준

## 5. 관측 packet ($37=10+12+9+6$)

| 그룹 | 차원 | 평면 packet 대비 추가 성분 |
|---|---:|---|
| 자기 운동 | 10 | $v_y,\;\sin\phi,\;\cos\phi,\;\omega_\phi$ |
| 패드 추적 | 12 | $\hat e_y,\;\widehat{\Delta v_y},\;\hat v_{p,y},\;\hat a_{p,y}$ |
| 가시성 | 9 | $\tilde\beta_y,\;\hat\beta_y^+$ |
| 임무 기억 | 6 | $\bar a_{t-1,y}$ |

- 정규화: 각 추가 성분은 대응 평면 성분과 같은 기준값
- 예측 시야 $\hat\beta^+,\hat\beta_y^+,\hat m_\beta^+$: $(\hat e_x^+,\hat e_y^+,h,\theta^+,\phi^+)$에 원뿔 투영 적용
- 정보 경계: 측방 truth·미래 상태 미포함, `assertCausalPacket`의 측방 필드 등록·완전성 검사

## 6. 감독기·종료·보상

- 감독기 복구 backup: 측방 축에도 $0.35\,\hat e_y+0.8\,\widehat{\Delta v_y}$ (미추적 시 $-1.5\,v_y$), 수직 규칙 불변
- 접촉 footprint: $\lvert e_x\rvert\le L_{pad}\wedge\lvert e_y\rvert\le W_{pad}$, $W_{pad}=0.5$ m — 신규 기호
- 기계적 안전: $\lVert[\Delta v_x,\Delta v_y]\rVert\le v_{x,td}$, $\lvert\phi\rvert\le\theta_{td}$, $\lvert\omega_\phi\rvert\le\omega_{td}$ 추가
- 안전 범위 위반: $\lvert\phi\rvert>\theta_{\max}+1^\circ$ 또는 $\lvert\omega_\phi\rvert>\omega_{\max}$ 추가
- 보상: 목표 비용의 수평 오차를 $\lVert[e_x,e_y]\rVert$로, 시야 비용을 $\beta_{off}$로 대체, 착륙 준비도에 $e_y,\Delta v_y,\phi,\omega_\phi$ 항 추가
- 행동 변화량 비용: 운행 비용에 $\frac{\Delta t}{T_{ref}}\,w_{\Delta a}\,\tfrac12\lVert\bar a_t-\bar a_{t-1}\rVert^2$ 추가, $w_{\Delta a}=10$ — 신규 기호
- 종료 보너스·가중치·할인: 평면 계약과 동일

### 6.1 최종 하강 단계

- 핵심: 신뢰 검출 상태로 저고도 대역에 진입하면 접촉까지 착지 승인 유지 (실기체의 blind final descent)
- 필요 이유: 패드 중심점 투영 모델에서 고도 $h$의 시야 반경 $h\tan(\varphi/2)$ → $h=0.1$ m에서 4.7 cm, 두 축 동시 오차로 패드 바로 위에서도 검출 소실·승인 해제
- 진입: $\mathrm{reacq}_k\wedge I^{ab}=0\wedge h\le h_{fd}$, $h_{fd}=0.15$ m — 신규 기호
- 유지 중: $I^{inh}=0$ (감독기 하강 제동 해제), 접촉 순간의 footprint·속도·자세 판정 불변
- 해제: $I^{ab}=1$ 또는 $h>h_{fd,exit}=0.25$ m 또는 진입 후 $T_{fd}=3$ s 경과 — 신규 기호
- 근거: 패킷 PD 기준 제어기의 3차원 공칭 성공 22/60 → 34/60 (2차원 37/60)

## 7. 그래프 상태

- 노드 9개·간선 26개·관계 5개 불변
- 노드 특징: 평면 12채널 + 측방 2채널(`lateralPrimary`, `lateralSecondary`) = 14채널, 상태 차원 $14\times9=126$
- 크기 채널: 수평 오차·속도 노름, pitch·roll 중 큰 값
- 측방 채널: 노드별 대응 평면 부호 채널의 $y$ 성분 (DescentEligibility·LandingInhibit은 0)
- R-GAT 수직 하강 gate: 행동 마지막 성분($a_z$) 적용
- 인과 사전학습 재구성 대상: 동적 11채널

## 8. 3차원 학습 설정

- 핵심: 평면 탐색 설정 그대로의 3차원 PPO는 착륙 0%, 학습 설정 4개로 중단 수렴 해소, 최종 하강 단계·행동 변화량 비용(§6) 추가 후 공칭 착륙 확인
- 증상: baseline·semantic-flat 각 2500회 학습, 고도 0.1~0.4 m 시작 단계부터 학습 에피소드의 약 90% SAFE_ABORT, 착륙 0회
- 과제 가능성: 패킷만 쓰는 PD 제어기의 3차원 성공 45/60(시작 단계)·22/60(공칭) → 물리적 착륙 가능, 탐색 실패
- 원인: 착지 안전 조건의 자세 $\le5^\circ$·각속도 $\le10^\circ$/s를 pitch·roll 두 축이 동시 충족 필요, 평면 탐색 잡음(logStd $-1.1$)의 측방 적용 시 무작위 접촉 대부분 roll 각속도 위반 → 성공 보상 미경험 상태의 상승·중단 수렴
- 설정 (세 비교군 공통, 학습 에피소드 한정, 평가는 공칭 계약):

| 항목 | 값 | 의미 |
|---|---|---|
| `rl.lateralInitialLogStd` | $-2.3$ | $a_y$ 초기 탐색 잡음 ($a_x,a_z$는 $-1.1$ 유지) |
| `rl.touchdownAttitudeCurriculumScale` | 2.0 | 착지 자세·각속도 허용치 초기 배율, 커리큘럼 진행에 따라 1로 복귀 |

- 통제 실험 (baseline, 시작 단계 학습 에피소드 SAFE_ABORT 비율):

| 조건 | 125회 | 375회 | 비고 |
|---|---:|---:|---|
| 수정 없음, 다른 시드 | 93% | 92% | 1300회까지 97% |
| 측방 UGV 운동 제거 | 84% | 86% | 1400회까지 94% |
| 측방 탐색 잡음만 | 85% | 92% | 650회 이후 탈출 |
| 착지 자세 커리큘럼만 | 90% | 91% | 1000회 무렵 탈출 |
| 두 설정 함께 | 77% | 16% | 가장 빠른 탈출 |
| 2차원, 다른 시드 (대조) | 61% | 41% | 375회 착륙 31% |

- 추가 학습 설정 (2차 통제 실험, 착지 시도 성공률 향상):

| 항목 | 값 | 의미 |
|---|---|---|
| `rl.initialLogStd` | $-1.6$ | $a_x,a_z$ 초기 탐색 잡음 (평면 $-1.1$) |
| `rl.trackAuthorizationCurriculumScale` | 2.0 | 최근 검출 허용 ×2·최소 신뢰도 ÷2에서 공칭으로 복귀 |

- 잔여 장벽 진단 (위 설정의 전체 2500회 학습 결과, 공칭 착륙 0%):
  - 정책 거동: 공칭 포착률 73~87%, 패드 위 7~8 cm 체공 후 TASK_TIMEOUT
  - 체공 중 상태: 검출 95~96%, 착륙 금지 3~8%, 수평 오차 2 cm → 승인된 상태의 자발적 미착지
  - 강제 착지 시험(정책 수평 제어 + 마지막 하강만 강제, 30회): 3차원 성공 3~5·SAFE_ABORT 12~24, 2차원 성공 21~25·SAFE_ABORT 3~6
  - 원인 ①: 고도 10 cm 이하 패드 중심점 소실 → 승인 해제·중단 (§6.1 최종 하강 단계로 해결)
  - 원인 ②: 패드 근처 결정 간 가속 명령 변화 2D 대비 2~2.5배, 접촉 순간 자세 각속도 중앙값 8~15°/s(허용 10°/s) → 행동 변화량 비용으로 억제
- 계약 보완 후 통제 실험 (baseline, 1200회 압축 커리큘럼, 공칭 검증 40 seed 결정론적 평가):

| 조건 | 공칭 착륙 (마지막) | 공칭 착륙 (검증 선택) |
|---|---:|---:|
| 보완 계약 기본값 | 12/40 | 10/40 |
| 기본값 + 커리큘럼 하한 45%→90% | 12/40 | 14/40 |
| 기본값, 다른 시드 | 0/40 | 0/40 |
| 기본값 + 커리큘럼 단계 0.05 | 0/40 | 0/40 |
| 행동 변화량 비용 없음 | 1100회 중단 시점 학습 중 공칭 착륙 3% | 미평가 |
| 보완 전 계약 (전체 2500회) | — | 0% |

- 해석: 보완 계약에서 첫 공칭 착륙 확인, 학습 결과의 시드 의존성 큼 (6개 중 2개 성공 계열, 두 계열은 360회까지 동일 경로)
- 압축 커리큘럼 기준 수치이며 2500회 전체 일정 결과는 별도 실행으로 확인 필요
- 설정 위치: [defaultSpatialConfig.m](../src/orchestration/+landing2d/+config/defaultSpatialConfig.m), 2차원 설정·학습 서명 불변

## 9. 검증

- 2차원 회귀: 수정 전후 fingerprint·학습 서명·롤아웃 궤적·1회 학습 가중치 비트 동일, 기존 2차원 체크포인트 재학습 없이 로드
- self-test: 10개 검사 중 9번째 `spatial-3d` (평면 환원·fingerprint 동일성·37차원 packet·14채널 그래프·3차원 행동·측방 footprint·학습 커리큘럼 공칭 복귀·최종 하강 단계 진입/유지/해제)
- 통합: 3차원 smoke pipeline, 3차원 고정 시나리오 평가·그림, `run_live` 3차원 화면 실행
- 성능 수치: 보완 계약의 전체 2500회 시험 결과 미생성, §8 수치는 압축 커리큘럼 통제 실험 한정

## 10. 한계

- yaw 축·측방 외란 미모델링
- roll 루프의 pitch 파라미터 공유
- Simulink 백엔드 미지원 (블록 신호 형식이 평면 계약 고정)
- 실시간 대시보드(`liveDashboard`)·Monte Carlo 요약 궤적은 $x$–$z$ 측면 투영, 3차원 궤적은 별도 탭·그림
