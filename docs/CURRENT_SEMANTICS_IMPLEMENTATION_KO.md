# 현재 관측 관계 모델 — 구현 및 검증 상태

작성: 2026-10-27. `current_semantics_v1`은 구현·실험 체계를 재구성한 개발 후보이며 아직 성능 결과가 없다.

## 0. 작업본 적용과 native 검사 기록 (2026-10-27, 갱신)

아래 1–4절은 MATLAB 없는 환경에서 작성된 전달 당시 기록이다. 그 뒤 원래 작업본(`ugv_landing_2d_workspace`)에 패치를 적용했다.

- 패치는 `d438a7d`에 적용했다. 미커밋 showcase 변경이 있던 `AGENTS.md`·`run_live.m`은 수동 병합했다.
- 변경 전 소스는 `results/archive/pre_current_semantics_20261027/`에 있다(353개 + SHA256SUMS).
- **수정 1건:** 첫 native 실행이 `registry.m`에서 멈췄다. 원인은 필드 없는 `struct([])`에 구조체를 첨자 대입한 것이다("첨자를 사용한 대입식의 구조체가 서로 다릅니다"). 셀에 모은 뒤 연결하도록 고쳤으며, 방법 정의·순서·값은 그대로다. 실패 기록은 `results/current_semantics_v1/native_checks/attempt_01_registry_struct/`에 있다.
- **native `run_check` 통과**(MATLAB R2025b Update 6, TEST ONLY). 기록은 `results/current_semantics_v1/native_checks/run_check_20261027.log`와 `run_check_report_20261027.mat`이다.
  - 새 core: 특징 Jacobian 오차 2.7e−10이다. Semantic-MLP/Untyped/R-GAT의 Actor 파라미터 유한차분 오차는 3.8e−12/1.1e−11/1.3e−11, 입력 유한차분 오차는 1.1e−11/5.2e−12/4.8e−12, 실제 PPO 방향 미분 오차는 1.6e−11/2.5e−11/1.4e−11이다.
  - 실제 객체의 파라미터 수는 2095/2095/2094/2100이다. Raw PPO 초기 함수는 기존 PPO와 같고, 네 방법의 raw Critic 초기화도 같다. 8셀의 외생 manifest는 방법 간에 일치한다.
  - 네 방법 각 1 update, 8셀×4방법 32회 평가, 96개 진단 입력, 저장·복원 재생이 일치한다.
  - 보관 회귀: `residual_context.selfTest`는 통과했다(최대 미분 오차 1.4e−10). `minimal.selfTest`는 13/13, `orchestration.selfTest`는 14/14로 통과했다. 7노드 trace는 과거 checkpoint가 필요해 계속 미실행이다.
- 이 기록은 구현 검사이며 성능 근거가 아니다. 등록과 본 학습은 아직 없다. `run`을 누르면 smoke를 다시 실행한 뒤 등록과 개발 학습이 이어진다.

## 1. 기준과 변경 범위

기준 저장소는 `junsuk123/ugv_landing_2d_workspace`, 원격 기준 커밋은 `d438a7d4096d5b186c731c894306754aa5ab628d`다. 이 작업 환경에는 원래 저장소 사본이나 MATLAB이 없어 GitHub에서 고정 버전의 소스·문서 344개를 받아 별도 작업본을 만들었다. 각 파일의 원래 Git blob SHA-1을 대조했고 344개가 모두 일치했다. 과거 결과·체크포인트와 실행 중 C3 작업본은 복사하거나 수정하지 않았다.

원격에 변경을 반영할 때에는 위 기준 커밋의 **전체 tree를 기반으로 변경 파일만 추가·수정**한다. 로컬에서 확보하지 않은 과거 파일이 원격에서 삭제되지 않도록 한다. `verification/current_semantics/source_snapshot.json`은 선택적으로 확보한 원본의 출처 기록이다. 그 안의 로컬 snapshot commit은 도구가 만든 로컬 기준점이며 원격 연구 커밋과 구분한다.

**전달 상태:** GitHub의 tree 생성 요청은 연결의 쓰기 권한 부족으로 `403 Resource not accessible by integration`을 반환했다. 원격 브랜치·PR은 생성되지 않았다. 변경은 로컬 Git 커밋으로 보존하고 기준 커밋에 적용할 수 있는 패치와 전체 소스 ZIP으로 전달한다. ZIP에는 원격 기준에 있던 나머지 문서·프로젝트 파일 11개도 읽기 전용으로 확보해 원본 그대로 포함한다. 이는 자동 승인 검토 거절이 아닌 GitHub 연결 권한의 제한이다.

주요 구현 위치는 다음과 같다.

| 범위 | 구현 |
|---|---|
| 현재 의미 특징·그래프·R-GAT·역전파 | `src/algorithms/+landing2d/+current_semantics/` |
| 고정 비교군·개발/확인·등록·평가·진단·복구 | `src/orchestration/+landing2d/+current_semantics/` |
| 기존 PPO·그래프 경로 연결 | `agentInit`, `encoderInit/Forward/Backward`, `applyMethod`, `methodRegistry`, `algorithmVersion`의 새 버전 분기 |
| gradient clipping | 새 Actor 전체를 기존 잔차 버전과 같은 joint norm으로 clipping |
| 검증·저장/복원 연결 | `evaluateV2`의 새 특징 진단, `relationalPathActive`, 기존 graph hash/signature 검사 |
| 사용자 진입점 | 기존 `run`, `run_check`, `run_scenario`, `run_live` 네 개 유지 |
| Python 독립 감사 | `tools/current_semantics_audit.py` |

시뮬레이션 소스, 기존 보상, PPO Actor/Critic 손실, 행동 샘플링·적용 함수는 변경하지 않았다. 공통 코드의 새 계산은 `current_semantics_v1`에서만 선택된다. 보관 버전의 native 회귀 검사는 아래 미실행 항목에 포함한다.

## 2. 실제로 수행한 검사

다음은 Python과 정적 소스 검토 결과다. **MATLAB 코드를 실행한 결과가 아니며 성능 증거도 아니다.**

| 검사 | 결과 |
|---|---|
| 원본 소스 파일의 Git blob 일치 | 344 / 344 |
| 10,000개 현재 상태에서 물리식과 안정 유리식 대조 | 최대 절대 오차 약 `2.94e-15` |
| 64개 입력의 19×10 특징 Jacobian, 총 12,160 항목 | 최대 정규화 오차 약 `4.63e-9` |
| 고도·수평 위치의 정규화 척도가 다른 접근선 상태 | 100개에서 접근 오차·변화율·곱 특징의 0 일치 |
| 경계 근처 및 초기 미갱신 상태 | 유한성 확인 |
| 원 관측 보존과 그래프/flat 특징 배치 | 원 10개 값이 Φ19에 정확히 보존됨 |
| 그래프 도달성 | 모든 원시 관측 노드가 두 홉 안에 LandingContext에 도달 |
| 독립 파라미터 산술 | 2095 / 2095 / 2094 / 2100, 최대 차이 약 0.29% |
| paired-t 구간 산식과 SciPy 대조 | t 임계값 최대 차이 약 `5.33e-15` |
| 새 MATLAB 패키지 함수 참조·중복 이름 | 누락 참조와 같은 패키지 내 중복 구현 없음 |

재현 명령:

```bash
python3 tools/current_semantics_audit.py --output verification/current_semantics/audit.json
```

이 검사는 특징 정의·수학·배치와 정적 연결을 확인한다. 실제 MATLAB 역전파, Java 해시, 테이블 API, 병렬 실행, 폐루프 시뮬레이터 동작을 인증하지 않는다. 실제 감사 값과 검사 대상 파일의 SHA-256은 해당 JSON에 보관한다.

## 3. 준비했지만 아직 실행하지 않은 native 검사

`run_check`는 `landing2d.current_semantics.smokeTest`를 호출한다. MATLAB에서 실행되기 전까지 아래 항목은 모두 **NOT_RUN**이다.

1. `selfTest`: 모든 새 Actor 파라미터와 입력의 유한차분, 실제 공통 PPO loss 경로의 방향 미분, 원 관측 보존·경계·배치·호출 순서 독립성.
2. 실제 객체의 네 방법 파라미터 수, 기존 Raw PPO 초기 함수, 모든 방법의 동일 raw Critic 초기화.
3. 같은 평가 조건과 환경 시드에서 네 방법의 외생 manifest 일치.
4. 네 방법 각각 PPO 1 update, 8셀×4방법의 32회 짧은 평가와 집계. 결과는 TEST ONLY.
5. 고정 현재 상태 96개에서 행동 반응과 조건 상호작용 기록. 이 진단도 성능 증거가 아니다.
6. 저장·복원 후 체크포인트 signature·graph hash 및 동일 시드의 재생 일치.
7. 공통 분기 수정에 대한 보관 버전 회귀: `residual_context.selfTest`, `minimal.selfTest`, `orchestration.selfTest`를 같은 suite에서 자동 실행한다. 보관 suite 자체의 TEST ONLY smoke도 포함한다. 과거 stress 시드의 초기화·외생조건 검사는 성능 평가가 아니며 새 결과에 사용하지 않는다. 과거 checkpoint가 필요한 trace 회귀는 별도 미실행 항목이다.

개발·확인 본 학습은 각각 **NOT_RUN**이다. 새 성공률·위험 접촉률·학습 효율 수치를 생성하거나 과거 결과를 새 모델의 결과로 재사용하지 않았다. MATLAB이 설치되지 않은 것이 현재 실행상의 제약이며, 자동 승인 검토의 거절이나 추가 사용자 승인 요구 때문이 아니다.

## 4. 실행 순서와 중단 복구

저장소 루트에서 MATLAB 경로를 설정한 뒤 사용한다. `run_check`가 경로를 추가한다.

```matlab
report = run_check;
landing2d.current_semantics.register('development',report,pwd);
run
```

새 개발 진입점은 실제 native 검사와 등록 증거 없이는 본 학습을 시작하지 않는다. 개발 완료 후 코드·특징·시드·평가 조건을 변경하지 않고 다음을 실행한다.

```matlab
landing2d.current_semantics.runConfirmation(struct('root',pwd))
```

개발 게이트를 통과하지 못하면 확인은 닫힌 상태로 끝난다. 성능을 보고 후보·시드·기준을 추가하지 않는다. 등록 후 `run.m`의 phase 값을 편집하는 방식은 소스 동결 검사와 충돌하므로 사용하지 않는다.

학습 bundle과 checkpoint hash가 봉인된 이후 평가 중단이 발생했다면 같은 모델로 평가만 재개할 수 있다.

```matlab
landing2d.current_semantics.runPipeline(struct( ...
    'root',pwd,'phase','development','resumeEvaluation',true))
```

복구 경로는 기존 불완전 산출물을 별도로 보존하고 학습 함수를 호출하지 않는다. 학습 자체가 중단된 경우의 optimizer 복구는 이번 버전에 구현하지 않았다. 자동 재학습으로 같은 시드의 실패를 숨기지 않도록 중단 상태를 보존한다.

## 5. 남아 있는 연구 위험

- 같은 현재 관측을 구분하지 못하는 숨은 과거·외란의 차이는 이 구조로 해결되지 않는다.
- 현재 의미 특징이 기존 보상과 같다는 이유만으로 관계 경로를 사용하거나 성능이 개선된다고 보장할 수 없다.
- 두 주 비교를 통과해도 Raw PPO 대비 실용성·ID 유지·위험 접촉 기준이 실패하면 전체 연구 목표 완료로 처리하지 않는다.
- 5개 개발 시드나 20개 확인 시드로 작은 효과의 검정력이 충분하다고 미리 단정하지 않는다.
- 원격·다른 컴퓨터의 모든 과거 실행 이력에는 접근하지 못했다. 새 시드 충돌 검사는 실행 컴퓨터의 registry·결과·checkpoint에서 다시 수행한다.
- 3D `OntoReward-RL` 이식은 별도 acceptance를 통과하지 않았으며 이 2D 재구성의 구현·성능 결과에 합치지 않는다.

전체 연구 질문과 해석 기준은 [연구 재구성 문서](CURRENT_SEMANTICS_RESEARCH_KO.md), 고정 예산과 수치는 [실험 계약](CURRENT_SEMANTICS_EXPERIMENT_KO.md)을 따른다.
