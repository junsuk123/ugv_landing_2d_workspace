# v3.19 최소 핵심 파이프라인

## 공통 경로

`marker/navigation → 12-D observation → policy → [a_x,a_z] → dynamics → mechanical touchdown`

## 일반 PPO

`o_t(12) → MLP 48–48 → Actor/Critic`

## 제안 모델

`o_t(12) → 7-node ontology → smooth energy × age confidence → typed R-GAT(16) → factorized grouped readout(16) → Actor 38–37 / Critic 35–34`

## 학습 전용 항

`state-proximity-weighted temporal action consistency`, weight 0.03. 추론 시 이전 상태나 이전 행동을 입력하지 않는다.

## 제외 요소

- raw observation과 graph의 동시 입력
- 안전 감독기·착륙 승인·SAFE_ABORT guard
- inference gate·action residual·command rewriting
- behavior cloning·graph pretraining·relation-only repair
- hidden truth·future state·reward/outcome feature

환경, 센서, 관측 원자료, `reward_v5`, 행동, 종료, 4,500-episode 예산, episode stream은 공통이고 전체 trainable parameter는 각각 6,101개다.
