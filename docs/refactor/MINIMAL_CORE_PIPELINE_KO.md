# 최소 핵심 파이프라인

## 공통 경로

`marker/navigation → 12-D observation → policy → [a_x,a_z] → dynamics → mechanical contact result`

## 일반 PPO

`o_t(12) → MLP 48–48 → Actor/Critic`

## 제안 모델

`o_t(12) → 7-node ontology → typed R-GAT(16) → factorized grouped readout(16) → Actor 38–37 / Critic 35–34`

## 제외 요소

- raw observation과 graph의 동시 입력
- 안전 감독기·착륙 승인·SAFE_ABORT guard
- inference gate·residual correction
- behavior cloning·graph pretraining·relation-only repair
- hidden truth·future state·reward/outcome feature

## 공정성

환경·센서·관측 원자료·reward_v5·행동·종료·4,500 episode 예산·seed 흐름 동일. 전체 trainable parameter 6,101개 동일.

상세 명세: `docs/CURRENT_SYSTEM_KO.md`.
