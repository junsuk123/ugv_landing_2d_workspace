# 최종 문서 색인

모든 문서는 현재 평면 `planar_visibility_v2`, 온톨로지–R-GAT PPO v3.19, train seed 1의 최종 체크포인트만 설명한다. 중간 실험 수치와 폐기된 상대궤적 그림은 포함하지 않는다.

| 문서 | 현재 내용 |
|---|---|
| [시스템·실험 단일 명세](CURRENT_SYSTEM_KO.md) | 환경, 관측, v3.19 graph, PPO, 평가 계약 |
| [최종 검증](VALIDATION_KO.md) | held-out 100회, validation 20×20, V2015 1,000회 |
| [공통 관측](COMMON_OBSERVATION_KO.md) | 12차원 causal observation과 정보 경계 |
| [온톨로지–R-GAT](ONTOLOGY_GRAPH_STATE_KO.md) | 7노드 특징, 신뢰도 가중, typed attention, readout |
| [모듈 지도](MODULE_MAP_KO.md) | 진입점과 소스 책임 |
| [기호](NOTATION_KO.md) | 현재 수식 기호와 분산 정의 |
| [그림 안내](ONTOLOGY_VIEW_KO.md) | README·논문·PPT용 최종 그림 |
| [Simulink](SIMULINK_KO.md) | 선택 backend 계약 |
| [3차원 옵션](SPATIAL_3D_KO.md) | 최종 2차원 결과와 분리된 선택 확장 |
| [최종 연구 보고서](refactor/FINAL_REPORT.md) | 논문·보고서용 결론과 한계 |
| [궤적 일관성·실행시간](refactor/CONSISTENCY_RUNTIME_REVIEW.md) | 최종 분산 평가와 추론 비용 |
| [설정표](refactor/CONFIGURATION.md) | 최종 주요 설정값 |
| [보상 근거](refactor/REWARD_RATIONALE.md) | 공통 `reward_v5` |
| [PPT 제작 지시서](refactor/PPT_AGENT_PROMPT_KO.md) | v3.19 발표자료 단일 기준 |

최종 이미지·PDF·MATLAB FIG·CSV는 [latest_parameter_matched](assets/paper/latest_parameter_matched/README.md)에 있다.
