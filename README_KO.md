# 이동 UGV 착륙 온톨로지–R-GAT PPO v3.19

이 문서는 현재 최종 버전만 요약한다. 상세 내용은 [기본 README](README.md)와 [현재 시스템 명세](docs/CURRENT_SYSTEM_KO.md)를 따른다.

![최종 held-out 결과](docs/assets/paper/latest_parameter_matched/parameter_matched_ontology_evidence.png)

## 핵심 결과

| 평가 | 일반 PPO | 온톨로지–R-GAT PPO v3.19 |
|---|---:|---:|
| Held-out 착륙률, n=100 | 95% | **98%** |
| Held-out unsafe | 0% | 0% |
| Held-out timeout | 5% | **2%** |
| Held-out 평균 return | 31.8186 | **33.4215** |
| Validation 착륙률, 20×20 | 93.50% | **98.75%** |
| Validation 평균 위치 분산 | 4.116811 m² | **0.009430 m²** |
| 파라미터 | 6,101 | 6,101 |

![최종 validation 궤적 분산](docs/assets/paper/latest_parameter_matched/parameter_matched_consistency.png)

![최종 V2015 절대 착륙 궤적](docs/assets/paper/latest_parameter_matched/trajectory_mc_world_absolute.png)

V2015 조건부 1,000회 sensor-noise Monte Carlo에서 착륙률은 70.2% 대 100.0%, 평균 위치 분산은 66.732568 m² 대 0.002233 m²이다. 왼쪽은 월드 절대좌표, 가로축 값은 실제 m, 표시 종횡비만 0.15배이며 패드는 실제 폭 직사각형이다.

## 최종 구조

- 공통 12차원 causal observation
- 7노드 × 6채널, 4관계, 16간선
- 16차원 R-GAT과 factorized grouped readout
- 영상·측위 age 기반 연속 신뢰도 가중치 0.5
- on-policy temporal consistency weight 0.03
- raw bypass·gate·guard 없음
- 일반 PPO와 제안 모델 모두 6,101 trainable parameter

## 실행

```matlab
run
run_trajMC
```

최종 그림과 원자료: [docs/assets/paper/latest_parameter_matched](docs/assets/paper/latest_parameter_matched/README.md)
