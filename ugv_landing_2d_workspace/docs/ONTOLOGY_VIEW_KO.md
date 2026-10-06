# 온톨로지·R-GAT 최종 시각화 안내

## 결론

- 전체 구조·런타임 감사: `ontologyRgatExplorer`
- 정적 구조 확인: `docs/assets/ontology_graph.svg`
- 실시간 정책 신호 확인: `run`의 `paper_ontology`
- 전체 궤적 비교: `paper_trajectories`
- 물리 가능성·하강 금지 원인: `paper_feasibility`
- checkpoint 관계 경로 활성 여부: `paper_architecture_audit.csv`
- Monte Carlo 평균·분산: `planar_visibility_monte_carlo.png`

## 시각화 방법론 조사와 최종 선택

조사 대상:

| 방법 | 강점 | 현재 구조의 한계 | 적용 |
|---|---|---|---|
| Node-link·layered graph | 단일 경로·방향 추적 | 26개 typed edge와 self-edge 동시 표시 시 교차선 증가 | 전체도 미적용 |
| Indented tree | 계층 탐색·초심자 가독성 | 다중 부모·비계층 관계의 중복 표현 | 미적용 |
| Semantic substrate | 의미 속성별 비중첩 영역·그룹 비교 | 관계 상세의 별도 표현 필요 | 노드 그룹 카드 적용 |
| Typed adjacency matrix | 전체 간선·방향·관계형의 정확한 비교 | 긴 경로의 직관성 감소 | 전체 관계 구조 적용 |
| Focus+context | 선택 관계의 상세 확인과 전체 문맥 보존 | 상호작용 상태 관리 필요 | 런타임 탭·전체 표 결합 |

선정 근거:

- 온톨로지 시각화의 단일 보편 표현 부재와 작업별 방법 선택 권고
- 의미 속성 기반 비중첩 영역을 통한 노드 그룹 구분
- 간선 밀도 증가 시 node-link보다 matrix의 구조 판독 우위
- MATLAB `imagesc`, stacked `bar`, `uitable`, `uitabgroup` 기반 추가 도구상자 없는 구현 가능성
- MATLAB `digraph` layered layout의 경로 중심 보조 사용 가능성 유지

참고 문헌:

- [Katifori et al., Ontology Visualization Methods—A Survey](https://doi.org/10.1145/1287620.1287621)
- [Shneiderman and Aris, Network Visualization by Semantic Substrates](https://www.cs.umd.edu/~ben/papers/Shneiderman2006Network.pdf)
- [Ghoniem et al., Node-Link and Matrix-Based Representations](https://doi.org/10.1057/palgrave.ivs.9500092)
- [MathWorks Graph Plotting and Customization](https://www.mathworks.com/help/matlab/math/graph-plotting-and-customization.html)
- [MathWorks Layered Graph Layout](https://www.mathworks.com/help/matlab/ref/matlab.graphics.chart.primitive.graphplot.layout.html)

최종 coordinated multiple views (`uitabgroup` 4개 탭):

| 탭 | 구성 |
|---|---|
| `1  Ontology schema` | 4개 readout 그룹 카드(노드 번호·클래스·risk/goal/state·self), typed relation matrix(행 source·열 destination·대각 self), 9행 노드 표(class·group·role·causal provenance), 26행 간선 표(17 semantic + 9 self) |
| `2  Runtime R-GAT` | Actor·Critic 목적 노드별 관계형 inbound attention 누적 막대 + 정규화 $\lVert h_j\rVert$ 선, Actor·Critic source→destination attention matrix |
| `3  Features and readout` | $X_t$ 12×9 = 108 값 heatmap, 4×9 grouped readout 행렬, 관계별 Actor/Critic $\lVert W_r\rVert_F$·평균 $\alpha$ 막대 |
| `4  Full audit` | 추론 경로 도식(packet→$X_t$→R-GAT→hidden→grouped readout→raw bypass+residual→Actor/Critic)·Actor/Critic context norm, 26개 간선별 score·$\alpha$·weighted message 표, 학습 텐서 목록($W_r$, $a_r$, $E_r$, $W_0$, $b_0$, $W_g$, $b_g$, relation head) |

- 입력 상태: 저장된 paper validation의 R-GAT trajectory 중 대표 1 step
- score 열: $\mathrm{LeakyReLU}_{0.2}$ 적용 logit
- message 열: $\alpha_{ij}^{(r)}\lVert W_r x_i\rVert_2$

## 실행

필요 파일:

- `results/ppo_context_rgat_planar_visibility_v2.mat`: 최종 R-GAT checkpoint
- `results/paper/paper_validation.mat`: 대표 상태용 paper validation

전체 온톨로지·R-GAT explorer:

```matlab
addpath(fullfile(pwd,'src','orchestration'), ...
    fullfile(pwd,'src','simulations'),fullfile(pwd,'src','algorithms'))
view = landing2d.viz.ontologyRgatExplorer();
```

- 출력 인수 생략 시 base workspace 변수 `ontologyRgatView` 저장
- 기본값: `scenarioId='S3'`, `snapshotMode='max_recovery'`, `figureVisible=true`

대표 시나리오 변경:

```matlab
view = landing2d.viz.ontologyRgatExplorer(struct( ...
    'scenarioId','S2','snapshotMode','max_recovery'));
```

| 옵션 | 값 |
|---|---|
| `scenarioId` | `S1`, `S2`, `S3` |
| `snapshotMode` | `max_recovery`, `middle`, `final` |
| `checkpointFile` | checkpoint 경로 |
| `studyFile` | paper validation 경로 |
| `figureVisible` | `true`, `false` |

- `max_recovery`: `ViewRecovery` urgency·uncertainty, `LandingInhibit` primary, `RelativeTracking` uncertainty 가중합 최대 step

논문 결과 전체 생성:

```matlab
output = run(struct('retrain',false));
```

창 없이 파일 생성:

```matlab
output = run(struct('retrain',false,'figureVisible',false));
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

- `DescentEligibility` primary
- 공개 `landingInhibited` 플래그
- pad detected
- vertical gate active

오른쪽 축:

- R-GAT vertical action residual

상단 감사 문구:

- `ACTIVE`: Policy/Value $\lVert W_g\rVert_F$와 Policy/Value relation head norm 모두 $>10^{-10}$
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

- 9개 의미 노드, readout 그룹별 색
- 17개 의미 간선 전체
- 관계형별 선 스타일: `informs`·`affects_visibility`·`supports`·`inhibits`
- `LandingInhibit → DescentEligibility` 억제 관계
- self-edge 9개 생략 표기

용도:

- 문서용 단순 개요
- 전체 구조 감사 용도 제외
- 전체 구조 감사는 explorer의 그룹 카드·typed relation matrix 사용

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
