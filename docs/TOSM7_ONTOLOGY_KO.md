# 온톨로지 문서 위치 변경

현재 공개 실행 구조는 **4노드 관계 문맥 잔차 후보 `relational_residual_v5`**다. v4의 특징·파라미터·수식은 유지하고 Q→T, R→T, R→U 간선을 추가한다. 이전에는 R만 관계 정보를 받았지만 이제 T/U/R 표현에 관계 경로가 생긴다. 새 5시드 개발을 위한 후보이며 성능 우위는 아직 입증되지 않았다.

**v4 짝 개발 완료(2026-10-26):** 네 방법 모두 5개 시드에서 학습 기준을 통과했지만, TOSM OOD 착륙률 95.53%는 PPO 95.40%, Residual-MLP 95.73%, Shuffled 96.73%에 대한 일반화 우위를 입증하지 못했다. v4의 미사용 개발·확인은 열지 않았으며, 완료된 v4 재현 경로와 결과를 보관한다.

- [현재 v5: 간선 변경·수식·고정 개발 기준](RELATIONAL_RESIDUAL_V5_KO.md)
- [v4 변경·비교 조건·완료 결과·실행 방법](RELATIONAL_RESIDUAL_V4_KO.md)
- [v3 그래프·수식과 전체 개발 실패 결과](RELATIONAL_RESIDUAL_V3_KO.md)
- [v2 전체 개발 실패 결과와 후속 근거](RELATIONAL_RESIDUAL_V2_KO.md)
- [v1 전체 개발 실패 결과와 변경 근거](RELATIONAL_RESIDUAL_V1_KO.md)

아래 문서는 이전 minimal v3 구조의 근거와 재현 기록이다.

- [보관 minimal v3의 4노드 구성과 인코더 수식](TOSM4_ONTOLOGY_KO.md)
- [v3.1 모델 개선: 품질 문맥을 사용하는 동적 attention](MINIMAL_V31_DESIGN_KO.md)
- [귀납적 편향이 가중치 공유·PPO 업데이트에 반영되는 위치](INDUCTIVE_BIAS_KO.md)
- [일반화 중심 평가 설계](EXPERIMENT_DESIGN_KO.md)
- [시스템 전체를 한 장으로 보기](MINIMAL_SYSTEM_KO.md)
- [이전 7노드 문서 보관본](archive/TOSM7_ONTOLOGY_V2_KO.md)

이 파일명은 기존 링크를 보존하기 위해 남겼다. `tosm7_v2`–`tosm7_v5`는 보관 모델 재현용이며 현재 `run.m`이 사용하는 입력이 아니다.
