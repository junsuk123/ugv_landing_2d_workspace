# 최종 문서 색인

## 핵심 문서

| 문서 | 내용 |
|---|---|
| [최종 구현·결과 보고](refactor/FINAL_REPORT.md) | 구조·결과·제한·최종 판정 |
| [온톨로지 그래프 상태 설계](ONTOLOGY_GRAPH_STATE_KO.md) | 9노드·26간선·R-GAT 수식·Actor/Critic 결합 |
| [시스템 명세](refactor/SYSTEM_SPEC.md) | 환경·센서·행동·동역학·안전·종료 |
| [공통 보상](refactor/REWARD_RATIONALE.md) | reward 수식·가중치·정보경계 |
| [설정·데이터 계약](refactor/CONFIGURATION.md) | 버전·seed·시나리오·PPO·checkpoint |
| [검증 결과](VALIDATION_KO.md) | held-out 결과·대표 시나리오·안정성 지표 |
| [모듈 지도](MODULE_MAP_KO.md) | 기능별 코드 위치 |
| [시각화 안내](ONTOLOGY_VIEW_KO.md) | figure·CSV 해석 |

## 최종 자산

| 자산 | 내용 |
|---|---|
| [시스템 파이프라인](assets/pipeline.svg) | 세 비교군과 공통 환경 |
| [온톨로지 그래프](assets/ontology_graph.svg) | 9개 의미 노드와 typed relation |
| [대표 궤적](assets/paper/paper_trajectories.png) | 고정 3시나리오 궤적 |
| [안정성 지표](assets/paper/paper_stability.png) | 6개 안정성 metric |
| [착륙 가능성](assets/paper/paper_feasibility.png) | authority margin·inhibit 원인 |
| [관계 경로 감사](assets/paper/paper_ontology.png) | ontology signal·relation residual |

## 상태 파일

- [최종 진행 상태](refactor/progress.json)
- [26필드 registry](refactor/feature_registry_sim2d.json)
- [seed manifest](refactor/scenario_manifest_v2.json)
- [정적 검사 상태](static_checks.json)

## 문서 기준

- 최신 코드·체크포인트·평가 결과만 수록
- 중간 설계 기록·레거시 보상 가중치 설명·초기 감사 기록 제외
- 단일 기준 문서 체계 확정
- 이전 기록 복구 경로: Git 이력
