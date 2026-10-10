# 현재 시스템·실험 명세

## 1. 범위

- 기준 브랜치: `main`
- 기본 실험: `planar_visibility_v2`
- 진입점: `run.m`, `run_scenario.m`, `run_live.m`
- 공식 비교군: 일반 PPO(`ppo`), 온톨로지–R-GAT PPO(`onto_rgat_ppo`)
- 선택 옵션: Simulink backend, 3차원 확장
- 비교 원칙: 환경·센서·관측 원자료·보상·행동·종료·PPO 예산 동일, 상태 표현만 상이

## 2. 환경과 행동

| 항목 | 값 |
|---|---:|
| 물리 주기 | 0.01 s |
| 정책 주기 | 0.10 s |
| 최대 시간 | 70 s |
| 초기 고도 분포 | 4–8 m |
| UGV 초기 속도 | 0.5–2.5 m/s |
| UGV 가속도 | 0.3–1.5 m/s² |
| 행동 | `[a_x,a_z]` |
| 행동 한계 | 2.5, 2.0 m/s² |

평면 실험은 `direct_policy_v1`. 정책 명령을 안전 감독기나 착륙 승인기가 수정하지 않음. 접촉 성공은 footprint, 상대속도, pitch, pitch-rate의 기계적 조건으로만 판정.

## 3. 센서와 12차원 공통 관측

마커 코너에서 평면 PnP로 UGV 기준점을 복원하고 등속 KF로 UGV 위치·속도를 추정. 미검출 시 예측만 수행. 드론 상태는 융합 측위 사용. 정책에는 다음 12개 값만 제공.

$$
o_t=[e_x,h,v_{rel,x},\hat v_{G,x},v_z,\sin\theta,\cos\theta,\dot\theta,
I_G,\tau_G,I_D,\tau_D]^\top.
$$

절대 수평 위치, 패드 참값, 미래 상태, reward, outcome, tracker 판단, 감독기 문맥은 제외. 일반 PPO는 $o_t$를 직접 사용하고 R-GAT는 동일한 $o_t$의 결정론적 그래프만 사용.

## 4. 온톨로지

### 4.1 노드

| 번호 | 노드 | 주요 근거 |
|---:|---|---|
| 1 | RelativePosition | cross-track, height, vision quality |
| 2 | RelativeVelocity | closure error, relative velocity, vision quality |
| 3 | PadVelocity | estimated UGV velocity |
| 4 | VerticalMotion | vertical speed, height, navigation quality |
| 5 | Attitude | sin/cos pitch, pitch rate, navigation quality |
| 6 | VisionQuality | vision update and age |
| 7 | NavigationQuality | navigation validity and age |

각 노드 6채널: `[primary,signed,secondary,validity,age,typeId]`.

### 4.2 관계

- `informs`: PadVelocity→RelativeVelocity, RelativeVelocity→RelativePosition
- `conditions`: VisionQuality→RelativePosition/RelativeVelocity, NavigationQuality→VerticalMotion/Attitude
- `couples`: RelativePosition→VisionQuality, Attitude→VisionQuality, VerticalMotion→RelativePosition
- `self`: 모든 노드 자기 간선

의미 간선 9개, 자기 간선 7개, 총 16개.

### 4.3 카메라 접근 좌표

$$
m=\tan(-\theta_C),\quad e_c=e_x-mh,\quad v_c=v_{rel,x}-mv_z.
$$

목표는 패드 직상방이 아니라 전방 하향 카메라 광축과 일치하는 접근 곡면.

## 5. R-GAT과 readout

관계별 선형 사상과 관계 embedding을 사용하는 typed attention:

$$
q_{ij}^{(r)}=\operatorname{LReLU}(a_r^T[W_rh_i\Vert W_rh_j\Vert e_r]),
$$

$$
\alpha_{ij}^{(r)}=\operatorname{softmax}_{(i,r)\in\mathcal N(j)}q_{ij}^{(r)},
\qquad z_j=\sum_{(i,r)\in\mathcal N(j)}\alpha_{ij}^{(r)}W_rh_i.
$$

노드 hidden 16, 관계 embedding 4, graph embedding 16. 노드 정체성을 유지하는 factorized grouped readout:

$$
g=\tanh\left(b_g+\sum_{k=1}^{7}(W_ch_k)\odot w_k\right).
$$

raw observation bypass, additive relation residual, descent gate, inference-time guard 없음. Actor/Critic은 독립 encoder 사용.

## 6. 네트워크와 파라미터

| 모델 | Actor | Critic | 전체 |
|---|---:|---:|---:|
| PPO | 3,076 | 3,025 | 6,101 |
| R-GAT PPO | 3,207 | 2,894 | 6,101 |

- PPO: 12–48–48–2 Actor, 12–48–48–1 Critic
- R-GAT PPO: 16–38–37–2 Actor, 16–35–34–1 Critic
- R-GAT encoder: Actor/Critic 각각 1,040개

## 7. 공통 reward_v5

$$
e_x^*=mh,
$$

$$
v_{rel,x}^*=mv_z-0.35(e_x-mh),\qquad
v_z^*=-\min(0.4,0.8h).
$$

goal·수평 속도·수직 속도 potential 가중치 4/4/4. 원거리 오차의 gradient 보존을 위해 수평 running goal cost에 pseudo-Huber 사용. view cost 1, control cost 0.25, readiness 변화 보상 8. 종료 보상 SUCCESS +25, TASK_TIMEOUT −12, 위험 접촉 및 envelope failure −40.

## 8. 학습

- PPO update 750회
- update당 6 episode, 총 4,500 episode
- PPO epoch 8, minibatch 256
- Actor/Critic learning rate 2e-4/5e-4
- R-GAT encoder learning rate 1e-4
- entropy weight 0.004, initial log std −1.0
- 입력 running normalization 비활성
- validation 25 update 간격
- 4–8 m 전체 과업으로 확장되는 공통 performance curriculum
- 학습 전용 reference-driver descent prefix, 정책 transition 제외, 평가 미사용
- behavior cloning·masked-node pretraining·relation-only adaptation 미사용

## 9. 평가와 지표

- validation seeds 2001–2200 중 100개
- held-out test seeds 3001–3200 중 100개
- checkpoint 선택에 test split 미사용
- 임무: 착륙·unsafe·timeout·return
- 일관성: `C_valid`, `D_obs`, `J_policy`
- 효율: 파라미터 수·Actor inference time

`C_valid`: 독립 물리 판정기의 허용 행동 집합에 정책 명령이 속하는 비율. `D_obs`: 동일 외생 궤적에서 센서 잡음 배율 변화에 따른 행동 거리. `J_policy`: 정상 외생 구간의 요청 명령 변화율 RMS.

## 10. 최종 결과

| 지표 | PPO | R-GAT PPO |
|---|---:|---:|
| 착륙 | 95% | 96% |
| unsafe | 0% | 1% |
| timeout | 5% | 3% |
| return | 31.8186 | 32.3719 |
| 공칭 `C_valid` | 77.3288% | 80.7987% |
| 공칭 `D_obs` P95 | 0.074238 | 0.095983 |
| pooled `J_policy` | 4.0996 | 6.6914 |
| 파라미터 | 6,101 | 6,101 |
| inference | 0.035257 ms | 0.169261 ms |

제안 모델은 착륙률, return, `C_valid` 개선. `D_obs`, `J_policy`, unsafe는 일반 PPO 대비 열세. 단일 학습 seed 결과이므로 통계적·안전성 우월 결론 제외.

## 11. 검증 상태

- self-test 13/13 통과
- 표준 smoke pipeline 통과
- S1 양 정책 `SUCCESS`
- Simulink 등가성: replay reward/observation 차이 0, driver 차이 0, 폐루프 최대 reward 차이 $9.89\times10^{-6}$, 종료 사유 동일

## 12. 결과 파일

- 문서·발표 그림: `docs/assets/paper/latest_parameter_matched/`
- MATLAB FIG 포함
- 로컬 원시 MAT·checkpoint 묶음: `results/latest_parameter_matched/`
- PPT 제작 지시서: `docs/refactor/PPT_AGENT_PROMPT_KO.md`
