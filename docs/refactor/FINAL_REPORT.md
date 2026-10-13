# 온톨로지–R-GAT PPO v3.19 최종 연구 보고서

## 연구 질문

동일한 최소 센서 정보, 공통 보상과 동일한 모델 용량에서 물리·센서 관계를 보존한 graph state가 일반 MLP PPO보다 이동 패드 착륙 성능과 sensor-noise 궤적 일관성을 개선하는가?

## 제안

12차원 causal observation을 5개 물리 노드와 2개 센서 품질 노드로 분해한다. `informs`, `conditions`, `couples`, `self` 관계의 typed attention과 factorized grouped readout으로 16차원 graph embedding을 생성한다.

v3.19는 물리 노드에 부드러운 제곱 에너지와 age 기반 연속 confidence를 적용한다. 학습 시 인접 on-policy 상태의 행동 평균 차이에 weight 0.03을 주어 작은 관측 변화에 대한 과도한 출력 변화를 억제한다. 새로운 제어 gate, 추론 guard, 정책 메모리나 핵심 이론은 추가하지 않는다.

## 공정 비교

- 동일 환경·동역학·센서·추정기
- 동일 12차원 관측 원자료
- 동일 `reward_v5`, 행동, 종료
- 동일 4,500 episode와 환경 seed 흐름
- 동일 6,101 trainable parameter
- 평면 direct policy
- raw bypass·action residual·descent gate·inference guard 없음

## 결과

| 평가 | 일반 PPO | v3.19 |
|---|---:|---:|
| Held-out 착륙, n=100 | 95% | **98%** |
| Held-out unsafe | 0% | 0% |
| Held-out timeout | 5% | **2%** |
| Held-out return | 31.8186 | **33.4215** |
| Validation 착륙, 20×20 | 93.50% | **98.75%** |
| Validation 위치 분산 | 4.116811 m² | **0.009430 m²** |
| Validation 법선 분산 | 0.025400 m² | **0.004580 m²** |
| V2015 착륙, n=1,000 | 70.2% | **100.0%** |
| V2015 위치 분산 | 66.732568 m² | **0.002233 m²** |

## 해석

Held-out에서 v3.19는 착륙률을 3%p 높이고 timeout을 3%p 줄였으며 unsafe는 두 방법 모두 0%였다. validation 20×20 집계에서는 위치 분산 99.7709%, 접근 곡면 법선 분산 81.9697% 감소가 확인됐다. V2015 조건부 스트레스 시험은 일반 PPO가 큰 along-track 발산과 timeout을 보이는 동안 v3.19가 궤적을 좁게 유지하는 차이를 시각적으로 보여준다.

단, 착륙 시간 분산은 증가했고 일부 쉬운 validation seed에서는 일반 PPO의 분산이 더 작다. 결과는 단일 학습 seed와 2차원 시뮬레이션에 한정되므로 통계적 보편성이나 형식적 안전성을 주장하지 않는다.

## 최종 그림

![최종 held-out 결과](../assets/paper/latest_parameter_matched/parameter_matched_ontology_evidence.png)

![최종 절대 착륙 궤적](../assets/paper/latest_parameter_matched/trajectory_mc_world_absolute.png)

원자료와 편집용 FIG/PDF: [최종 자산 목록](../assets/paper/latest_parameter_matched/README.md).
