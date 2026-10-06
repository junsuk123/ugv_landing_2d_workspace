# 문서 색인

## 요약

- 문서 체계: 문제 정의·시스템 모델·알고리즘·평가의 이론 문서 구성
- 공통 기호: [기호 정의](NOTATION_KO.md) 단일 기준
- 결과 기준: 시험 seed 집합 $\mathcal S_{te}=\{3001,\dots,3100\}$ 100개 평가
- 수록 범위: 최종 알고리즘·최종 평가 결과 한정

## 진입 문서

- 결론: 전체 README의 결론·결과·실험 설정 우선 참조

| 문서 | 내용 |
|---|---|
| [전체 README](../README.md) | 결론·결과·POMDP 정의·알고리즘·실험 설정·평가 프로토콜 |
| [연구 개요](../README_KO.md) | 문제 정의·방법 개요·핵심 결과 요약 |
| [기호 정의](NOTATION_KO.md) | 전 문서 공통 기호 체계 |

## 이론 문서

- 결론: 시스템 모델 → 상태 표현 → 보상 → 알고리즘 → 평가 순서의 참조 구조

| 문서 | 내용 |
|---|---|
| [시스템 모델](refactor/SYSTEM_SPEC.md) | 동역학·패드 운동·센서·행동·안전 감독기·종료 조건 |
| [온톨로지 그래프 상태 설계](ONTOLOGY_GRAPH_STATE_KO.md) | 9노드·26간선·R-GAT 수식·Actor/Critic 결합 |
| [보상 설계](refactor/REWARD_RATIONALE.md) | 보상 수식·가중치·정보 경계 |
| [실험 파라미터](refactor/CONFIGURATION.md) | 시나리오 분포·seed 분할·PPO·커리큘럼 설정 |
| [알고리즘 구성](MODULE_MAP_KO.md) | 인지·추정·그래프·정책·감독기·학습 알고리즘 구성 |
| [평가 프로토콜·결과](VALIDATION_KO.md) | 시험 결과·대표 시나리오·안정성 지표 |
| [관계 해석 지표](ONTOLOGY_VIEW_KO.md) | attention·관계 residual·그림 해석 |
| [연구 결과 보고](refactor/FINAL_REPORT.md) | 방법·결과·제한·최종 판정 |

## 그림

- 결론: 파이프라인·그래프 구조와 평가 결과 그림의 분리 제시

| 그림 | 내용 |
|---|---|
| [시스템 파이프라인](assets/pipeline.svg) | 세 비교군과 공통 환경 |
| [온톨로지 그래프](assets/ontology_graph.svg) | 9개 의미 노드와 관계 유형 |
| [대표 궤적](assets/paper/paper_trajectories.png) | 고정 3시나리오 궤적 |
| [안정성 지표](assets/paper/paper_stability.png) | 6개 안정성 지표 |
| [착륙 가능성](assets/paper/paper_feasibility.png) | authority margin $m_v,m_a,m_T$·하강 금지 원인 |
| [관계 경로 검증](assets/paper/paper_ontology.png) | 온톨로지 신호·관계 residual $\tilde\delta_t$ |
| [Monte Carlo 평가](assets/paper/planar_visibility_monte_carlo.png) | $\mathcal S_{te}$ 평균·1시그마 궤적·결과율 |

## 문서 기준

- 최종 알고리즘·최종 평가 결과 한정 수록
- 중간 설계 기록·폐기 보상 설계·초기 분석 기록 제외
- 기호: [기호 정의](NOTATION_KO.md) 준수, 신규 기호는 첫 등장 위치 정의
