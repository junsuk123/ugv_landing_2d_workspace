# 보상 설계

## 요약

- 세 상태 표현 정책에 단일 보상 함수 공통 적용, 모델별 보상 변경 부재
- 결정 단위 보상: 종료 보상 $-$ 유계 running cost $+$ readiness 진척 $+$ potential shaping의 4항 분해
- potential 항: 종료 potential 0의 semi-MDP potential-based shaping, 최적 정책 불변
- readiness 항: 할인 가중 평균 readiness 차이로 환원되는 유계 dense 신호, hover 누적 보상 부재
- running cost: 항별 $[0,1]$ 유계, 임무 전체 할인 합 최대 약 2.05
- 종료 보상 순서: SUCCESS $>$ TASK_TIMEOUT $>$ SAFE_ABORT $>$ 실패 4종, 공칭 조건에서 할인 후에도 순서 유지
- 커리큘럼: 실패 보상·접지 한계·장기 손실 시간·시나리오 범위의 $\ell$ 선형 완화, 검증·시험은 공칭 조건
- checkpoint 선택 점수 $J$: 위험 접촉 1건 상쇄에 성공 2건 초과 요구

## 기호

- 공통 기호: 기호 정의 문서 준수
- 본 문서 신규 기호

| 기호 | 의미 | 값 |
|---|---|---|
| $B_t$ | 종료 보상, 비종료 결정에서 0 | 종료 보상 절 |
| $C_t$ | running cost | — |
| $c_{goal,t},\;c_{view,t},\;c_{ctrl,t}$ | goal·view·control 비용 | $[0,1]$ |
| $T_{ref}$ | running cost 정규화 시간 | 70 s |
| $\tau_\gamma$ | 할인 시정수 | 70 s |
| $w_g,\;w_v,\;w_u$ | running cost 가중치 | 2.0, 1.0, 0.25 |
| $w_r$ | readiness 진척 가중치 | 8.0 |
| $w_p$ | potential 가중치 | 2.0 |
| $\Phi_t$ | shaping potential | — |
| $L_x,\;L_h$ | goal 비용 수평·고도 길이 척도 | 3 m, 4 m |
| $\varpi$ | goal 비용 수평 비중 | 0.65 |
| $\psi_t\in(0,1]$ | landing readiness | — |
| $\Upsilon_t$ | readiness 위험 지수 | — |
| $h_r$ | readiness 고도 척도 | 1.0 m |
| $v_{x,td},\;v_{z,td}$ | 접지 수평 상대속도·수직속도 한계 | 0.35 m/s, 0.30 m/s |
| $\theta_{td},\;\omega_{td}$ | 접지 pitch·pitch rate 한계 | 5°, 10°/s |
| $h_{td}$ | 접촉면 높이 오프셋 | 0.04 m |
| $T_{loss}$ | 장기 손실 판정 시간 | 공칭 3 s |
| $\iota_t,\;\varsigma_t\in\{0,1\}$ | 하강 금지·중단 요청 지시자 | — |
| $\Gamma_t=\prod_{i\le t}\gamma_{\Delta t,i}$ | 누적 할인, $\Gamma_0=1$ | — |
| $N$ | episode 결정 수 | — |

## 1. 보상 분해

- 결론: 결정 $t$의 보상은 결정 시작 시점(첨자 $t-1$)과 종료 시점(첨자 $t$)의 참값 상태 기반 4항 합

$$
r_t=B_t-C_t+w_r\left(\psi_t-\psi_{t-1}\right)+\gamma_{\Delta t}\Phi_t-\Phi_{t-1}
$$

- $\Delta t$: 실제 결정 경과 시간, 공칭 $\Delta t_p=0.10$ s, 종료 사건 발생 시 사건 시각까지 단축
- 접촉 종료 결정: 종료 시점 상태로 선형 보간 접촉 시각의 접촉 직전 상태 사용
- 참값 사용 범위: 보상·종료 판정·사후 평가 한정, Actor·Critic·그래프 입력 제외
- 종료 보상 지급: episode당 1회
- 모델별 상황 가중치·관계 attention 보상·그래프 보조 보상 부재

## 2. Running cost

- 결론: 세 비용 모두 $[0,1]$ 유계, 시간 적분 정규화로 결정 주기와 무관한 비용 척도

$$
C_t=\frac{\Delta t}{T_{ref}}\left(w_g\,c_{goal,t}+w_v\,c_{view,t}+w_u\,c_{ctrl,t}\right)
$$

### 2.1 Goal cost

$$
c_{goal,t}=\varpi\,\frac{n_x}{1+n_x}+(1-\varpi)\,\frac{n_h}{1+n_h},
\qquad
n_x=\left(\frac{e_x}{L_x}\right)^2,\quad
n_h=\left(\frac{h}{L_h}\right)^2
$$

- $n_x,n_h$: 정규화 제곱 오차 (본 절 한정 신규 기호)
- 유계 변환 $u/(1+u)$: 원거리 오차의 비용 포화, 초기 오차 크기에 따른 gradient 폭주 억제
- 수평·고도 분리 가중: 고도 감소만으로 수평 이탈 상쇄 방지
- $\varpi=0.65$: 수평 추종 우선, 수평 정렬 이전 하강 억제

### 2.2 View cost

$$
c_{view,t}=\begin{cases}
\min\!\left(1,\left(\dfrac{\tilde\beta_t}{\varphi/2}\right)^2\right), & d_t=1\ \wedge\ \text{bearing 유효},\\[4pt]
1, & \text{그 외}
\end{cases}
$$

- $\varphi=50^\circ$, $\tilde\beta_t$: 결정 종료 시점 측정 bearing
- 종료 사건 결정: 사건 직전 마지막 측정 사용, 접촉 이후 측정 생성 제외
- 광축 중심 유지 유도, FOV 경계 접근의 연속 비용, 비가시 상태 최대 비용

### 2.3 Control cost

$$
c_{ctrl,t}=\tfrac12\lVert\bar a_t\rVert_2^2,\qquad \bar a_t=\tanh(u_t)\in[-1,1]^2
$$

- 기준 행동: 안전 감독기 $\Pi_s$ 적용 이전 정규화 행동
- R-GAT의 경우 $u_t$에 관계 residual $\tilde\delta_t$ 포함
- 과도한 가속도 명령 억제, 최대값 1

### 2.4 유계성

- 결정당 상한: $C_t\le\frac{\Delta t}{T_{ref}}(w_g+w_v+w_u)=3.25\,\frac{\Delta t}{70}$
- 임무 전체 할인 합 상한: $\sum_t\Gamma_{t-1}C_t\lesssim3.25\left(1-e^{-T/\tau_\gamma}\right)\le2.05$ ($T\le T_{\max}=70$ s)
- 의미: running cost만으로 종료 보상 순서 역전 불가 (5절 분석)

## 3. 할인율

- 결론: 연속 시간 할인의 이산화, 단축 결정과 공칭 결정의 일관된 할인

$$
\gamma_{\Delta t}=\exp\!\left(-\frac{\Delta t}{\tau_\gamma}\right),\qquad \tau_\gamma=70\ \text{s}
$$

- 공칭 결정: $\gamma_{\Delta t_p}=e^{-0.1/70}\approx0.99857$
- 시간 일관성: 두 결정 할인의 곱 $=$ 합산 경과 시간의 할인, 사건 단축 결정의 할인 왜곡 부재
- $\tau_\gamma=T_{\max}$: 유효 지평이 임무 전체 포괄, 임무 종료 시점 할인 $e^{-1}\approx0.368$
- GAE·return 목표에 동일 결정별 $\gamma_{\Delta t}$ 적용

## 4. Shaping 항

### 4.1 Potential shaping

- 결론: 종료 potential 0의 semi-MDP potential-based shaping, 최적 정책 불변

$$
\Phi_t=\begin{cases}-w_p\,c_{goal,t}, & \text{결정 } t\ \text{비종료},\\ 0, & \text{결정 } t\ \text{종료}\end{cases}
\qquad
F_t=\gamma_{\Delta t}\Phi_t-\Phi_{t-1}
$$

- 할인 합의 telescoping: $\sum_{t=1}^{N}\Gamma_{t-1}F_t=\Gamma_N\Phi_N-\Phi_0=-\Phi_0$
- $-\Phi_0$: 초기 상태만의 함수, 정책 무관 상수
- 결과: 가변 결정 시간 포함 최적 정책 불변 (Ng·Harada·Russell 1999의 potential-based shaping 조건)
- 역할: 접근 진척 신호의 시간 재분배, 희소 종료 보상의 credit assignment 보조

### 4.2 Landing readiness

- 결론: 접지 가능 상태와의 거리를 $(0,1]$ 지수로 요약, 진척 차분만 보상

접지 목표 속도:

$$
\Delta v_x^{*}=-\mathrm{sgn}(e_x)\min\!\left(v_{x,td},\,0.6\lvert e_x\rvert\right),
\qquad
v_z^{*}=-\min\!\left(0.8\,v_{z,td},\,0.5\,h^{+}\right),
\qquad h^{+}=\max(h,0)
$$

위험 지수와 readiness:

$$
\Upsilon_t=\left(\frac{e_x}{L_{pad}}\right)^2+\left(\frac{h^{+}}{h_r}\right)^2
+\left(\frac{\Delta v_x-\Delta v_x^{*}}{v_{x,td}}\right)^2
+\left(\frac{v_z-v_z^{*}}{v_{z,td}}\right)^2
+\left(\frac{\theta}{\theta_{td}}\right)^2
+\left(\frac{\omega}{\omega_{td}}\right)^2
$$

$$
\psi_t=\exp\!\left(-\tfrac12\min(\Upsilon_t,100)\right)
$$

- $\Delta v_x^{*},v_z^{*}$: 수평 오차 비례 접근 속도·고도 비례 하강 속도의 목표 (신규 기호)
- 정규화 척도: 접지 판정 한계 자체, readiness 1의 의미 $=$ 접지 조건 중심
- $L_{pad}=0.5$ m, $h_r=1.0$ m
- $\min(\Upsilon,100)$: 원거리 상태의 수치 하한 $e^{-50}$ 보장
- 학습 episode: $v_{x,td},v_{z,td}$에 커리큘럼 배율 적용 (7절)

진척 항의 할인 합:

$$
\sum_{t=1}^{N}\Gamma_{t-1}\,w_r(\psi_t-\psi_{t-1})
=w_r\left(\langle\psi\rangle_\Gamma-\psi_0\right),
\qquad
\langle\psi\rangle_\Gamma=\sum_{t=1}^{N}\Gamma_{t-1}(1-\gamma_{\Delta t,t})\,\psi_t+\Gamma_N \psi_N
$$

- $\langle\psi\rangle_\Gamma$: 가중치 합 1의 할인 가중 평균 readiness (신규 기호)
- 범위: $w_r(\langle\psi\rangle_\Gamma-\psi_0)\in[-w_r \psi_0,\,w_r(1-\psi_0)]$, episode 길이와 무관한 상한 $w_r=8$
- 비할인 합: $w_r(\psi_N-\psi_0)$, 제자리 hover의 추가 보상 0
- 이탈 시 이전 이득 반환, hover reward farming 방지
- 정책 불변 아님: 이른 시점의 readiness 도달 선호, 의도된 dense 유도
- 상한 $8<$ SUCCESS와 TASK_TIMEOUT의 종료 보상 차 37, 종료 결과 선호 역전 불가 (동일 종료 시각 기준)

## 5. 종료 보상

- 결론: SUCCESS $>$ TASK_TIMEOUT $>$ SAFE_ABORT $>$ 실패 4종의 엄격한 순서

| 종료 결과 | $B$ | 근거 |
|---|---:|---|
| SUCCESS | +25 | 유일한 양의 종료 결과 |
| TASK_TIMEOUT | −12 | 표적 유지 상태의 임무 미완료 |
| SAFE_ABORT | −15 | 표적 포기에 의한 조기 종료 |
| UNSAFE_CONTACT | −40 | 허가 접촉의 기계적 한계 위반 |
| UNAUTHORIZED_CONTACT | −40 | 하강 금지·중단 요청 중 접촉 |
| MISSED_PAD_CONTACT | −40 | 패드 footprint 밖 접촉 |
| SAFETY_ENVELOPE_VIOLATION | −40 | 동역학·고도 안전 영역 이탈 |

- TASK_TIMEOUT $>$ SAFE_ABORT: 낮은 비용의 의도적 중단이 학습 지름길로 작동하는 현상 방지, 시야 유지 시간 초과의 상대 우대
- 실패 4종 동일 값: 실패 유형 간 선호 유도 배제

할인 후 순서 유지 조건 (종료·running 성분 한정, 공칭 조건):

| 비교 | 조건 | 판정 |
|---|---|---|
| TASK_TIMEOUT vs SAFE_ABORT | $12e^{-T_d/\tau_\gamma}<15e^{-T'/\tau_\gamma}\iff T'-T_d<15.6$ s | $T'\le T_d$에서 항상 성립 |
| 실패 vs SAFE_ABORT | $40e^{-T/\tau_\gamma}>15e^{-T'/\tau_\gamma}\iff T-T'<68.7$ s | 중단 최소 시각 $T'\ge T_{loss}+8=11$ s, $T\le70$ s에서 성립 |
| 실패 최선 vs 중단 최악 | $-40e^{-1}=-14.72$ vs $-15e^{-11/70}-0.47=-13.29$ | 실패가 항상 하위 |

- $T,T'$: 실패·중단 종료 시각 (본 표 한정)
- readiness 항(폭 $w_r=8$) 포함 시 엄밀 보장 제외, 4.2절 상한 기준의 근사 순서
- 대표 궤적 10종의 정확 할인 return 점검 (running cost·종료 보상만 사용, 고정 비용·지속시간 가정)

| 대표 궤적 | 지속시간 | 종료 결과 | 할인 return |
|---|---:|---|---:|
| 효율 착륙 | 10 s | SUCCESS | 21.61 |
| 단기 손실 복구 후 착륙 | 25 s | SUCCESS | 17.20 |
| 지연 착륙 | 40 s | SUCCESS | 13.69 |
| 패드 근처 hover 후 마감 | 70 s | TASK_TIMEOUT | −4.67 |
| 진동 접근 후 마감 | 55 s | TASK_TIMEOUT | −6.69 |
| 불필요 손실 후 중단 | 20 s | SAFE_ABORT | −11.84 |
| 적정 중단 | 5 s | SAFE_ABORT | −14.16 |
| 후기 충돌 | 60 s | UNSAFE_CONTACT | −18.28 |
| 비가시 비허가 접촉 | 12 s | UNAUTHORIZED_CONTACT | −34.07 |
| 고속 충돌 | 2 s | UNSAFE_CONTACT | −39.00 |

- 결과 유형 간 순서 유지 확인, 동일 유형 내 이른 성공·늦은 실패 우대의 할인 효과 확인
- 적정 중단 5 s: 공칭 중단 최소 시각 미만의 가상 궤적, 순서 점검 전용

## 6. 종료 판정

- 결론: 물리 적분 시점마다 고정 우선순위 판정, 접촉 분류는 사건 직전 측정 문맥 기준

| 순위 | 결과 | 조건 |
|---:|---|---|
| 1 | 접촉 사건 | $h$의 $h_{td}=0.04$ m 또는 0 하향 통과, 선형 보간 접촉 시각의 접촉 직전 상태로 분류 |
| 1a | MISSED_PAD_CONTACT | $\lvert e_x\rvert>L_{pad}$ |
| 1b | UNAUTHORIZED_CONTACT | footprint 내, $\iota_t=1\ \vee\ \varsigma_t=1$ |
| 1c | UNSAFE_CONTACT | 허가 접촉, $\lvert\Delta v_x\rvert\le v_{x,td}$·$\lvert v_z\rvert\le v_{z,td}$·$\lvert\theta\rvert\le\theta_{td}$·$\lvert\omega\rvert\le\omega_{td}$ 중 하나 이상 위반 |
| 1d | SUCCESS | footprint 내·허가·기계적 안전 |
| 2 | SAFETY_ENVELOPE_VIOLATION | 동역학 hard envelope 위반, $z>25$ m, $z<0$, 비유한 상태 |
| 3 | SAFE_ABORT | $\varsigma_t=1$, 요청 후 경과 $\ge8$ s, $h\ge1.0$ m, $\lvert v_z\rvert\le0.10$ m/s |
| 4 | TASK_TIMEOUT | 시나리오 마감 $T_d$ 도달 |

- 접촉 우선: 같은 적분 구간 내 동시 사건의 물리적 선행 사건 우선 처리
- 접촉 판정의 측정 갱신 선행: 접촉 이후 정보의 관측 기억 유입 차단

결정 문맥 갱신 (인과 추적 상태만 사용):

- 재포착: 추적 초기화 $\wedge$ $\Delta t_{\mathrm{loss}}\le0.5$ s $\wedge$ $c_k\ge0.25$
- 중단 요청 설정: $\varsigma_t=0\wedge\Delta t_{\mathrm{loss}}\ge T_{loss}$
- 중단 요청 해제: $\varsigma_t=1\wedge$ 재포착, 장기 손실의 비가역 판정 배제
- 하강 금지: $\iota_t=\lnot$재포착 $\vee\ \varsigma_t$

## 7. 커리큘럼 완화

- 결론: 학습 episode 생성만 난이도 $\ell\in[0,1]$의 선형 함수로 완화, 접촉 분류 규칙과 검증·시험 조건 불변

| 항목 | $\ell$ 함수 | $\ell=0$ | $\ell=1$ (공칭) |
|---|---|---:|---:|
| 실패 4종 종료 보상 | $B_{fail}(\ell)=-20-20\ell$ | −20 | −40 |
| 접지 속도 한계 배율 | $2-\ell$ ($v_{x,td},v_{z,td}$ 공통) | 2.0 | 1.0 |
| 장기 손실 판정 시간 $T_{loss}$ | $12-9\ell$ s | 12 s | 3 s |
| $v_1,a_2$ 범위 배율 | $0.15+0.85\ell$ | 0.15 | 1.0 |
| $T_1$ 범위 | $[0.10,0.30]+([0.5,4]-[0.10,0.30])\ell$ s | 0.10–0.30 s | 0.5–4 s |
| 초기 고도 배율 | $[0.025,0.05]+([1,1]-[0.025,0.05])\ell$ | 0.025–0.05 | 1.0 |

- $B_{fail}(\ell)$: $\max(B_{fail}^{nom},-20)+(B_{fail}^{nom}-\max(B_{fail}^{nom},-20))\ell$, $B_{fail}^{nom}=-40$
- 초기 고도: 공칭 $h_0\in[4,8]$ m에 배율 적용, $\ell=0$에서 0.1–0.4 m
- SUCCESS·SAFE_ABORT·TASK_TIMEOUT: 완화 부재
- 실패 보상 하한 −20: SAFE_ABORT −15 미만 유지, 완화 단계에서도 위험 접촉의 중단 대비 우대 부재
- 무작위 초기 정책의 단일 충돌이 다수 근접 접촉 전이의 신호를 상쇄하는 현상 완화
- 장기 손실 판정 완화: 초기 탐색 단계의 조기 중단 고착 완화
- $T_1$ 최소 범위: 쉬운 episode에서도 패드 가속 사건 경험 보장

난이도 진행:

- 승급: 평가 창(25 iteration) 현재 난이도 학습 착륙률 $\ge0.10$의 3창 연속 시 $\ell\leftarrow\min(1,\ell+0.10)$
- 예정 하한: iteration $i\le750$에서 0, 이후 $(i-750)/1250$ 선형 증가, iteration 2000에서 1.0
- 갱신: $\ell\leftarrow\max(\ell,\ \text{예정 하한})$
- batch 6 episode 구성: easy 1 ($\ell=0$), bridge 1 ($\ell/2$), current 4 ($\ell$)
- easy replay: 학습 종료까지 $B_{fail}=-20$ 유지, 접지 사례 망각 방지

한계:

- $\ell=0$ 할인 순서: 실패 $-20$과 중단 $-15$의 할인 순서 유지 조건 $T-T'<70\ln(4/3)\approx20.1$ s, 늦은 실패의 이른 중단 대비 우대 가능성 잔존
- 해당 완화의 적용 범위: 저고도 easy episode 한정

## 8. Checkpoint 선택 점수

- 결론: 결과 유형 순서를 고정 가중치로 인코딩한 검증 점수, 위험 접촉 최우선 억제

$$
J=1000\,p_s-2500\,p_u-100\,p_a-10\,p_\tau+\bar G
$$

- 평가 집합: $\mathcal S_{val}$ 100 seed, 공칭 조건, 결정론 정책
- $p_u$: 실패 4종 합산 비율, $\bar G$: 비할인 평균 return
- 위험 접촉 1건(−25점) 상쇄: 성공 2건 초과(+10점/건) 필요
- 중단(−1점/건)과 시간 초과(−0.1점/건) 차등: 낮은 비용 중단 지름길 억제
- $\bar G$: 동률 결과율 간 미세 순위 결정
- 후보 자격: $\ell\ge1.0$, 쉬운 커리큘럼 checkpoint의 최종 선택 배제
- 관계 적응 구간(iteration $>2250$) R-GAT: 기존 최고 대비 $J$ 개선 $>5.0$ 요구, 검증 seed 과적합 억제

## 9. 세 모델 공통성

- 결론: 보상·종료·커리큘럼·할인·안전 감독기 전 항목 동일, 상태 표현만 상이

| 공통 항목 | 적용 |
|---|---|
| $c_{goal},c_{view},c_{ctrl}$ | 동일 |
| readiness 진척·potential shaping | 동일 |
| 종료 보상·종료 판정 순서 | 동일 |
| 커리큘럼 완화 일정 | 동일 |
| 할인율 $\gamma_{\Delta t}$ | 동일 |
| 안전 감독기 $\Pi_s$ | 동일 |
| 선택 점수 $J$ | 동일 (R-GAT 관계 적응 구간 선택 여유 5.0만 추가) |

## 10. 설계 경위

- 결론: 희소 성공 보상 문제를 진척 차분·선택 자격·순서 분리로 대응

| 관찰된 문제 | 대응 |
|---|---|
| 성공 종료의 극단적 희소성 | readiness 진척·potential shaping의 dense 신호 |
| 절대 readiness 보상의 패드 근처 hover 누적 | 진척 차분 보상 전환 |
| SAFE_ABORT 고착 | TASK_TIMEOUT $>$ SAFE_ABORT 순서, $J$의 중단 가중 강화 |
| 쉬운 커리큘럼 checkpoint 선택 | $\ell\ge1.0$ 자격 조건 |
| 커리큘럼 정체 | 예정 난이도 하한의 공칭 과제 강제 노출 |
| 고난이도 전환 후 접지 망각 | easy·bridge replay |
| 완화 실패 보상의 고속 하강 지름길 | 완화 시작값 −20 제한 (SAFE_ABORT 미만 유지) |
