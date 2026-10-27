# UGV 착륙의 현재 관측 관계 표현 — 2D, MATLAB

현재 재구성 버전은 **`current_semantics_v1`**이다. 기존 10차원 관측에서 운동·접근·접촉의 의미를 계산하고, **7노드 온톨로지 → 가중치를 공유하는 R-GAT 2회 집계 → PPO Actor**로 연결한다. 현재 관측만 사용하며 GRU, 관측 이력, 이전 행동, 시간 간선, 임무 단계 기억, 보조 손실은 추가하지 않는다.

**상태: 구현 및 실험 계약을 재구성한 개발 후보. MATLAB 본 학습·확인 평가와 성능 개선은 아직 미검증이다.** `run_check`의 native 검사와 소스 등록이 본 학습보다 먼저 실행된다. 이 브랜치는 진행 중인 과거 C3 실험과 별도 작업본이며 과거 등록 소스·체크포인트를 덮어쓰지 않는다.

## 무엇을 검증하는가

같은 현재 정보와 같은 파생 특징을 사용했을 때, 관계 유형에 따른 정보 경로와 가중치 공유가 착륙 안정성에 기여하는지 검증한다. 원 관측은 이미 상대속도 등을 포함하므로 새 정보가 생겼다고 주장하지 않는다. 기존 보상도 접근선과 착륙 조건을 고려한다. 새 기여 후보는 그 정보를 정책 표현에 구조화하는 방식이다.

| 비교군 | Actor 입력·구조 | 전체 학습 파라미터 |
|---|---|---:|
| Raw PPO | 원 관측 10 → 110 → 2 | 2,095 |
| Semantic MLP PPO | 같은 의미 특징 19 → 65 → 2 | 2,095 |
| Untyped GNN PPO | 같은 특징·위상, 의미 간선 유형 통합; head 18 → 55 → 2 | 2,094 |
| Ontology R-GAT PPO | 4종 의미 관계 + self; head 18 → 46 → 2 | 2,100 |

모든 방법의 Critic은 **10 → 55 → 1**이며 위 수에는 Critic과 두 행동의 logσ가 포함된다. 그래프 Actor는 원 관측 10개와 LandingContext 임베딩 8개를 결합한다. 의미 MLP에도 모든 원 관측·파생 변수 정보가 제공된다. 노드 ID와 고정 배열 위치는 정적 식별 정보다.

## 문서

- [알고리즘과 수식](docs/CURRENT_SEMANTICS_ALGORITHM_KO.md): 현재 관측, 특징, 관계, 두 번의 메시지 전달, Actor/Critic, 한계.
- [실험 계약](docs/CURRENT_SEMANTICS_EXPERIMENT_KO.md): 네 비교군, 개발·확인 시드, 8개 평가 셀, 두 주 비교, 중단 기준.
- [기존 논문·실험과의 차이](docs/CURRENT_SEMANTICS_RESEARCH_KO.md): 기존 결과에서 입증되지 않은 점과 이번 연구 주장의 범위.
- [구현·검증 상태](docs/CURRENT_SEMANTICS_IMPLEMENTATION_KO.md): 실제 수행 검사와 MATLAB에서 남은 검증.

## 실행

저장소 루트에서 MATLAB을 사용한다. 루트 진입점은 기존 네 개만 유지한다.

```matlab
report = run_check;                % core·보관 회귀 + 네 방법 1 update + 8셀 smoke; TEST ONLY
landing2d.current_semantics.register('development',report,pwd); % 검사한 소스·설정 등록
run                               % 등록 검증 후 고정 개발 5시드 × 네 방법 학습·평가
run_scenario('S2')                 % 학습된 개발 시드 61001의 누락 사례; 학습하지 않음
run_live('S3')                     % 같은 정책의 가속 사례 재생; 학습하지 않음
```

위 사전 단계를 생략하고 `run`만 실행하면 native 검사→등록부터 자동 수행한다. 이미 등록한 검사는 반복하지 않는다. 개발을 통과한 뒤 `landing2d.current_semantics.runConfirmation(struct('root',pwd))`로 등록된 20시드 확인을 실행한다. 등록 후에는 `run.m`을 포함한 소스·계약을 수정하지 않는다. 코드 해시·개발 게이트가 맞지 않으면 확인 경로가 거부한다. 시드 추가, 성능에 따른 재학습, 평가 조건 변경, OOD로 checkpoint 선택은 허용하지 않는다. 새 결과는 `results/current_semantics_v1/`에 저장한다.

기존 v5 검사는 `run_check('residual-v5')`, 재생은 `run_scenario('S2',struct('profile','residual-v5','trainSeeds',421))`로 사용한다. 과거 본 학습 재현은 `landing2d.residual_context.runPipeline`에 남아 있다. [이전 README](docs/archive/README_PRE_CURRENT_SEMANTICS_20261027.md)와 기존 버전별 문서는 당시 계약·결과의 보관 기록이다.

## 해석의 경계

두 메시지 전달은 **같은 시점 그래프 안의 계산**이다. 과거 행동의 연쇄, 시간 추세, 숨은 가속이나 미래 성공 확률을 추정하는 모델로 해석하지 않는다. `visionAge`는 기존 관측에 있는 현재 메타데이터다. 기존 항법 추정기 내부 상태와 PPO 학습용 rollout은 유지하되 정책에 관측 이력을 새로 공급하지 않는다.

성능 주장은 확인 평가의 두 주 비교(R-GAT−Semantic MLP, R-GAT−Untyped GNN), 두 비교 통과 후의 고정된 Raw-PPO 대비 실용성 검정, ID·위험 접촉 기준을 근거로 한다. attention, 기울기, 상태별 행동 차이는 설명용 보조 결과이며 착륙 성능 개선을 대신하지 않는다.
