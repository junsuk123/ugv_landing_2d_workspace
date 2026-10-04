# 온톨로지·R-GAT 최종 시각화 안내

## 결론

- 정적 구조 확인: `docs/assets/ontology_graph.svg`
- 실시간 정책 신호 확인: `run_paper`의 `paper_ontology`
- 전체 궤적 비교: `paper_trajectories`
- 물리 가능성·하강 금지 원인: `paper_feasibility`
- checkpoint 관계 경로 활성 여부: `paper_architecture_audit.csv`
- Monte Carlo 평균·분산: `planar_visibility_monte_carlo.png`

## 실행

```matlab
[study,figures] = run_paper;
```

창 없이 파일 생성:

```matlab
run_paper(struct('figureVisible',false));
```

## 생성 figure

| figure | 내용 |
|---|---|
| `paper_trajectories` | 패드 상대 $x$–고도 궤적, 시간–추종오차 |
| `paper_stability` | 안정성 지수와 5개 구성 metric |
| `paper_feasibility` | speed·acceleration margin, inhibit 비율·원인 |
| `paper_ontology` | eligibility·inhibit·visibility·gate·relation residual |
| `planar_visibility_monte_carlo` | test 100 seed 평균·1시그마 궤적·결과율·attention |

## 궤적 figure

![궤적 비교](assets/paper/paper_trajectories.png)

표현:

- 시작점: 빈 원
- 종료점: 채운 역삼각형
- 회색 점선: level-camera FOV 참고 경계
- 왼쪽 열: pad-relative $x$–height
- 오른쪽 열: signed horizontal tracking error
- 배경: CV1·CA·CV3 구간
- 모든 scenario의 왼쪽 축 범위 통일

## 안정성 figure

![안정성 지표](assets/paper/paper_stability.png)

포함 metric:

- stability index
- tracking RMSE
- relative-speed RMSE
- measured FOV loss
- supervisor intervention
- control jerk RMS

방향:

- stability index: 큰 값 우수
- 나머지 metric: 작은 값 우수

## 착륙 가능성 figure

![착륙 가능성](assets/paper/paper_feasibility.png)

구분:

- speed authority margin
- acceleration authority margin
- operational `LandingInhibit` 비율
- R-GAT trajectory의 inhibit 원인 시간 분해

주의:

- 양의 authority margin: 해당 단일 물리 제약 통과
- `LandingInhibit`: 영구적 착륙 불가능 판정 제외
- 물리적 가능성과 운영 중 하강 금지의 별도 해석

## 온톨로지 정책 추적 figure

![온톨로지 추적](assets/paper/paper_ontology.png)

왼쪽 축:

- `DescentEligibility`
- `LandingInhibit`
- pad detected
- vertical gate active

오른쪽 축:

- R-GAT vertical action residual

상단 감사 문구:

- `ACTIVE`: policy·value graph readout의 비영 norm 확인
- `INACTIVE`: raw semantic bypass만 사용한 선택 checkpoint

최신 결과:

- Policy $\lVert W_g\rVert_F=0.0001665$
- Value $\lVert W_g\rVert_F=0.0006056$
- relation path `ACTIVE`
- vertical residual 축의 $10^{-5}$ 배율 표시
- 성능 보존 calibration scale 0.001

## 정적 구조 그림

![온톨로지 그래프](assets/ontology_graph.svg)

포함 내용:

- 9개 의미 노드
- 주요 typed relation
- `LandingInhibit → DescentEligibility` 억제 관계
- self-edge 생략 표기

전체 간선 표:

- [온톨로지 상태 설계](ONTOLOGY_GRAPH_STATE_KO.md)

## 숫자 원본

| 파일 | 용도 |
|---|---|
| `paper_scenario_feasibility.csv` | scenario별 physical margin |
| `paper_stability_metrics.csv` | 모델·scenario별 metric |
| `paper_runtime_profile.csv` | parameter·runtime |
| `paper_architecture_audit.csv` | R-GAT 관계 경로 활성 여부 |
| `paper_validation.mat` | 전체 재현 데이터 |

GitHub 문서 포함 사본:

- `assets/paper/data/planar_visibility_full_summary.csv`
- `assets/paper/data/latest_document_summary.csv`
- `assets/paper/data/paper_runtime_profile.csv`
- `assets/paper/data/paper_stability_metrics.csv`
- `assets/paper/data/paper_scenario_feasibility.csv`
- `assets/paper/data/paper_architecture_audit.csv`

## Monte Carlo figure

![Monte Carlo 평균·1시그마 궤적](assets/paper/planar_visibility_monte_carlo.png)

## 해석 제한

- 단일 trajectory의 우월성 일반화 제외
- 안정성 지수와 성공률의 혼합 제외
- 작은 relation residual의 보편적 우월성 주장 제외
- 논문 그림의 사후 truth metric을 정책 입력으로 해석하는 오류 제외
