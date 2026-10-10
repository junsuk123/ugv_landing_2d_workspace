# 발표자료 제작 에이전트 지시서

## 1. 작업 목적

- 주제: 이동 UGV 착륙을 위한 최소 관측 온톨로지–R-GAT PPO
- 기준 코드: 현재 저장소 `main`의 실행 가능한 `planar_visibility_v2`
- 비교 대상: 일반 PPO와 온톨로지–R-GAT PPO
- 핵심 통제: 환경·센서·12차원 관측 원자료·보상·행동·종료·학습 예산 동일
- 핵심 차이: Actor/Critic 상태 표현
- 발표 원칙: 생성된 결과만 사용, 단일 학습 seed의 통계적·안전성 우월 주장 금지

원본:

`C:\Users\user\SynologyDrive\junsuk\세미나\발표\20261012\261012_김준석_드론 자율 착륙을 위한 온톨로지 관계 추론 기반 강화학습 기법.pptx`

원본 PPTX를 덮어쓰지 않고 같은 폴더에 다음 이름으로 저장.

`261012_김준석_드론 자율 착륙을 위한 온톨로지 관계 추론 기반 강화학습 기법_최종.pptx`

## 2. 필수 파일

기준 폴더:

`C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\docs\assets\paper\latest_parameter_matched`

| 용도 | 파일 |
|---|---|
| 종합 결과 | `parameter_matched_ontology_evidence.png` |
| 일관성 지표 | `parameter_matched_consistency.png` |
| 학습 곡선 | `parameter_matched_learning_curve.png` |
| 위험 실패 분석 | `parameter_matched_unsafe_failures.png` |
| 편집용 MATLAB 원본 | 위와 같은 이름의 `.fig` |
| 표 원자료 | 같은 이름의 `.csv` |
| 현재 파이프라인 | `current_pipeline.svg` |
| 7노드 온톨로지 | `current_ontology.svg` |

수치를 재계산하거나 눈대중으로 옮기지 않고 CSV와 본 문서 사용.

## 3. 한 문장 결론

> 동일한 6,101개 파라미터와 동일한 착륙 과업에서, 12차원 센서 관측을 7개 물리·센서 노드와 4개 관계 유형으로 구조화한 온톨로지–R-GAT PPO가 일반 PPO보다 held-out 착륙률, 평균 return, 물리적 유효행동 일관성 `C_valid`를 개선했으나, 관측 잡음 민감도 `D_obs`와 명령 변화율 `J_policy`는 더 높은 결과.

## 4. 실험 계약

| 항목 | 값 |
|---|---|
| 실험 | `planar_visibility_v2` |
| 공간 | x–z 평면 |
| 물리/정책 주기 | 0.01 s / 0.10 s |
| 최대 임무 시간 | 70 s |
| 정책 입력 | 공통 12차원 관측 `o_t` |
| 행동 | `[a_x,a_z]` 정규화 명령 후 축별 한계 적용 |
| 행동 적용 | 평면 direct policy, 안전 감독기·착륙 승인·SAFE_ABORT guard 없음 |
| 보상 | 공통 `reward_v5` |
| PPO 예산 | 750 update × 6 episode = 4,500 episode |
| 평가 | validation 100회, held-out test 100회 |
| 학습 seed | 1개 |
| 비교군 | `ppo`, `onto_rgat_ppo` |

학습 중 기준 구동기 prefix는 두 방법에 동일한 커리큘럼으로만 사용되며 prefix 구간은 PPO transition에서 제외. 평가에는 prefix 미사용.

## 5. 공통 관측

$$
o_t=[e_x,h,v_{rel,x},\hat v_{G,x},v_z,\sin\theta,\cos\theta,\dot\theta,
I_G,\tau_G,I_D,\tau_D]^\top\in\mathbb{R}^{12}.
$$

| 그룹 | 성분 |
|---|---|
| 상대 상태 | `relative_x`, `relative_height`, `relative_vx` |
| 운동·자세 | `ugv_vx`, `drone_vz`, `drone_sinTheta`, `drone_cosTheta`, `drone_pitchRate` |
| 센서 품질 | `ugv_visionUpdated`, `ugv_visionAge`, `drone_navigationValid`, `drone_navigationAge` |

은닉 패드 참값, 미래 상태, 보상, 종료 라벨, 감독기 모드, 착륙 승인 플래그, 절대 수평 위치 제외.

## 6. 제안 온톨로지

### 6.1 노드

1. RelativePosition
2. RelativeVelocity
3. PadVelocity
4. VerticalMotion
5. Attitude
6. VisionQuality
7. NavigationQuality

각 노드는 6채널 특징 `[primary,signed,secondary,validity,age,typeId]` 사용. 모든 값은 12차원 `o_t`의 결정론적 함수.

전방 하향 카메라 접근 곡면:

$$
m=\tan(-\theta_C),\qquad e_c=e_x-mh,\qquad
v_c=v_{rel,x}-mv_z.
$$

`RelativePosition`은 $(e_c,h)$, `RelativeVelocity`는 $(v_c,v_{rel,x})$, `PadVelocity`는 $\hat v_{G,x}$, `VerticalMotion`은 $(v_z,h)$, `Attitude`는 $(\sin\theta,\cos\theta,\dot\theta)$, 품질 노드는 유효도와 경과시간으로 구성.

### 6.2 관계

- `informs`
- `conditions`
- `couples`
- `self`

의미 간선 9개와 자기 간선 7개, 총 16개 간선.

### 6.3 R-GAT

관계 $r$의 간선 $i\rightarrow j$:

$$
q_{ij}^{(r)}=\operatorname{LReLU}\!\left(
a_r^\top[W_rh_i\Vert W_rh_j\Vert e_r]\right),
$$

$$
\alpha_{ij}^{(r)}=
\frac{\exp q_{ij}^{(r)}}{\sum_{(k,r')\in\mathcal N(j)}\exp q_{kj}^{(r')}},
\qquad
z_j=\sum_{(i,r)\in\mathcal N(j)}\alpha_{ij}^{(r)}W_rh_i.
$$

현재 구현은 16차원 관계 상태와 local transform을 결합한 단일 typed-attention 층 사용.

### 6.4 정보보존형 저랭크 readout

7개 노드를 평균으로 합치지 않고 노드별 grouped representation 유지.

$$
U_k=W_c h_k,\qquad
g=\tanh\!\left(b_g+\sum_{k=1}^{7}U_k\odot w_k\right),
\qquad g\in\mathbb{R}^{16}.
$$

- $W_c\in\mathbb{R}^{16\times16}$
- $W_n=[w_1,\ldots,w_7]\in\mathbb{R}^{16\times7}$
- raw observation bypass·additive residual·descent gate 없음
- Actor와 Critic은 독립 R-GAT encoder 사용

## 7. 파라미터 정합

| 구성 | Actor | Critic | 합계 |
|---|---:|---:|---:|
| 일반 PPO | 3,076 | 3,025 | 6,101 |
| 온톨로지–R-GAT PPO | 3,207 | 2,894 | 6,101 |

제안 모델 Actor MLP 16–38–37–2, Critic MLP 16–35–34–1. 각 encoder 1,040개 파라미터. 파라미터 차이 0개.

## 8. 공통 보상

전방 카메라 광축과 일치하는 목표 곡면:

$$
e_x^*=mh,\qquad
v_{rel,x}^*=mv_z-0.35(e_x-mh),
$$

$$
v_z^*=-\min(0.4,0.8h).
$$

bounded goal·수평 속도·수직 속도 potential 가중치 각각 4. 원거리 수평 오차에 pseudo-Huber running cost 적용. 종료 보상 SUCCESS +25, TASK_TIMEOUT −12, 기계적 실패 −40.

## 9. 최종 결과

### 9.1 Held-out 100회

| 지표 | 일반 PPO | 온톨로지–R-GAT PPO | 변화 |
|---|---:|---:|---:|
| 착륙률 | 95% | 96% | +1%p |
| unsafe | 0% | 1% | +1%p |
| timeout | 5% | 3% | −2%p |
| 평균 return | 31.819 | 32.372 | +0.553 |
| 파라미터 | 6,101 | 6,101 | 0 |
| Actor 추론 | 0.0353 ms | 0.1693 ms | 약 4.8배 |

R-GAT 추론시간은 100 ms 정책 주기의 약 0.169%.

### 9.2 일관성

| 지표 | 일반 PPO | 온톨로지–R-GAT PPO | 판정 |
|---|---:|---:|---|
| 공칭 `C_valid` | 77.329% | 80.799% | 제안 +3.470%p |
| 공칭 `D_obs` P95 | 0.074238 | 0.095983 | 일반 PPO 우세 |
| pooled `J_policy` | 4.0996 | 6.6914 | 일반 PPO 우세 |

잡음 배율 0.5/1/2에서 R-GAT `C_valid` 81.821/80.799/76.812%, PPO 77.735/77.329/74.895%.

### 9.3 위험 실패

- 1건, seed 3076, `UNSAFE_CONTACT`
- 종단 pitch rate −11.643 deg/s
- 허용 한계 대비 1.164배
- 위치·수평·수직 속도·pitch는 허용 범위, pitch-rate 단일 위반

### 9.4 학습 선택

- R-GAT 선택 checkpoint: update 525
- validation 착륙률 98%, unsafe 0%, 평균 return 33.27
- test seed는 checkpoint 선택에 미사용

## 10. 슬라이드 구성

1. 제목·연구 질문
2. 비구조 관측 정책의 한계와 공정 비교 조건
3. 전체 파이프라인 — `current_pipeline.svg`
4. 12차원 공통 관측과 정보 경계
5. 7노드 온톨로지 — `current_ontology.svg`
6. typed R-GAT 수식과 관계 유형
7. factorized grouped readout과 raw bypass 부재
8. PPO 결합·공통 reward·학습 커리큘럼
9. 정확한 6,101개 파라미터 정합
10. 학습 곡선
11. held-out 임무 결과
12. `C_valid`, `D_obs`, `J_policy` 동시 보고
13. 위험 실패 1건 분석
14. 계산 비용과 실시간성
15. 결론·한계·향후 다중 seed 검증

## 11. 표현 규칙

- 개조식·두괄식·명사형 종결어미
- 본문 최소 20 pt, 축·범례 최소 14 pt
- PPO 파랑, 온톨로지–R-GAT 보라 유지
- `C_valid`만 단독 제시 금지, `D_obs`·`J_policy`·임무 성공률 병기
- `해석 가능성 = 정책 일관성 보장` 문구 금지
- `안전성 향상`, `통계적 유의`, `전 지표 우월`, `일반 PPO보다 빠름` 주장 금지
- 3차원 결과와 관계 교란 절제 실험을 공식 비교 결과에 포함 금지
- 코드 변경 과정·폐기 모델·과거 파라미터 수·과거 실험 결과 언급 금지

## 12. 최종 검수

- 12차원, 7노드, 4관계, 16간선 표기 일치
- 양 모델 6,101개 표기 일치
- 착륙 95%/96%, unsafe 0%/1%, timeout 5%/3% 일치
- `C_valid` 77.329%/80.799%, `D_obs` 0.074238/0.095983, `J_policy` 4.0996/6.6914 일치
- 모든 그림이 `latest_parameter_matched` 폴더의 최신 파일인지 확인
- 출력 PPTX와 PDF 열림·폰트·잘림·투명도 확인
