# PPT 수정 에이전트용 최종 프롬프트

아래 PowerPoint를 직접 수정하라.

- 원본: `C:\Users\user\SynologyDrive\junsuk\세미나\발표\20261012\261012_김준석_드론 자율 착륙을 위한 온톨로지 관계 추론 기반 강화학습 기법.pptx`
- 출력: 원본을 덮어쓰지 말고 같은 폴더에 `261012_김준석_드론 자율 착륙을 위한 온톨로지 관계 추론 기반 강화학습 기법_파라미터정합_최종.pptx`로 저장
- 수치 원본: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\results\planar_visibility_full_summary.csv`
- 학습 원본: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\results\planar_visibility_full.mat`
- PPT용 최종 결과 그림: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\docs\assets\paper\parameter_matched_ontology_evidence.png`
- 벡터 그림: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\docs\assets\paper\parameter_matched_ontology_evidence.pdf`
- 일관성 재평가 그림: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\docs\assets\paper\parameter_matched_consistency.png`
- 위험 실패 부록 그림: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\docs\assets\paper\parameter_matched_unsafe_failures.png`
- 단독 학습곡선: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\docs\assets\paper\parameter_matched_learning_curve.png`

## 수정 목표

일반 PPO 6,101개와 기존 온톨로지–R-GAT PPO 16,565개의 파라미터 차이 때문에 제안 모델의 이점이 단순 모델 용량 증가에서 비롯됐을 가능성을 제거한다. 최종 제안 모델은 온톨로지의 7개 노드·4개 관계·16개 간선과 노드별 정보보존 grouped readout을 유지하되, R-GAT 노드 은닉 차원을 16에서 4로, 그래프 임베딩을 32에서 5로 축소한 파라미터 정합형 구조이다. 공통 관측·보상·환경·행동·종료·PPO 예산은 변경하지 않았다.

발표의 핵심 주장을 다음과 같이 재구성한다.

> 거의 같은 모델 용량에서 온톨로지 관계 구조를 명시적으로 사용한 정책이 held-out 착륙 성공률과 평균 누적 보상을 유지·개선함. 따라서 성능 차이를 단순히 더 큰 네트워크의 효과로 설명하기 어려움. 단, 단일 학습 seed이며 위험 실패 2%가 관측되었으므로 안전성 우월성은 주장하지 않음.

다만 파라미터 정합 압축 후 세 정책 일관성 지표가 모두 일반 PPO보다 악화되었으므로, `온톨로지가 더 일관적이다`라는 주장은 철회한다. 최종 발표의 정직한 결론은 `임무 성공률 개선과 일관성·평활성 악화가 동시에 나타난 구조적 trade-off`이다.

## 확정 구조와 파라미터

- 공통 관측: 12차원
- 온톨로지: 7개 노드, 4개 관계(`informs`, `conditions`, `couples`, `self`), 16개 간선
- 노드 특징: 6차원
- R-GAT: 관계형 메시지 전달 1층, 관계 임베딩 4차원, 노드 은닉 4차원
- 노드별 grouped readout: `H ∈ R^(4×7)`을 펼친 `z ∈ R^28`
- 그래프 요약: `28 → 5`, `g ∈ R^5`
- Actor MLP: `5–48–48–2`
- Critic MLP: `5–48–48–1`
- Actor/Critic R-GAT 인코더: 서로 독립, 인코더당 333개
- Actor 전체: 3,073개
- Critic 전체: 3,022개
- 제안 모델 전체: 6,095개
- 일반 PPO 전체: 6,101개
- 차이: 제안 모델이 6개 적음, 상대 차이 약 `−0.10%`
- 기존 16,565개 제안 모델 대비 감소: 약 `−63.2%`

파라미터 산식은 다음을 사용한다.

`P_enc = (4×4×6) + 4(2×4+4) + (4×4) + (4×6) + 4 + (5×28) + 5 = 333`

`P_proposed = 3,073 + 3,022 = 6,095`

`P_PPO = 3,076 + 3,025 = 6,101`

R-GAT 수식의 차원도 모두 새 구조에 맞춘다.

`e_ji^(r) = LeakyReLU(a_r^T [W_r x_i || W_r x_j || E_r])`

`α_ji^(r) = softmax_(j,r)(e_ji^(r))`

`h_i = tanh(Σ_(j,r) α_ji^(r) W_r x_j + W_0 x_i + b_0)`, `h_i ∈ R^4`

`z = vec([h_1,…,h_7]) ∈ R^28`

`g = tanh(W_g z+b_g) ∈ R^5`, `W_g ∈ R^(5×28)`

## 확정 실험 결과

동일한 750 PPO 반복 × 반복당 6 에피소드 = 4,500 에피소드, 학습 seed 1개, 독립 held-out test 100에피소드 결과만 사용한다.

| 지표 | 일반 PPO | 파라미터 정합 온톨로지–R-GAT PPO | 차이 |
|---|---:|---:|---:|
| 파라미터 | 6,101 | 6,095 | −6 (−0.10%) |
| 착륙 성공률 | 95% | 98% | +3%p |
| 위험 실패율 | 0% | 2% | +2%p |
| 시간 초과율 | 5% | 0% | −5%p |
| 평균 누적 보상 | 31.8186 | 32.0514 | +0.2328 |
| Actor 추론시간 | 0.0369 ms | 0.1840 ms | 약 4.99배 |
| 공칭 `C_valid` | 77.329% | 64.182% | −13.147%p |
| 공칭 `D_obs` P95 | 0.074238 | 0.10162 | +36.9% |
| pooled `J_policy` | 4.0996 | 7.5562 | +84.3% |

추론시간은 제안 모델이 더 크다고 해석하지 말고, 작은 행렬에 대한 그래프 구성·관계별 연산·MATLAB 함수 호출 오버헤드로 설명한다. 0.1840 ms는 100 ms 정책 주기의 약 0.184%이므로 실시간 예산 안이지만, 일반 PPO보다 빠르다는 주장은 금지한다.

학습 중 validation 모델 선택은 test와 분리되었다. 선택 체크포인트는 650회 반복에서 validation 착륙 100%, 위험 실패 0%, event-aware score 1033.46을 기록했다. 최종 주장은 반드시 held-out test 결과를 기준으로 한다.

## 슬라이드별 필수 수정

1. 슬라이드 1: 발표일을 `2026. 10. 12.`로 정정한다.
2. 슬라이드 3~4: 연구 흐름과 R-GAT 개념은 유지하되, 핵심 기여에 `파라미터 정합 비교로 모델 용량 혼입 제거`를 추가한다.
3. 슬라이드 5: Actor/Critic 블록을 `R-GAT 1층·노드 4차원`, `그래프 요약 28→5`, Actor `5–48–48–2`, Critic `5–48–48–1`로 교체한다.
4. 슬라이드 6: 7노드·4관계·16간선 온톨로지 설계는 유지한다. 노드나 관계를 삭제·추가하지 않는다.
5. 슬라이드 7: `112→32`, 노드 임베딩 16차원, attention 벡터 36차원 표기를 모두 제거한다. `28→5`, 노드 임베딩 4차원, attention 벡터 `2·4+4=12`차원으로 수정하고 위 수식과 파라미터 산식을 배치한다.
6. 슬라이드 8~9: 공통 보상·환경 내용은 변경하지 않는다.
7. 슬라이드 10: 비교 문구를 `일반 PPO 6,101개 / 제안 모델 6,095개`로 바꾸고, `파라미터 차이 0.10% 미만` 배지를 추가한다. 학습 4,500에피소드와 held-out 100회 조건을 명확히 표시한다.
8. 슬라이드 11: 기존 `두 정책 모두 95%` 문구를 삭제하고, 성공 95→98%, timeout 5→0%, 평균 보상 31.82→32.05를 시각화한다. 위험 실패 0→2%도 같은 크기와 가시성으로 표시해 숨기지 않는다.
9. 슬라이드 12: 제목을 `파라미터 정합 후 드러난 임무 성능–일관성 trade-off`로 변경한다. `parameter_matched_consistency.png`를 사용해 공칭 `C_valid` −13.147%p, `D_obs P95` +36.9%, pooled `J_policy` +84.3%를 표시한다. 기존 +20.2%p·−6.68%·−8.85% 주장을 완전히 삭제한다.
10. 슬라이드 13: 향후 연구에 `다중 학습 seed 신뢰구간`, `위험 실패 2건의 패드 이탈 원인 개선`, `6,095개 예산 안에서 관계 표현의 잡음 강건성·평활성 회복`을 추가한다.
11. 슬라이드 16과 19: 상세 구조의 모든 16차원·32차원·112차원·4,272개/인코더·총 16,565개 표기를 각각 4차원·5차원·28차원·333개/인코더·총 6,095개로 수정한다.
12. 슬라이드 20: 학습 설정은 유지하고 `파라미터 정합 구조에서도 동일 PPO 예산 적용`을 추가한다.
13. 슬라이드 21: 결론을 `거의 동일한 파라미터에서 held-out 성공률 +3%p, 평균 보상 +0.23이나 일관성 3종 악화`로 교체하고, `단일 seed·위험 실패 2%·구조적 trade-off`를 함께 명시한다.
14. 부록에 `parameter_matched_unsafe_failures.png` 한 장을 추가한다. 두 실패는 seed 3026·3076의 `MISSED_PAD_CONTACT`이며 주 위반은 종단 위치 오차 69.10배·3.11배임을 표시한다.
15. 기존 패널에서 잘라 쓴 작은 학습곡선을 `parameter_matched_learning_curve.png`로 교체한다. 별도 추론시간 주석을 추가하지 않는다.

## 일관성 재평가 결과 처리

기존 슬라이드의 `C_valid +20.2%p`, `D_obs P95 감소`, `jerk 8.9% 감소`는 16,565개 모델의 체크포인트에서 생성된 값이므로 6,095개 최종 모델의 결과처럼 재사용하지 않는다. 다음 파일들도 현재는 구형 모델 결과이므로 인용하지 않는다.

- `results/consistency/priority_review_test.mat`
- `results/consistency/ontology_vs_ppo_summary.csv`
- `docs/assets/paper/ontology_vs_ppo_evidence.png`

파라미터 정합 모델의 재평가 결과는 `results/consistency/parameter_matched_consistency.mat`과 `docs/assets/paper/parameter_matched_consistency.csv`에 확정 저장됨. 일반 PPO 대비 결과는 다음과 같음.

- 공칭 `C_valid`: 77.329% → 64.182%, −13.147%p
- 공칭 `D_obs` P95: 0.074238 → 0.10162, +36.9%
- pooled `J_policy`: 4.0996 → 7.5562, +84.3%
- 판정: 관계형 구조의 일관성 이점 확인 실패, 압축 과정에서 기존 이점 소실

슬라이드에서 `재평가 예정` 문구를 모두 제거하고 위 실측 결과로 교체한다. 임무 착륙률 98%와 반드시 병기해 성능 trade-off로 해석한다.

## 편집·시각화 원칙

- 기존 네이비·보라 계열 디자인, 글꼴, 페이지 번호, 여백, 도형 스타일을 최대한 유지한다.
- 본문은 개조식·두괄식·명사형 종결어미로 정리한다.
- 표보다 핵심 비교가 잘 보이는 두 막대 비교, before/after 구조도, 파라미터 산식 callout을 우선 사용한다.
- 결과 막대에는 표본수 `held-out n=100`, 학습 seed `n=1`을 직접 표기한다.
- `온톨로지가 안전성을 개선했다`, `통계적으로 유의하다`, `일관성이 개선됐다`는 새 검증 없이 주장하지 않는다.
- 일반 PPO와 제안 모델에 공통 관측·보상·환경·행동·종료·PPO 예산이 같다는 점을 반복적으로 명확히 한다.
- 텍스트·수식·도형의 겹침, 잘림, 슬라이드 밖 배치를 전수 검사한다.
- 편집 후 전체 슬라이드를 렌더링해 육안 검수하고, 수정본 PPTX와 렌더링 PDF를 함께 저장한다.

최종 응답에는 수정한 슬라이드 번호, 변경한 핵심 수치, 삭제한 구형 주장, 출력 PPTX/PDF 경로를 요약하라.
