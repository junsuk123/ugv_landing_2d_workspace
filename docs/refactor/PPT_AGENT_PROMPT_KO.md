# PPT 수정 에이전트용 최종 프롬프트

아래 PowerPoint를 직접 수정하라.

- 원본: `C:\Users\user\SynologyDrive\junsuk\세미나\발표\20261012\261012_김준석_드론 자율 착륙을 위한 온톨로지 관계 추론 기반 강화학습 기법.pptx`
- 출력: 원본을 덮어쓰지 말고 같은 폴더에 `261012_김준석_드론 자율 착륙을 위한 온톨로지 관계 추론 기반 강화학습 기법_파라미터정합_최종.pptx`로 저장
- 수치 원본: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\results\planar_visibility_full_summary.csv`
- 학습 원본: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\results\planar_visibility_full.mat`
- 종합 결과 그림: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\docs\assets\paper\latest_parameter_matched\parameter_matched_ontology_evidence.png`
- 일관성 그림: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\docs\assets\paper\latest_parameter_matched\parameter_matched_consistency.png`
- 위험 실패 그림: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\docs\assets\paper\latest_parameter_matched\parameter_matched_unsafe_failures.png`
- 단독 학습곡선: `C:\Users\user\SynologyDrive\junsuk\학술대회\CICS2026\codes\ugv_landing_2d_workspace_refactor\docs\assets\paper\latest_parameter_matched\parameter_matched_learning_curve.png`

## 최종 발표 주장

> 일반 PPO와 정확히 동일한 6,101개 파라미터에서, 정보보존형 저랭크 ontology–R-GAT가 held-out 착륙률·평균 누적 보상·물리적 유효행동 일관성 `C_valid`를 개선함. 종전 6,095개 과압축 모델보다 잡음 민감도와 명령 jerk도 감소했으나, `D_obs`와 `J_policy`는 일반 PPO보다 여전히 높음. 단일 학습 seed와 위험 실패 1% 때문에 안전성·통계적 우월성 주장은 제외함.

공통 관측·보상·환경·행동·종료·PPO 예산은 변경하지 않았음을 명시한다. 게이트, 안전 가드, raw observation bypass, additive residual은 사용하지 않는다.

## 확정 구조와 파라미터

- 공통 관측: 12차원
- 온톨로지: 7개 노드, 4개 관계(`informs`, `conditions`, `couples`, `self`), 16개 간선
- 노드 특징: 공통 관측에서만 계산한 6차원
- R-GAT: 관계 메시지 전달 1층, 관계 임베딩 4차원, 노드 은닉 16차원
- 노드별 grouped state: `H ∈ R^(16×7)`
- 저랭크 grouped readout: 채널 투영 `W_c ∈ R^(16×16)`과 노드 혼합 `W_n ∈ R^(16×7)`
- 그래프 임베딩: `g ∈ R^16`
- Actor MLP: `16–38–37–2`
- Critic MLP: `16–35–34–1`
- Actor/Critic 인코더: 서로 독립, 인코더당 1,040개
- Actor 전체: 3,207개
- Critic 전체: 2,894개
- 제안 모델 전체: 6,101개
- 일반 PPO 전체: 6,101개
- 파라미터 차이: 0개

파라미터 산식:

`P_relation = (4×16×6) + 4(2×16+4) + (4×4) + (16×6) + 16 = 656`

`P_readout = (16×16) + (16×7) + 16 = 384`

`P_encoder = 656 + 384 = 1,040`

`P_actor = 1,040 + 2,167 = 3,207`

`P_critic = 1,040 + 1,854 = 2,894`

`P_proposed = 3,207 + 2,894 = 6,101 = P_PPO`

수식:

`e_ji^(r) = LeakyReLU(a_r^T [W_r x_i || W_r x_j || E_r])`

`α_ji^(r) = softmax_(j,r)(e_ji^(r))`

`h_i = tanh(Σ_(j,r) α_ji^(r) W_r x_j + W_0 x_i + b_0)`, `h_i ∈ R^16`

`q_kn = w_(c,k)^T h_n`

`g_k = tanh(Σ_n W_n[k,n] q_kn + b_k)`, `g ∈ R^16`

초기 readout의 12개 채널은 횡오차·고도·폐합속도·UGV 속도·수직속도·자세·영상/항법 유효도와 경과시간에 일대일 대응한다. 이는 학습 가능한 ontology 좌표 초기화이며 raw 관측 우회가 아니다.

## 확정 실험 결과

동일한 750 PPO 반복 × 반복당 6에피소드 = 4,500에피소드, 학습 seed 1개, held-out test 100에피소드 결과만 사용한다.

| 지표 | 일반 PPO | 최종 온톨로지–R-GAT PPO | 차이 |
|---|---:|---:|---:|
| 파라미터 | 6,101 | 6,101 | 0 |
| 착륙 성공률 | 95% | 96% | +1%p |
| 위험 실패율 | 0% | 1% | +1%p |
| 시간 초과율 | 5% | 3% | −2%p |
| 평균 누적 보상 | 31.8186 | 32.372 | +0.553 |
| Actor 추론시간 | 0.0353 ms | 0.1693 ms | 약 4.8배 |
| 공칭 `C_valid` | 77.329% | 80.799% | +3.470%p |
| 공칭 `D_obs` P95 | 0.074238 | 0.095983 | +29.3% |
| pooled `J_policy` | 4.0996 | 6.6914 | +63.2% |

종전 6,095개 모델 대비 최종 모델의 변화도 별도 callout으로 제시한다.

- `C_valid`: 64.182% → 80.799%, +16.617%p
- `D_obs` P95: 0.10162 → 0.095983, −5.5%
- `J_policy`: 7.5562 → 6.6914, −11.4%
- 파라미터: 6,095 → 6,101, PPO와 정확히 동일

추론시간 0.1693 ms는 100 ms 정책 주기의 약 0.169%이므로 실시간 예산 안이지만 일반 PPO보다 빠르다는 주장은 금지한다. 선택 체크포인트는 validation 525회에서 착륙 98%, unsafe 0%, 평균 return 33.27을 기록했다. test seed는 선택에 사용하지 않았다.

## 슬라이드별 필수 수정

1. 슬라이드 1: 발표일 `2026. 10. 12.` 표기.
2. 슬라이드 3~4: 핵심 기여에 `동일 6,101개 예산에서 관계 표현 용량 재배분` 추가.
3. 슬라이드 5: `R-GAT 1층·노드 16차원`, `factorized grouped readout 16차원`, Actor `16–38–37–2`, Critic `16–35–34–1`로 교체.
4. 슬라이드 6: 7노드·4관계·16간선 유지. 노드나 관계 추가·삭제 금지.
5. 슬라이드 7: dense `112→32` 또는 과압축 `28→5` 도식을 삭제하고 `H(16×7) → W_c(16×16), W_n(16×7) → g(16)` 저랭크 수식과 1,040개/인코더 산식 배치.
6. 슬라이드 8~9: 공통 보상·환경 내용 유지.
7. 슬라이드 10: `일반 PPO 6,101개 = 제안 모델 6,101개` 및 `파라미터 차이 0` 배지 표시.
8. 슬라이드 11: 착륙 95→96%, timeout 5→3%, 평균 보상 31.82→32.37, 위험 실패 0→1%를 동일 가시성으로 표시.
9. 슬라이드 12: 제목을 `동일 파라미터에서 회복된 유효행동 일관성`으로 변경. `parameter_matched_consistency.png`를 사용해 `C_valid +3.470%p`, `D_obs +29.3%`, `J_policy +63.2%`를 함께 제시. 한 지표만 선택해 우월성을 주장하지 말 것.
10. 슬라이드 13: 향후 연구에 다중 학습 seed 신뢰구간, 위험 실패 1건 원인 개선, `D_obs`·`J_policy` 격차 해소 추가.
11. 슬라이드 16·19: 노드 16차원, 그래프 16차원, 1,040개/인코더, 총 6,101개로 전면 수정.
12. 슬라이드 20: 동일 4,500-episode PPO 예산과 validation/test 분리 명시.
13. 슬라이드 21: `동일 파라미터에서 성공률 +1%p, return +0.553, C_valid +3.470%p`를 결론으로 사용하고 `단일 seed·unsafe 1%·D_obs/J_policy 열세`를 병기.
14. 부록: `parameter_matched_unsafe_failures.png` 추가. 유일한 위험 실패는 seed 3076의 `UNSAFE_CONTACT`이며 종단 pitch-rate가 허용 한계의 1.164배였음을 명시.
15. 작은 학습곡선을 `parameter_matched_learning_curve.png`로 교체하고 추론시간 중복 주석은 제거.

## 삭제할 구형 주장

- 16,565개 모델의 `C_valid +20.2%p`, `D_obs P95 −6.68%`, `J_policy −8.85%`
- 6,095개 과압축 모델의 `C_valid −13.147%p`, `D_obs +36.9%`, `J_policy +84.3%`
- `성공률 98%`, `unsafe 2%`, `timeout 0%`, `28→5`, `총 6,095개`
- `온톨로지가 안전성을 개선`, `통계적으로 유의`, `모든 일관성 지표 우월` 표현

## 편집·검수 원칙

- 기존 네이비·보라 계열 디자인, 글꼴, 페이지 번호, 여백, 도형 스타일 유지.
- 개조식·두괄식·명사형 종결어미 사용.
- 결과에 `held-out n=100`, `training seed n=1` 직접 표기.
- 공통 관측·보상·환경·행동·종료·PPO 예산 동일성 반복 명시.
- 수치 추정 금지. 위 파일의 최신 값만 사용.
- 전체 슬라이드를 렌더링하여 겹침·잘림·슬라이드 밖 배치를 육안 검수.
- 수정본 PPTX와 렌더링 PDF 동시 저장.

최종 응답에는 수정 슬라이드 번호, 핵심 수치, 삭제한 구형 주장, 출력 PPTX/PDF 경로를 요약하라.
