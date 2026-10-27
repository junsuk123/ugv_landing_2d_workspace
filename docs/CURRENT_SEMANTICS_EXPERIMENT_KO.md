# 현재 관측 의미 관계 실험 — current_semantics_v1

2026-10-27 설계·구현 계약. **이 문서는 새 성능 결과가 아니다.** 이 구현 환경에는 MATLAB이 없어 실제 MATLAB 미분 검사, 1 update smoke, 본 학습과 확인 평가는 실행하지 않았다. 등록과 본 학습은 해당 native 검사가 실제로 통과한 뒤에만 실행 경로가 열린다. **갱신(2026-10-27):** 원래 작업본에 적용한 뒤 native `run_check`가 통과했다([구현 상태 0절](CURRENT_SEMANTICS_IMPLEMENTATION_KO.md)). 본 학습과 확인 평가는 아직 실행하지 않았다.

연구 가설은 [연구 설계](CURRENT_SEMANTICS_RESEARCH_KO.md), 특징·노드·관계와 역전파는 [알고리즘](CURRENT_SEMANTICS_ALGORITHM_KO.md)을 따른다. 실행 패키지는 `src/orchestration/+landing2d/+current_semantics/`, 알고리즘 패키지는 `src/algorithms/+landing2d/+current_semantics/`다.

## 1. 질문과 고정 경계

**동일한 현재 10D 관측의 의미 관계 구성이, 같은 특징의 MLP 및 관계 타입을 제거한 GNN보다 학습 범위 밖 착륙에 도움이 되는가?**를 검증한다. 기존 결과를 확인한 뒤 정한 새 가설이며, 이전 실패한 일반화 실험의 확인 결과로 소급하지 않는다.

정책 입력은 기존 인과적 항법 추정기가 내놓는 현재 10D다. 시간 이력, GRU, 이전 행동, 정책 메모리, 추가 센서, 새 가속 추정기, 미래·참값·성공 라벨 및 보조 손실을 추가하지 않는다. 기존 항법 추정기 자체의 내부 상태는 그대로다. GNN의 두 홉은 한 결정 시점에서의 관계 합성이며 두 시간 단계가 아니다.

원래 PPO 손실, 보상, 동역학, 센서, 직접 행동 적용, 종료, 탐색, 학습 분포, validation 선택·중단 규칙을 유지한다. Raw PPO의 actor는 10→110→2, 공통 critic은 10→55→1이다. 네 방법 모두 같은 raw critic을 사용한다. 모든 변경은 actor의 현재 상태 표현에 한정한다.

## 2. 네 방법

| ID | 현재 입력과 actor | 은닉 폭 | 총 학습 파라미터 |
|---|---|---:|---:|
| `ppo` | 원래 10D Raw PPO | 110 | 2,095 |
| `semantic_mlp_ppo` | R-GAT과 같은 19D 현재 특징을 받는 MLP | 65 | 2,095 |
| `untyped_gnn_ppo` | 같은 노드·방향·위상, 의미 간선 변환을 공유하는 GNN | 55 | 2,094 |
| `onto_rgat_ppo` | 의미별 관계 타입을 사용하는 R-GAT | 46 | 2,100 |

총수에는 actor, critic, 두 logσ가 포함된다. 등록 전 실제 초기 agent를 세어 위 수치와 일치하는지 검사한다. 차이는 0.3% 미만이다. 파라미터 수 일치만으로 모든 최적화 조건이 같다는 주장은 하지 않는다.

두 GNN은 같은 7노드·16간선·공유 두 홉·raw 관측과 LandingContext readout을 사용한다. Feature MLP는 같은 정적 문맥 상수와 파생 특징을 제공받는다. 원본 정보의 차이를 그래프 효과로 해석하지 않는다. 주 실험에 관계 shuffle은 추가하지 않는다.

주 비교는 **Typed−Feature MLP**, **Typed−Untyped GNN** 두 개다. **Typed−Raw PPO**는 선행 두 비교가 모두 통과한 뒤에만 확증적으로 판정하는 고정 순서의 후속 비교다. 사용자 목표인 기존 PPO 대비 착륙 개선까지 만족해야 목표 완료로 판정한다. Feature MLP−Raw PPO는 특징 가공의 효과를 설명하는 비교이며, 두 주 비교와 섞지 않는다.

## 3. 학습과 일회 예산

원래 750 update × update당 6 episode 상한, 25 update마다 validation, 원래 validation screen·plateau 규칙을 유지한다. checkpoint는 validation으로만 선택한다. OOD 결과로 checkpoint를 재선택하지 않는다. 공통 조기 종료 규칙이 있어 실제 사용 표본 수까지 항상 같지는 않다.

| 단계 | 학습 시드 | 모델 수 | 평가 환경 시드 | 고정 평가 에피소드 |
|---|---|---:|---|---:|
| 개발 | 61001–61005 | 5 × 4 = 20 | 12001–12100 | 16,000 |
| 확인 | 61101–61120 | 20 × 4 = 80 | 12201–12300 | 64,000 |

후보는 하나, 확인은 최대 한 번이다. 총 상한은 본 학습 100모델·450,000 episode, 평가 80,000 episode다. 주기적 validation과 아래 TEST ONLY 검사는 별도 비용이다. 개발 실패 후 다른 후보·임계값·난이도·추가 시드를 같은 계획에 덧붙이지 않는다.

개발 5시드는 기존 실험의 최소 개발 규모를 유지하고, 확인 20시드는 학습 변동성을 더 확인하기 위한 고정 예산이다. 과거 개발에서는 방법 차이의 시드 간 SD가 8–11%p 수준이었으므로 **20시드가 1–2%p 차이를 검출할 충분한 검정력을 보장하지 않는다.** 확인 CI가 넓으면 불확실한 결과로 보고하며 결과를 본 뒤 시드를 늘리지 않는다.

기존 431–450 및 9101–9200은 그대로 봉인한다. C3/C4 예약 471–475, 481–485도 재사용하지 않는다. 새 실험의 smoke는 학습 ID 61000, 환경 12999를 사용하고 임시 폴더에서만 실행한다.

`auditSeeds`는 알려진 보관 registry, 접근 가능한 로컬 결과 CSV, 등록 JSON, checkpoint 파일명의 중복을 검사한다. **접근할 수 없는 외부 실행 기록까지 미사용임을 입증한다고 표현하지 않는다.** validation/test/고정 사례/학습 episode 범위는 기존 설정을 유지한다. 새 평가 시드는 별도 프로토콜 필드에 보관하고 과거 stress manifest를 덮어쓰지 않는다.

## 4. 여덟 평가 셀

기존 [일반화 프로토콜 v2](GENERALIZATION_PROTOCOL_V2_KO.md)에서 PPO만으로 선택했던 강도를 재사용한다. 새 모델들의 결과를 보고 재보정하지 않는다. 각 셀은 같은 환경 시드 100개다.

| 요인 | ID 참조 | OOD | 양쪽에 고정하는 발생 조건 |
|---|---|---|---|
| Motion | 가속 0.3–0.8 m/s² | 1.5–2.0 m/s² | 모두 CA |
| Dropout | 누락 0.5–1.0 s | 2.1–2.9 s | 모두 severe 누락 |
| Noise | 잡음 표준편차 ×1 | ×3 | 원래 운동·누락 혼합 분포 |
| Combined | 위 세 강도가 모두 ID | 위 세 강도가 모두 OOD | 모두 CA·severe 누락 |

Noise ID가 전체 혼합 ID 평가를 겸한다. 다른 세 ID는 학습 범위 내 **조건부 참조**이며 전체 혼합 학습 분포와 같지 않다. Combined는 세 강도를 동시에 바꾸는 별도 스트레스 조건이다. Motion/dropout/noise의 단일 요인 차이와 혼동하지 않는다.

같은 셀·환경 시드에서 방법 간 초기 상태, 운동 일정, 외생 누락, 기저 잡음 표는 같다. 정책에 따라 폐루프 궤적과 실제 관측은 달라질 수 있다. ID/OOD의 같은 시드는 해당 강도만 바꾸도록 구성한다. 사건 노출 전에 종료한 episode도 포함하고, 실제 노출량을 보조 표로 공개한다.

기존 v2에서 dropout은 천장이 남아 있었다. 다시 천장이 나타나면 해당 조건의 구분력이 낮다고 보고한다. 또한 기존 문서의 “3초 이후 supervisor hold” 설명은 정정되었다. direct policy에서는 그런 명령 개입이 없으므로 이 범위의 근거로 사용하지 않는다.

## 5. 지표·통계

학습 시드별 네 OOD 셀 성공률의 등가중 평균을 주 지표로 쓴다.

\[
P_{m,s}^{OOD}=\frac14\sum_{k\in\{motion,dropout,noise,combined\}}p_{m,s,k}.
\]

조건별 episode를 먼저 평균하고, 같은 학습 시드끼리 방법 차이를 짝짓는다. **독립 분석 단위는 학습 시드**다. 에피소드 수를 독립 학습 반복 수로 취급하지 않는다. 모든 방법·시드·셀·환경의 완전한 짝을 검사하고 빠지거나 중복된 자료는 집계 오류로 처리한다.

Typed−Feature MLP, Typed−Untyped GNN에는 각각 **97.5% 양측 paired t CI**를 쓴다. 두 주 비교에 대한 Bonferroni family 수준은 t 구간 가정하에서 최소 95%다. 확인은 n=20, df=19다. 두 주 비교가 모두 통과하면 그다음 **Typed−Raw PPO의 95% paired t CI 하한 >0**을 판정한다. Raw를 세 번째 동시 주 비교로 바꾸지 않는 고정 순서 gatekeeping이다. Raw의 수치와 구간은 선행 비교 실패 시에도 공개하지만 그때는 기술 결과로만 해석한다. 조건별·나머지 보조 지표는 다중 비교 보정 없는 95% 기술 구간이다.

이 고정 순서는 이전 family의 모든 가설이 통과해야 다음 family로 진행하는 serial gatekeeping 원칙을 따른다([Dmitrienko, Tamhane & Wiens, 2008, DOI:10.1002/bimj.200710464](https://doi.org/10.1002/bimj.200710464)). paired t 구간은 독립적으로 학습한 시드 사이의 차이 분포에 대한 정규성/근사 조건을 전제로 한다. gate 실패와 무관하게 모든 방법·시드·비교의 수치와 구간을 공개한다.

이 구간은 고정 held-out 환경 목록을 조건으로 한 학습 변동성을 나타낸다. 환경 모집단 전체의 표집 불확실성까지 모두 반영한다고 확대하지 않는다.

함께 공개할 지표는 다음과 같다.

- 전체 혼합 ID 성공률, 조건별 성공률, 최악 OOD 성공률, 짝지은 ID→OOD 감소.
- 기존 세 요인만의 OOD 평균. 새 네 요인 평균과 같은 수치처럼 비교하지 않는다.
- 공통 평가기의 `Unsafe`, `Timeout`, terminal reason, 실패 분류, 학습 실패율.
- 에피소드별 aim RMS의 평균, 명령 변화, 실제 외생 누락 및 접근 중 시야 소실량.

`Unsafe`는 기존 공통 평가기의 위험 종료 정의를 유지한다. 비정상 접촉, 패드 이탈 접촉, 안전 영역 위반 등이 포함된다. Timeout은 성공률에서 실패로 남기고 최대 비행시간을 바꾸지 않는다. 전체 비행 추종 오차를 공개하며 성공한 비행만 남겨 평균을 개선하지 않는다. 성공 시각·접촉 오차를 추가 해석할 때는 성공/접촉 조건부 지표임을 명시한다.

## 6. 개발·확인 판정

### 개발

다음 조건을 모두 만족할 때만 같은 동결 설계로 확인 단계에 진입한다.

1. 네 방법의 5개 시드 모두 학습 중 validation 80%에 도달하고, 선택 checkpoint도 validation 80% 이상이다.
2. 두 주 비교의 OOD 평균 차이가 모두 양수다. 개발 CI 통과를 요구하거나 개발 결과를 확인 근거로 사용하지 않는다.
3. Raw PPO 대비 OOD 성공률 평균 차이도 양수다.
4. Raw PPO 대비 전체 혼합 ID 성공률 평균 감소가 2%p 이내다.
5. Raw PPO 대비 OOD `Unsafe` 평균 증가가 1%p 이내다.

학습 실패한 시드를 제외·대체·성능 이유로 재시작하지 않는다. 학습 실패가 우열을 만들면 일반화 효과와 분리해 보고한다.

### 확인

동일한 네 방법으로 새 학습 20시드와 새 환경 목록을 한 번 사용한다. 각 방법·시드의 기존 학습 기준을 유지하고, 다음을 모두 요구한다.

1. 두 주 비교의 97.5% CI 하한이 모두 0보다 크다.
2. 1이 통과한 뒤에만 Raw PPO 대비 OOD 성공률 차이의 95% CI 하한 >0을 후속 판정하며, 이것도 통과한다.
3. Raw PPO 대비 ID 성공률 차이의 95% CI 하한이 −2%p 이상이다.
4. Raw PPO 대비 OOD `Unsafe` 차이의 95% CI 상한이 +1%p 이하다.

2%p/1%p는 결과를 보기 전에 정한 **운영 판정 마진**이다. 과거 데이터가 증명한 안전 한계나 안전성 보장이 아니다. 두 주 비교만 통과하고 Raw 후속 비교가 실패하면 관계 효과의 근거와 기존 PPO 대비 개선 미확인을 분리해 보고하고 `goalComplete=false`를 유지한다. “차이가 유의하지 않다”를 동등성이나 무효과 증명으로 바꾸지 않는다.

## 7. 동일 현재 상태의 행동 진단

`diagnosticInputs`가 미리 정한 96개의 현재 관측을 모든 동결 정책에 똑같이 입력한다. 세 상호작용 × 8개 기준 상태 × 4개 교차 조건이다.

- 상대 위치 × 상대속도.
- 고도 × 수직속도.
- 영상 경과시간 × 상대속도.

원래 `toVector`로 관측을 만들며 자세 sin/cos, 상대속도의 구성, `visionUpdated`와 `visionAge`의 일관성을 보존한다. 실제 비행에서 모든 교차 상태가 같은 빈도로 발생한다고 주장하지 않는다. 진단 표를 정책의 이력 입력으로 사용하지 않는다.

각 교차 조건의 행동 평균을 동일한 행동 변환에 통과시킨 후 다음을 저장한다.

\[
I_\mu = \mu(o_{++})-\mu(o_{+-})-\mu(o_{-+})+\mu(o_{--}).
\]

코드의 `InteractionX/Z`는 위 식을 실제 가속 명령에 적용한 값이다. 원래 평균 `MeanX/Z`도 따로 저장한다. 큰 상호작용이나 attention은 좋은 제어, 인과적 중요도, 일반화 우위의 지표가 아니다. 이 진단은 **현재 문맥에 따라 행동이 달라지는지**를 설명하며 폐루프 성능을 대신하지 않는다.

현재 운동과 다음 명령은 같지 않다. 하강 중 제동에는 위쪽 가속이 필요할 수 있다. 또한 동일한 현재 10D 뒤에 서로 다른 숨은 가속·소실 원인이 있어도 memoryless 정책은 동일한 행동 분포를 낸다. 그래프가 관측에 없는 정보를 복원했다고 주장하지 않는다.

## 8. 실행·등록·중단 복구

프로젝트 루트에서 MATLAB 경로를 설정한 공개 진입점을 사용한다.

```matlab
report = run_check('current-semantics');  % 실제 native 검사 + 4군 각 1 update, TEST ONLY
landing2d.current_semantics.register('development',report,pwd);
output = landing2d.current_semantics.runDevelopment(struct('root',pwd));

% 개발 통과 뒤, 등록된 소스 파일을 편집하지 않고 runtime 옵션으로 호출한다.
confirmation = landing2d.current_semantics.runConfirmation(struct('root',pwd));
```

`run` 또는 등록 없이 `runDevelopment`를 호출해도 native 검사→등록→학습 순서로 진행한다. 이미 현재 소스로 통과·등록한 native 검사는 반복하지 않는다. 확인은 같은 소스의 개발 검사 증거를 재사용하고 개발 통과를 확인한다. **확인 단계로 바꾸기 위해 `run.m`을 편집하면 등록 소스 해시가 달라지므로, 위 함수 호출을 사용한다.**

native suite는 새 core의 수식·역전파, 네 새 방법 각각 1 update, 여덟 셀 smoke, 저장/복원 재생에 더해 `residual_context.selfTest`, `minimal.selfTest`, `orchestration.selfTest`의 보관 회귀를 실행한다. 보관 suite에는 자체 TEST ONLY smoke가 있으므로 “새 모델 네 개”를 전체 검사 연산량으로 오해하지 않는다. 보관 `checkGeneralization`의 기존 stress 시드 초기화·외생조건 비교는 정책 성능 평가가 아니며 새 실험의 결과에 포함하지 않는다. 과거 7노드 trace는 해당 역사 checkpoint가 필요하므로 이 자동 suite에 포함하지 않고 pending으로 기록한다.

등록에는 `src/**/*.m`, 루트 MATLAB 진입점, `README.md`, `AGENTS.md`, `docs/**/*.md`, `tools/**/*.py`, 현재 설정·시드·통계·마진·예산·실제 native 검사 결과의 SHA-256을 남긴다. native 검사 보고서도 당시 소스와 설정에 묶는다. 실행 전·학습 후·평가 후 소스가 같은지 확인한다. 학습·확인 중 조건, 코드 또는 문서를 변경하지 않는다.

출력은 `results/current_semantics_v1/` 아래에만 저장한다. checkpoint는 공통 `checkpoints/`에 학습 시드별로 저장하고, 평가·등록은 `development/`와 `confirmation/`으로 나눈다. 이전 모델과 결과는 덮어쓰지 않는다. `training_complete.mat` 및 `training_manifest.json`에 완료된 학습과 checkpoint 해시를 봉인한다.

학습이 모두 끝난 뒤 평가가 인프라 문제로 중단됐을 때는 다음처럼 **평가만** 재개할 수 있다.

```matlab
output = landing2d.current_semantics.runDevelopment( ...
    struct('root',pwd,'resumeEvaluation',true));
% 확인 평가의 중단에는 같은 옵션을 runConfirmation에 전달한다.
```

이 경로는 등록 소스, 학습 bundle SHA, 각 checkpoint SHA·서명·그래프·선택 history를 확인한다. 중단된 평가 산출물과 실행 로그는 `interrupted_evaluation_attempt_NNN/`에 보존하고 동일한 동결 모델로 같은 평가를 다시 수행한다. optimizer나 trainer를 호출하지 않는다. 완료된 평가에는 재개를 허용하지 않는다.

**학습 중단의 자동 복구는 구현하지 않았다.** 전체 `training_complete.mat`와 봉인 manifest가 없으면 재개를 거절한다. checkpoint·로그를 지우거나 재학습하여 우회하지 않고, 동일 시드·설정·시도 보존을 확인하는 별도 수동 복구가 필요하다. 이는 통계 중단 규칙과 인프라 오류를 섞지 않기 위한 현재 구현의 한계다.

주 산출물은 `primaryBySeed.csv`, `primaryContrasts.csv`, `ppoContrasts.csv`, `guardContrasts.csv`, `generalizationEpisodes.csv`, 조건별 요약·실패 표, `validationBySeed.csv`, `matchedActions.csv`, `semanticInteractionsBySeed.csv`, `results.mat`, 등록·학습·완료 manifest다. TEST ONLY 출력은 본 실험 수치에 포함하지 않는다.

## 9. 3D와 주장 범위

이 실험은 현재 10D를 사용하는 2D 폐루프 과제다. 별도 `OntoReward-RL` 3D 포트의 migration acceptance는 앞선 감사에서 전체 FAILED였으며, 관측/그래프 parity 일부 통과를 실제 현행 3D 학습·폐루프 검증 완료로 표현하지 않는다. 이 결과를 3D 결과와 합치지 않는다. 3D는 별도 이식 검증 후 후속 실험으로 다룬다.

현재 기록 가능한 상태는 **새 설계와 코드 준비, native 검증·본 학습·확인 미실행**이다. 실제 실행 결과가 나오기 전 성공률 향상, 안정성 개선 또는 관계 효과를 입증했다고 쓰지 않는다.
