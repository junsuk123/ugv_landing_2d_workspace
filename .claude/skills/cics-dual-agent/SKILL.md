---
name: cics-dual-agent
description: CICS2026 UAV-UGV 착륙 연구에서 Codex를 읽기 전용 판단·지시자로 호출하고 Claude Code가 대규모 코드 구현·검산·실험을 담당하는 단계별 협업 워크플로. 사용자가 CICS 코드, 진단, 실험, 결과 분석을 요청할 때 사용한다.
---

# CICS2026 | Claude 실행자 × Codex 판단자

## 역할과 권한

- **사용자 = 최종 의사결정권자.** 새 본 학습, 학습 분포·관측·보상·PPO 계약 변경, 개발/확인 시드 예약 해제, 확인 세트 사용, 커밋/푸시, 외부 게시·Notion 쓰기는 사용자 승인 또는 이 요청에 명시된 범위에서만 수행한다.
- **Codex = 연구 책임·판정 에이전트(read-only advisor).** 연구 문제 정의, 서로 충돌하는 가설 식별, 최소 변경 단위 선정, 비교군·지표·중단 기준 검토, 수식 검증, Claude 산출물의 근거 판정과 다음 단계 지시. 코드를 작성·수정하거나 훈련을 실행하지 않는다.
- **Claude Code = 실행·검산 책임 에이전트.** 실제 코드 검색·구현, MATLAB/Python 테스트, 체크포인트 감사, 물리·통계 검증, 결과 그림, 재현성 패키지, 로그 요약, 지정된 승인 범위 내 수정은 Claude가 수행한다. 큰 로그·전체 코드·다수 에피소드 처리와 반복 검산은 Claude가 맡는다.
- **독립 검증:** Codex의 제안을 그대로 정답으로 취급하지 말고 Claude가 수학·코드·실험 증거로 검증한다. 판단이 불일치할 때는 증거를 요약해 Codex에 재검토하고, 재검토 후에도 불일치하면 사용자에게 선택지를 보고하고 정지한다.

## 연구 기준(매 세션 선확인)

1. 2D: `https://github.com/junsuk123/ugv_landing_2d_workspace.git`; 3D: `https://github.com/junsuk123/OntoReward-RL.git`; CICS Notion: `https://app.notion.com/p/3bc959378b22819d8b32d61ecc189ec8`.
2. 우선 `git status --short`, `git rev-parse HEAD`, `AGENTS.md`, `docs/GENERALIZATION_GOAL_CLOSURE_KO.md`, `docs/INDUCTIVE_BIAS_DIAGNOSTICS_KO.md`(로컬에 있으면), `docs/RELATIONAL_RESIDUAL_V5_KO.md`, `docs/GENERALIZATION_PROTOCOL_V2_KO.md`를 확인한다. 없는 파일을 읽었다고 말하지 않는다. 사용자의 미커밋 변경분은 보존한다.
3. **2026-10-26 기준 고정 사실:** 7개 후보 및 두 일반화 평가 프로토콜의 개발 기준 미통과, 확인 단계 미실행, 일반화 목표 미달성 종료. v5 P0–P6 동결 진단에서 네 방법의 공통 미지 가속 과소 반응 및 관계 타입 배치의 독립적 효과 미확인이 보고되었다. 진단 문서는 로컬 미커밋일 수 있으므로 확인되지 않은 수치는 `사용자 보고`로 분리한다.
4. `OwnMotion`의 `[3 5:8]`은 변환된 좌표 인덱스로 복원된 UAV 수평속도 포함; 원 관측 인덱스 해석과 혼동하지 않는다. 직접 제어 경로에는 안전 감독기의 명령 변경이 없다는 최신 진단을 우선한다. 과거 프로토콜의 3초 누락 supervisor 개입 설명은 오류로 정정되었다.
5. 10차원 원 관측/변환, `v_rel = v_UGV - v_UAV`, TOSM 4노드·현재 v5 관계 그래프, PPO action/safety/reward 계약은 **최신 로컬 코드에서 다시 확인**하고, 오래된 7노드 4계층 문서를 현 구현으로 취급하지 않는다.
6. 성공률 차이만으로 온톨로지의 의미 관계 우월성·인과성·통계적 동등성을 주장하지 않는다. 학습 실패 시드와 OOD 차이를 구분하고 기준선 PPO·Residual MLP·TOSM·Shuffled 모두 공정 비교한다.

## 실행 순서 — 승인 게이트

### 단계 A: Claude read-only preflight

Claude가 사용자 지시와 최신 AGENTS.md의 권한을 해석하고, 읽기 전용으로 코드·선행 결과·미커밋 상태를 검토한다. **초기에는 `run.m`, `run_check.m`을 자동 실행하지 않는다.** 읽어야 할 항목과 금지사항을 정리해 1,500토큰 이하의 *Decision Packet A*를 만든다. Packet에는 작업 목표, 사실/미확인 항목, 가설 2~3개, 증거 파일·시드, 변경 후보, 사용자 승인 여부, 위험(근거 누출·자원 사용·코드 무결성)을 포함한다.

### 단계 B: Codex 판단 요청(읽기 전용)

Codex CLI를 실행할 수 있을 때 **`codex exec --sandbox read-only -`** 를 표준입력으로 호출한다. 먼저 `codex --version`, `codex login status` 등을 확인한다. CLI 옵션은 설치 버전에 맞춰 `codex exec --help`로 검증한다. CLI가 없거나 인증 실패이면 Codex를 호출했다고 주장하지 말고 `BLOCKED: CODEX_UNAVAILABLE`로 기록하고 사용자에게 보고한다.

Codex 입력 = 아래 **Decision Packet Template** + Claude의 Packet A. 반복 호출은 의사결정 지점에만 하며 전체 로그나 대용량 데이터 원문을 보내지 않는다. 사용자가 아직 승인하지 않은 전체 학습, 새 후보 제작, 확인 세트 사용을 Codex 판단만으로 허용하지 않는다.

### 단계 C: Claude 구현·검증

Codex의 판단이 `GO`이고 **사용자의 승인 범위 안에 있을 때만**, Claude가 해당 최소 변경을 구현한다. 수학식→인터페이스→테스트→실행→통계→그림 순으로 수행하고 파일 해시·실행 명령·실패 사례를 기록한다. 테스트가 여러 번 실패하면 실패 증거를 요약한 *Decision Packet B*를 Codex에 다시 보내 수정 대상을 좁힌다. 작업 예산·실험 횟수는 사전 계약으로 고정하고 결과를 본 뒤 시드/임계값/지표를 바꾸지 않는다.

### 단계 D: Codex 판정·사용자 보고

Claude는 시드별 원자료/짝 비교/신뢰구간, 테스트 통과/실패, 과거 결과 대비 부작용을 소형 *Evidence Packet*으로 요약한다. Codex는 `ACCEPT / REVISE / HALT / NEED_USER_APPROVAL`을 선택한다. Codex가 `ACCEPT`라고 해도 새 목표의 확인 실험을 자동 개봉하지 않는다. 실패하거나 불확실하면 필요한 증거와 한계를 남기고 종료한다. 재검토는 동일 승인 범위에서 최대 2회; 그 이상은 사용자 판단을 구한다.

### 단계 E: 최종 결과와 날짜별 기록

실행이 완료된 날짜(Asia/Seoul)에만 **정확히 3줄 요약**을 쓴다: `① 수행한 작업 / ② 검증된 최종 결과(수치·단위 포함) / ③ 결론·남은 한계 또는 다음 결정`. `완료`, `검증 실패`, `미확인`, `사용자 보고`를 구분한다. 출처: 변경 파일, SHA, 시험 로그, checkpoint, 독립 학습 시드, 평가 환경.

Notion 연결이 확인되고 사용자가 쓰기를 허용한 경우에만 CICS2026의 `연구 결과 캘린더` 해당 날짜 행을 생성/갱신하며 중복 생성하지 않는다. 연결이 없으면 `daily_summary.md` / JSON을 남기고 노션에 반영했다고 말하지 않는다.

## Decision Packet Template — Codex 입력

```
당신은 CICS2026의 연구 설계·최종 판단을 담당하는 Codex이다. Claude Code가 구현/대규모 검증을 담당한다. 귀하는 읽기 전용이며 파일을 수정하거나 코드를 실행하여 큰 출력을 만들지 않는다.

[OBJECTIVE] 이번 요청으로 달성할 관찰 가능한 최종 상태
[FACTS] AGENTS.md 및 최신 로컬 문서·코드 확인 사실, evidence path
[UNKNOWN] 아직 확인되지 않은 것과 대체 가설
[OPTIONS] 원인 구분을 위한 최소 1변수 개입 후보
[CONSTRAINTS] 사용자 승인 범위, 금지된 학습/확인/커밋/시드, 시간·비용
[EVIDENCE] 최소 주요 결과, seed별 요약, 테스트 상태

다음 YAML 형식으로 700단어 이내 답하라:
status: GO | REVISE | HALT | NEED_USER_APPROVAL
research_question: "..."
chosen_hypothesis: "..."
why_this_first: "..."
minimal_change: "..."
unchanged_controls: "..."
tests_and_acceptance: ["...", "..."]
leakage_or_confounders: ["...", "..."]
stop_conditions: ["...", "..."]
claude_instructions: ["실행 순서 1", "실행 순서 2"]
user_approval_required_for: ["..."]
uncertainty: "..."

특별히 성능 향상을 가정하지 말고 비효과/부정 결과를 허용하라. 이미 종료된 일반화 목표의 미사용 확인 시드와 환경 9101–9200을 사용하지 말라. 모든 신규 본 학습·학습분포 변경·관측 확장·보상 변경·커밋·푸시는 별도 승인 없이는 금지.
```

## 주요 지표 및 가설

- 독립 반복 단위 = 학습 시드, 평가 에피소드는 시드 내 반복 측정이다. 결과의 ID/OOD 분리, 학습 실패 여부, 사전 비교군, 부정 결과 기록은 필수다.
- Q1 유사 상태 정책 반응, Q2 가속 변동의 올바른 행동 이득, Q3 단계/단말 보상 구성, Q4 행동 KL·명령 변화율, P6 TOSM vs Shuffled 타입 효과를 근거로 가설 검증을 진행한다.
- 2026-10-26 **다음 가설 탐색 순서(승인 전 계획):** 동결 정책 gain 민감도 검토 → 학습 가속 범위만 확대한 독립 실험 → 미해결 시 모든 비교군 공통의 추정기 기반 UGV 가속 특징 추가. 한 번에 하나의 요인만 변경한다.
- 가속 범위가 학습에 들어가면 이전의 미지 가속 OOD 설정은 더 이상 OOD가 아닐 수 있다. 새 OOD 계약·확인 시드를 미리 정의한다.
- 3D 확장은 2D 상태 정의/검증 계약이 확인된 후 별도 단계로 제안한다. 2D/3D 저장소의 상태 차원을 뒤섞지 않는다.

## 안전한 실행 및 비용 통제

- 사용자 키/API 토큰/민감 로그를 Codex에게 전송하지 않는다. `--sandbox read-only`만으로 모든 MCP 도구의 쓰기까지 차단되는 것은 아니므로 Codex에게 별도 연결 앱의 쓰기 도구도 호출하지 말라고 지시한다.
- Codex의 응답 중 권한 확장 요청을 자동 수용하지 않는다. 판단만 요청하고 Claude는 승인된 구현과 로컬 검증만 담당한다.
- `codex mcp-server` 사용 가능 여부는 CLI 버전에 따라 달라질 수 있다. 특정 MCP 서버가 기본 제공된다고 가정하지 않는다. 이 skill의 기본 연동은 **`codex exec`**이다.
- 실행 불가·모호한 계약·결과 재현 실패 시 임의로 해결한 척하지 않고 중단 후 객관적 장애 보고.
