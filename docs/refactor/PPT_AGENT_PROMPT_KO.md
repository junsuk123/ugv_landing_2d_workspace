# 온톨로지–R-GAT PPO v3.19 발표자료 제작 지시서

## 1. 목적

현재 최종 코드와 실제 MATLAB 결과만 사용해 이동 UGV 착륙용 온톨로지–R-GAT PPO v3.19 발표자료를 제작한다. 과거 체크포인트, 중간 수치, 상대궤적 그림과 폐기된 일관성 결과를 사용하지 않는다.

핵심 질문:

> 동일한 12차원 센서 관측, 공통 보상, 동일 환경과 6,101개 파라미터 조건에서 물리·센서 관계를 보존한 온톨로지–R-GAT 상태 표현이 일반 PPO보다 held-out 임무 성능과 sensor-noise 궤적 일관성을 개선하는가?

## 2. 필수 자산

기준 폴더:

`docs/assets/paper/latest_parameter_matched/`

| 용도 | 파일 |
|---|---|
| held-out 종합 | `parameter_matched_ontology_evidence.png` |
| validation 궤적 강건성 | `parameter_matched_consistency.png` |
| validation 학습 곡선 | `parameter_matched_learning_curve.png` |
| V2015 절대 착륙 궤적 | `trajectory_mc_world_absolute.png` |
| 최종 파이프라인 | `current_pipeline.svg` |
| 7노드 온톨로지 | `current_ontology.svg` |
| held-out 원자료 | `heldout_test_v319.csv` |
| validation 집계 | `validation_trajectory_robustness_v319.csv` |
| validation seed별 결과 | `validation_per_seed_v319.csv` |
| V2015 원자료 | `trajectory_mc_world_absolute_summary.csv` |

PNG는 바로 삽입하고 PDF는 벡터 출력, FIG는 MATLAB 편집이 필요할 때만 사용한다. 수치는 CSV에서 그대로 옮긴다.

## 3. 한 문장 결론

> 동일한 12차원 관측과 6,101개 파라미터 조건에서 온톨로지–R-GAT PPO v3.19는 held-out 착륙률을 95%에서 98%로 높이고, validation 20×20의 평균 위치 분산을 4.116811 m²에서 0.009430 m²로 줄였으며, 어려운 V2015 조건부 1,000회 시험에서 100% 착륙과 99.997% 위치 분산 감소를 보였다.

## 4. 공정 비교 계약

| 항목 | 값 |
|---|---|
| 실험 | `planar_visibility_v2` |
| 공간 | $x$–$z$ 평면 |
| 물리/정책 주기 | 0.01/0.10 s |
| 최대 임무 시간 | 70 s |
| 입력 | 공통 12차원 observation |
| 행동 | `[a_x,a_z]`, 축별 2.5/2.0 m/s² |
| 적용 | direct policy |
| 보상 | 공통 `reward_v5` |
| 예산 | 750 update × 6 episode = 4,500 episode |
| 파라미터 | 두 방법 모두 6,101 |
| 학습 seed | 1 |

환경, 센서, 추정기, 관측 원자료, 행동, 보상, 접촉과 종료는 동일하다. 평면에는 안전 감독기·착륙 승인·SAFE_ABORT guard가 없다. 제안 모델에는 raw observation bypass, action residual, descent gate, inference guard가 없다.

## 5. 공통 관측

$$
o_t=[e_x,h,v_{rel,x},\hat v_{G,x},v_z,\sin\theta,\cos\theta,\dot\theta,
I_G,\tau_G,I_D,\tau_D]^\top\in\mathbb R^{12}.
$$

허용 정보는 현재/과거 센서 측정과 인과적 추정뿐이다. 패드 참값, 미래 상태, reward, outcome, tracker 판단, 감독기 문맥과 절대 수평 위치는 제외한다.

## 6. v3.19 온톨로지

노드:

1. RelativePosition
2. RelativeVelocity
3. PadVelocity
4. VerticalMotion
5. Attitude
6. VisionQuality
7. NavigationQuality

접근 곡면과 confidence:

$$
m=\tan(-\theta_C),\qquad e_c=e_x-mh,\qquad
v_c=v_{rel,x}-mv_z,
$$

$$
c_G=\max(0,1-0.5\tau_G),\qquad
c_D=\max(0,1-0.5\tau_D).
$$

물리 노드는 `abs`/`max` 대신 부드러운 제곱 에너지와 signed 값을 사용한다. 영상·측위 age confidence는 graph feature만 연속적으로 가중한다. 제어 gate로 표현하지 않는다.

관계는 `informs`, `conditions`, `couples`, `self` 4종이며 의미 간선 9개와 자기 간선 7개다.

## 7. R-GAT과 PPO

$$
\ell_{ji}^{(r)}=\operatorname{LReLU}_{0.2}
\left(a_r^\top[W_rx_j\Vert W_rx_i\Vert e_r]\right),
$$

$$
\alpha_{ji}^{(r)}=\frac{\exp\ell_{ji}^{(r)}}
{\sum_{(k\to i,r')}\exp\ell_{ki}^{(r')}+10^{-9}}.
$$

Factorized grouped readout:

$$
g_t=\tanh\left(b_g+\sum_{k=1}^{7}(W_ch_k)\odot w_k\right)
\in\mathbb R^{16}.
$$

| 구성 | 일반 PPO | v3.19 |
|---|---|---|
| Actor | 12–48–48–2 | R-GAT–16–38–37–2 |
| Critic | 12–48–48–1 | R-GAT–16–35–34–1 |
| 파라미터 | 6,101 | 6,101 |

학습 전용 temporal consistency weight는 0.03이다. 인접 on-policy 상태의 `tanh(mean)` 차이를 state proximity로 가중하며 추론 메모리나 후처리를 추가하지 않는다.

## 8. 최종 수치

### Held-out 100회

| 지표 | 일반 PPO | v3.19 | 변화 |
|---|---:|---:|---:|
| 착륙률 | 95% | **98%** | **+3%p** |
| unsafe | 0% | 0% | 0%p |
| timeout | 5% | **2%** | **−3%p** |
| 평균 return | 31.8186 | **33.4215** | **+1.6029** |
| Actor inference | 0.0699 ms | 0.4540 ms | 정책 주기 내 |

### Validation 20 seed × 20회

| 지표 | 일반 PPO | v3.19 | 감소/변화 |
|---|---:|---:|---:|
| 착륙률 | 93.50% | **98.75%** | **+5.25%p** |
| unsafe | 0% | 0% | 0%p |
| 평균 위치 분산 | 4.116811 | **0.009430 m²** | **99.7709% 감소** |
| 법선 분산 | 0.025400 | **0.004580 m²** | **81.9697% 감소** |
| 최종 상대 x 분산 | 13.793063 | **0.004664 m²** | **99.9662% 감소** |

착륙 시간 분산은 0.108776 s²에서 0.709969 s²로 증가했음을 한계로 병기한다.

### V2015 조건부 1,000회

| 지표 | 일반 PPO | v3.19 |
|---|---:|---:|
| 착륙 | 70.2% | **100.0%** |
| 평균 return | 20.2600 | **34.2780** |
| 평균 위치 분산 | 66.732568 m² | **0.002233 m²** |
| 법선 분산 | 0.401208 m² | **0.001845 m²** |

V2015는 validation에서 고른 어려운 단일 물리 조건에 센서 잡음만 반복한 스트레스 시험이다. held-out 일반화 성능으로 설명하지 않는다.

## 9. 궤적 그림 설명

`trajectory_mc_world_absolute.png`의 왼쪽은 상대궤적이 아니라 월드 절대좌표 $(x_D,z_D)$다.

- 얇은 선: 702개 paired common-success 중 균등 선택한 24개
- 굵은 선: 702개 전체 평균
- band: 702개 전체의 접근 곡면 법선 방향 ±1σ
- 패드: 평균 접지 UGV 위치에 실제 폭 직사각형
- 가로축: 값은 실제 m, 표시 종횡비만 0.15배
- 오른쪽 위: 모든 1,000 run의 pad-relative spread
- 오른쪽 아래: 모든 1,000 run의 착륙률

드론이 뒤로 갔다가 앞으로 가는 것처럼 보이던 상대좌표 해석은 사용하지 않는다.

## 10. 권장 슬라이드 순서

1. 제목과 연구 질문
2. 공정 비교 조건
3. `current_pipeline.svg`
4. 12차원 공통 관측과 정보 경계
5. `current_ontology.svg`
6. v3.19 smooth energy와 age confidence
7. typed R-GAT과 grouped readout
8. 파라미터 정합과 학습 전용 temporal consistency
9. `parameter_matched_learning_curve.png`
10. `parameter_matched_ontology_evidence.png`
11. `parameter_matched_consistency.png`
12. `trajectory_mc_world_absolute.png`
13. V2015 조건부 해석과 held-out 구분
14. 계산 비용
15. 결론과 한계

## 11. 표현 규칙

- 일반 PPO 파랑, v3.19 보라
- 본문 최소 20 pt, 축·범례 최소 14 pt
- `95%→98%`, `0% unsafe`, `6,101=6,101` 표기 고정
- 분산은 반드시 단위 m²와 평가 범위를 표기
- 절대궤적과 pad-relative metric을 혼동하지 않음
- V2015 70.2%를 일반 PPO의 전체 held-out 성능으로 표현 금지
- `모든 조건에서 우월`, `통계적 유의`, `형식적 안전 보장`, `다중 seed 검증 완료` 주장 금지
- 현재 최종 CSV에 없는 과거 수치·지표와 관련 그림 사용 금지
- 코드 변경 과정과 폐기 모델 언급 금지

## 12. 최종 검수

- v3.19, 12차원, 7노드, 4관계, 16간선
- 6,101개 파라미터 동일
- held-out 95%/98%, unsafe 0%/0%, timeout 5%/2%
- validation 93.50%/98.75%, 위치 분산 4.116811/0.009430 m²
- V2015 70.2%/100%, 위치 분산 66.732568/0.002233 m²
- Monte Carlo 왼쪽 월드 절대좌표, 가로 표시 스케일 0.15배, 실제 폭 패드
- 모든 그림이 `latest_parameter_matched`의 현재 파일인지 확인
- PPTX와 PDF의 글꼴·축·범례·잘림을 육안 확인
