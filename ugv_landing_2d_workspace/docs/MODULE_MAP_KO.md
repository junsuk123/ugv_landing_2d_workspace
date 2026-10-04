# 최종 코드 구조

## 결론

- 루트 진입점 2개
- `src` 상위 계층 3개
- MATLAB 소스 128개
- 최종 계약 self-test 8개
- 과거 실험·가중치 설계·중복 GUI·분산 테스트 제거

## 루트 진입점

| 파일 | 역할 |
|---|---|
| `run.m` | scratch 학습→validation→held-out test→논문 시각화 |
| `run_scenario.m` | S1·S2·S3 중 단일 시나리오 최종 정책 비교 |

## `src/orchestration`

| 패키지 | 역할 |
|---|---|
| `+orchestration` | 전체 파이프라인·검증·단일 시나리오·self-test |
| `+config` | `planar_visibility_v2` 설정과 계약 검증 |
| `+paper` | 대표 시나리오·안정성·가능성·논문 그림 |
| `+viz` | 학습 대시보드·Monte Carlo 요약·R-GAT field |
| `+io` | 최종 탭 figure 저장 |
| `+util` | 수치 최적화 공통 유틸리티 |

핵심 파일:

- `src/orchestration/+landing2d/+orchestration/runPipeline.m`
- `src/orchestration/+landing2d/+orchestration/trainEvaluate.m`
- `src/orchestration/+landing2d/+orchestration/validateStudy.m`
- `src/orchestration/+landing2d/+orchestration/runStudy.m`
- `src/orchestration/+landing2d/+orchestration/runScenario.m`
- `src/orchestration/+landing2d/+orchestration/selfTest.m`

## `src/simulations`

| 패키지 | 역할 |
|---|---|
| `+environment` | reset·step·종료·접촉·안전 문맥 |
| `+dynamics` | 2D 기체·추력·피치 동역학 |
| `+sensing` | 카메라·26필드 packet·causal 추정기 |
| `+scenario` | CV–CA–CV 이동 패드 |
| `+control` | 공통 안전 감독기와 제어 변환 |
| `+simulation` | 최종 rollout 초기화 |
| `+metrics` | 회복·거리 metric |

## `src/algorithms`

| 패키지 | 역할 |
|---|---|
| `+rl` | PPO·Actor/Critic·reward·checkpoint·평가 |
| `+graphstate` | 9노드 상황 그래프·encoder·사전학습 |
| `+rgat` | typed relation attention 순전파·역전파 |
| `+ontology` | 최종 노드 스키마·노드 값 |

## 최소 시각화

| 출력 | 내용 |
|---|---|
| 학습 대시보드 | return·성공률·안전률·R-GAT 학습 상태 |
| Monte Carlo summary | 평균·1시그마 궤적·결과율·학습 곡선·추론시간·attention |
| paper trajectories | 고정 시나리오 착륙 궤적 |
| paper stability | 안정성 지표 |
| paper feasibility | 물리 가능성과 inhibit 원인 |
| paper ontology | ontology signal과 relation residual |

## 제거 범위

- 구 진입점 13개
- 개선과정 개별 테스트 34개
- 미사용 시각화 모듈 18개
- 최종 파이프라인 비의존 레거시 모듈 47개
- 중간 checkpoint·구형 그림·구형 비교 결과
