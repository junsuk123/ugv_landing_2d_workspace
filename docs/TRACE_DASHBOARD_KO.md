# 결정 추적 대시보드 (`decision_trace_v1`)

> **보관 모델 전용:** 이 대시보드는 기존 7노드 그래프를 재현한다. 현재 4노드 모델의 진단은 `run_scenario`와 `run_live`를 사용한다([현재 시스템](MINIMAL_SYSTEM_KO.md)). 아래 옛 루트 호출 예시는 `landing2d.orchestration.runTrace`를 명시적으로 호출할 때만 적용한다.

학습된 `onto_rgat_ppo`(M2) Actor 한 에피소드를 결정 시각 단위로 기록하고 보여 주는 진단 도구다. 원천별 센서 사건(카메라 프레임, ArUco 마커 검출, PnP, UGV 칼만 필터, UAV 자체 항법 추정)에서 시작해 공통 관측 $o_t$(v2.3부터 10차원), TOSM 노드 특징 $X_t$, R-GAT 층들의 관계별 메시지(층 수는 체크포인트에서 읽음, v2.2부터 4층), 그래프 리드아웃 $g_t^A$를 거쳐 실제 요구 가속도 $[a_x,a_z]$까지 이어지는 경로를 그린다. 결정마다 한국어 상황 설명도 붙인다.

- 평가 지표가 아니다. 체크포인트·사례·임계값을 고르는 데 쓰지 않는다(`EXPERIMENT_DESIGN_KO.md` §5). 실험 결과의 근거로도 인용하지 않는다.
- 새 추론 모델이 아니다. 시뮬레이션과 신경망은 기존 함수가 계산한다. 이 도구는 그 값을 읽어서 보여 줄 뿐이다.
- attention 계수·하이라이트 경로는 기술적 진단이다. 인과적 중요도, 원인 증명, 착륙 승인, 안전 보장으로 해석하지 않는다.

> 2026-10-20부터 기본 인코더가 `rgat_v2`다(2층, 관계 간 attention, 게이트 없음, `RGAT_V2_DESIGN_KO.md`). 그래서 기본 체크포인트는 학습 시드 16이다. 대시보드는 층별 α, 층 1·최종 노드 임베딩, 2홉 근거 사슬을 보여 준다. 아래 S4 수치 예와 시험 기록은 v1.1(`typed_v1`, 시드 11)로 만든 것이다.

## 실행

```matlab
run_scenario('S4',struct('trace',true))                    % 실시간 대시보드 (학습된 M2, 기본 학습 시드 16)
run_scenario('S1',struct('trace',true,'visible',false))    % 화면 없이 기록 + 내보내기
run_scenario('S4',struct('trace',true,'staged',true,'speed',0.5))   % 설명용 단계 재생
run_scenario([],struct('replay','results/trace/S4_onto_rgat_ppo_s11_r01.mat'))  % 재생 (정책 재실행 없음)
run_check('trace')                                         % 수용 시험 A01–A13 (headless, 약 1분)
```

추가 옵션(`landing2d.orchestration.runTrace`):

| 옵션 | 기본값 | 내용 |
|---|---|---|
| `trainSeed` | 16 | M2 체크포인트 학습 시드 (v2.0 첫 시드) |
| `replicate` | 1 | 통제 사례 잡음 반복(에피소드 시드 = 43001 + r − 1) |
| `deterministic` | true | 평가와 같은 평균 행동. false면 확률적 표본을 쓰고, 평균 기반 미리보기를 따로 기록한다 |
| `live` | `visible`과 같음 | 에피소드를 진행하면서 결정마다 대시보드에 보낸다 |
| `speed` | 1 | 재생 속도 0.25x–4x. 기준은 기록된 시뮬레이션 시각이다 |
| `staged` | false | 설명용 단계 재생 |
| `png` / `video` | true / false | PNG / MP4로 내보낸다(MP4는 프레임당 약 0.5 s) |
| `mock` | false | 학습되지 않은 `agentInit` 가중치. 모든 출력에 `TEST ONLY` 표시가 붙는다 |

- 기본 체크포인트는 학습 시드 11이다. v1.1 확인 실험의 첫 시드(`registry.trainSeeds.confirmatory(1)`)이며, trace를 보기 전에 정했다. S1–S4 결과를 보고 고른 값이 아니다.
- 학습 시드 1–10의 M2 체크포인트는 v1.0 서명이다. 지금 설정에서는 `landing2d:CheckpointMismatch`로 거부된다(2026-10-19 확인). 이 경우 재학습하지 않고 오류로 멈춘다.

## 정책 비간섭 계약

- 환경·보상·행동·종료·PPO·R-GAT 파일은 바꾸지 않았다. `+trace`, `TosmTraceDashboard`, `runTrace`를 새로 추가했다. `runScenario`·`runCheck`에는 분기만 넣었다.
- 기록 루프(`landing2d.trace.recordEpisode`)는 `rolloutEpisodeV2`와 같은 순서로 같은 함수를 호출한다.
  - reset → $o_t$의 TOSM 그래프 → 에피소드 자체 난수열로 `policyAction` → `valueForward` → `step`
- 센서 경로는 `landing2d.trace.decisionSensing`이 결정 시각 입력 그대로 다시 실행한다.
  - 입력: 같은 상태, 같은 시간 기준 잡음표 열 `stepCount+1`, 같은 dropout·프레임 조건
  - 재실행해 만든 $o_t$와 기억이 환경 값과 비트 단위로 같아야 한다(`landing2d:TraceReplay`). 그래서 표시하는 마커 ID, PnP 결과, KF 갱신 종류는 실제 run의 값이다.
- Actor 수치(`landing2d.trace.actorForward`)는 `encoderForward`·`mlpForward`·`valueForward`의 캐시다. μ와 V가 `policyAction`·`valueForward`의 결과와 비트 단위로 같아야 한다(`landing2d:TraceForward`).
- 화면은 기록의 복사본만 받는다. 콜백에서 오류가 나면 콜백만 끄고, 에피소드는 바뀌지 않는다.
- 위 보장은 A09가 시험한다. S1·S4 × 결정론적·확률적 경우와, live 대시보드 공급이 있는 경우에 행동·관측·보상·가치·로그확률·참값 궤적·종료가 비트 단위로 같다.

## 사건과 시각

평면 계약에서는 카메라 프레임·마커 검출·PnP·KF·항법 추정이 모두 결정 구간 끝(10 Hz)에서 한 번 계산된다. 0.01 s 물리 스텝에서는 센서 사건이 생기지 않는다. 사건 시각은 코드가 쓰는 데이터 시각이다.

- 카메라: `detections.stamp`
- 항법: `navigationStamp`
- KF: 갱신 시각
- 정책: 결정 시각

같은 결정 시각에 일어나는 단계들의 `Phase`는 화면 표시 순서일 뿐이다. 지연을 뜻하지 않는다. 별도 처리 시각은 모델에 없으므로 `ProcessingTime_s = NaN`이다.

| 사건 | 발생 조건 |
|---|---|
| `camera_frame` | 프레임이 있음 (마커 0개여도 기록) |
| `marker_valid` / `marker_missing` | 등록 마커 검출 / 프레임은 있으나 검출 없음 |
| `pnp_valid` / `pnp_rejected` | 검출 코너로 PnP를 시도해 채택 / 기각 |
| `kf_measurement_update` | 채택된 PnP 측정이 KF에 들어감(첫 측정은 `initialization`) |
| `kf_time_update` | 측정 없이 예측만 함. 과거 추정을 0으로 만들지 않는다 |
| `own_navigation_update` | 새 항법 추정 |
| `common_observation_built` … `actor_action_decided` | 결정 시각의 계산 |
| `episode_terminal` | 종료. 영상 없음, 항법·KF 예측만 있음, 정책 결정 없음 |

S4, 학습 시드 11, 반복 1(2026-10-19 기록):

- **카메라**: 169프레임, 10.00 Hz.
- **항법**: 170건(종료 시각 16.84 s의 마지막 추정 포함), 10.03 Hz.
- **마커 검출**: 138건. 미검출 31건 중 8건은 외부 주입 누락(3.1–3.8 s), 23건은 최종 하강 사각지대(14.6 s 이후)다.
- **누락 구간 동작**: 프레임은 계속 들어온다. 같은 구간에 마커·PnP·측정 갱신은 없고 KF 시간 갱신만 있다. visionAge는 0.10 → 0.80 s로 늘고 결정은 계속된다.
- **누락 구간 경계**: 주입 구간은 [3.0, 3.8) s다. 그런데 환경 시각이 0.01 s 누적이라 3.0 s 프레임은 2.99999…로 구간 밖이 되고, 3.8 s 프레임은 3.79999…로 구간 안이 된다. 환경의 기존 동작이며, trace는 그대로 보고한다.

## 세 연결 층

화면 중앙은 성격이 다른 세 층을 서로 다른 모양으로 그린다.

1. **(A) 센서·추정기 데이터 흐름.** 카메라 → ArUco 검출 → PnP → UGV KF, 그리고 UAV 항법 → PnP(카메라 포즈) / KF(초기 속도). 원천은 카메라와 항법 둘뿐이고, 나머지는 처리기다. GNSS·IMU 장치 스트림은 모델에 없다.
2. **(B) $o_t$ → 노드 특징 파생.** 결정론적 의존이며 메시지 전달 간선이 아니다. 연결은 코드에서 섭동으로 구한다(`landing2d.trace.provenanceMap`). `toVector`와 `observationVectorGraph`의 입력을 하나씩 흔들어 보고, 값이 바뀌는 특징만 연결한다. A03이 아래 표와 같은지 확인한다.

| 노드 | $o_t$ 성분 | 고정 상수 |
|---|---|---|
| VisionQuality | ugv_visionUpdated, ugv_visionAge | – |
| PadVelocity | ugv_vx | – |
| RelativePosition | relative_x, relative_height | cameraPitchOffset (cross-track 기울기 $m$) |
| RelativeVelocity | relative_vx | – |
| DroneMotion | drone_vz, sinθ, pitchRate (cosθ 없음; v2.3에서 상수 항법 유효·경과 제거) | – |
| ViewMargin | relative_x, relative_height, sinθ, cosθ | cameraPitchOffset, FOV, 위치·고도 정규화 척도 |
| LandingCondition | relative_x, relative_vx, drone_vz, sinθ, cosθ, pitchRate | 접지 한계 5개, 정규화 척도 4개 |

3. **(C) 체크포인트의 R-GAT 간선 20개.** `encoderSpec.T`에서 읽는다(의미 13 + self 7).
   - `landing2d.trace.graphSchema`는 노드·간선 끝점·관계 유형·연산군이 tosm7 그래프(`tosm7_v1`과 `tosm7_v2`의 위상은 같음)와 다르면 오류로 멈춘다. 관계가 교란된 그래프도 거부한다.
   - 전파(`informsMotion`, `affectsVisibility`, self)는 청록 실선 펄스로, `+` 표시를 붙인다.
   - 조절(`qualifiesEstimate`, `conditionsLanding`)은 보라 파선 ◇ 펄스로 그리고, 도착 노드에 게이트 파문을 그린다.
   - 이어서 7개 노드 임베딩 전체 → 리드아웃 → 액터 MLP → 가속도 명령을 금색으로 그린다. 행동이 LandingCondition 하나만 거쳐 나오지 않는다.

## R-GAT 수치

$H=(1+\tanh Z_{mod})\odot\tanh(Z_{prop}+W_0X+b_0)$

- 어텐션 점수 $e_{ij}$(softmax 입력)와 어텐션 계수 $\alpha_{ij}$를 구분한다.
- $\alpha$는 연산군 풀(전파+자기 루프 / 조절)별로 도착 노드마다 합이 1이다. softmax 분모 하한이 $10^{-9}$이라 오차가 $10^{-9}$ 이하로 남는다.
- 조절 게이트 $1+\tanh Z_{mod}$는 $\alpha$가 아니다. 조절 간선이 없는 노드에서는 정확히 1이다.
- 표시값은 모두 캐시 값이다. 다시 계산한 $Z_{prop}$, $Z_{mod}$는 캐시의 $\tanh$ 값과 $10^{-12}$ 이내로 같다(A05).
- 리드아웃 사전활성 항 크기 $\lVert(W_cH_k)\odot W_n(:,k)\rVert$는 덧셈 분해의 크기다. 행동 기여도가 아니다. 센서별 기여 백분율은 계산하지 않는다.

S4 결정 #32($t=3.10$ s, 외부 주입 누락 첫 프레임) 예:

- **원천·KF**: 마커 0개, PnP 미수행, KF 시간 갱신(마지막 측정 3.00 s).
- **LandingCondition 조절 풀**: RP 0.170, RV 0.191, DM 0.312, VM 0.149, VQ 0.179. 게이트 평균 1.020 [0.807, 1.295].
- **RelativePosition 전파 풀**: RV 0.345, DM 0.370, self 0.285.
- **조절 게이트 공유**: PadVelocity·RelativePosition·RelativeVelocity는 조절 입력이 VisionQuality 하나뿐이다(α = 1). `operator_shared_v1`에서는 사영도 공유하므로 세 노드의 게이트가 같다.
- **행동**: 요구 가속도 $[-0.117, +0.515]$ m/s².

## 화면 구성

| 영역 | 내용 |
|---|---|
| 위 | 모드(LIVE / REPLAY / TEST ONLY), 체크포인트 상태, 사례·시드·그래프 해시 |
| 도구 막대 | 결정 단위 이전/다음, 재생/일시정지, 시각 이동, 속도 0.25x–4x, 설명용 단계 재생, 실시간 따라가기, 간선 굵기(균일 / α / $\lvert\alpha Wx\rvert$), 관계 필터, 자기 루프 표시, PNG / MP4 |
| 왼쪽 | 원천별 사건 줄(데이터 시각), 상태 카드(마지막 시각, Δt, 2 s 창 관측 주기, 유효, 경과, 최신 값). 외부 주입 누락 구간은 `[평가 전용]` 띠로만 보인다 |
| 가운데 | (A)(B)(C) 세 층, 노드별 5채널 특징 띠(Explicit 파랑 / Implicit 주황). 예측 기반 노드는 파선 테두리와 경과시간으로 표시한다. 이번 결정에 일어나지 않은 계산(미검출, PnP 미수행, 측정 갱신 없음)은 회색 점선으로 그린다 |
| 오른쪽 | 액터: 간선별 α(풀 색), $X_t$ 6×7, $H_t$ 16×7, 조절 게이트 16×7, $g_t^A$, μ / tanh / 요구 / 적용 / [평가] 실제 가속도. 크리틱 탭: $g_t^V$, $V$. 크리틱은 행동 선택에 쓰이지 않는다 |
| 아래 | 결정마다 갱신되는 상황 설명, 클릭한 요소의 근거 사슬, 상류(Back) / 하류(Forward) / 전체 근거 사슬(Expand All) / LandingCondition 사슬 |

- 재생 속도가 기록 시각 기준이면, 같은 결정의 계산을 모두 동시에 표시한다. 이때 R-GAT 간선 메시지는 단일 층의 동시 집계로 나타난다.
- 설명용 단계 재생은 한 결정 시각의 계산을 8단계로 펼친다(단계당 0.35 s). 화면에 "같은 결정 시각, 물리 지연 아님"이라고 표시한다.
- live 모드에서는 콜백이 에피소드를 화면 시계(시뮬레이션 시각 / 속도)에 맞춰 진행시킨다. 화면을 일시정지해도 에피소드는 계속 진행된다.
- 그림 갱신은 `drawnow limitrate`로 줄인다. 사건 기록은 줄이지 않는다(A11).
- 요소를 클릭하면 구조적 도달 집합을 강조하고 나머지는 흐리게 한다. 마우스를 올리면 노드·간선 수치를 보여 준다.
  - 원천·채널: 하류 전체
  - 노드: 특징의 출처, 들어오는·나가는 간선, 임베딩
  - 간선: 출발 노드의 출처와 도착 노드 임베딩
- 단일 층이므로 노드 임베딩에서 간선으로 가는 경로는 없다. 다중 홉 추론처럼 그리지 않는다. 예를 들어 LandingCondition 사슬에는 들어오는 `conditionsLanding` 5개와 self만 들어간다.

## 상황 설명 규칙 (`landing2d.trace.explainDecision`)

- 기록된 관측·추정·노드 특징·공개 한계값·관계 메타데이터·R-GAT 수치·행동만으로 결정론적으로 만든다. R-GAT가 생성한 문장이나 OWL/SWRL 추론이 아니다.
- 한정어로 출처를 구분한다: `[관측]`, `[추정]`, `[예측]`, `[착륙 조건]`, `[관계]`, `[R-GAT 계산]`, `[행동]`, `[해석 주의]`, `[주의]`, `[평가 전용]`.
- 값이 없으면 지어내지 않고 `알 수 없음 (UNKNOWN)`이라고 쓴다.
- KF 시간 갱신일 때는 UGV 값을 "새 직접 측정이 아닌 예측값"이라고 쓴다. 시뮬레이션 참값에만 있는 UGV 가속을 감지했다고 쓰지 않는다.
- `tosm7_v2`에는 normalizedCrossTrack이 없다. RelativePosition은 정규화 수평 위치와 고도만 받는다고 적는다.
- ViewMargin은 추정값 기반 예측이다. 같은 시각의 실제 검출 여부와 따로 적는다.
- LandingCondition은 현재 추정 상태의 한계비 $r/(1+r)$일 뿐이다(0.5 = 한계값). 착륙 승인·안전 보장·미래 접촉 예측·PPO 행동이 아니다(A08).

## 출력 (`results/trace/`)

| 파일 | 내용 |
|---|---|
| `<사례>_onto_rgat_ppo_sNN_rNN.mat` | `decisionTrace`(숫자 기록·사건 표·스키마·출처·식별)와 `annotations`(렌더링한 설명)를 분리 저장 |
| `*_events.csv` | 사건 한 줄씩 (`InjectedDropout_evalOnly` 열은 평가 전용) |
| `*_decisions.csv` | 결정별 $o_t$, PnP/KF 상태, 20개 간선 α, μ, 요구·적용 가속도, 보상 |
| `*_session.json` | 식별, 스키마, 출처, 관측 주기, 결정별 설명 사실 |
| `*_provenance.md` | 체크포인트·학습 서명·그래프 해시, 소스 커밋, 명령, 간선·출처·주기 표 |
| `*.png`, `*_replay.png` | 고정 규칙으로 고른 화면: 첫 외부 주입 누락 결정(S2·S4) 또는 중간 결정(S1·S3), LandingCondition 사슬 선택 |

## 검증 (`run_check('trace')`, 2026-10-19 실행, 학습 시드 11)

| 시험 | 결과 |
|---|---|
| A01 원천 주기 | 카메라 10.00 Hz, 항법 10.03 Hz(종료 추정 포함), 측정 갱신 사건 = `filter.updated` = PnP 채택 |
| A02 누락 | 8개 누락 결정 3.1–3.8 s: 프레임 있음, 측정 경로 펄스 없음, KF 시간 갱신, visionAge 증가 |
| A03 출처 | 파생 연결 21개, 고정 상수 14쌍이 위 표와 같음. 169개 결정 모두에서 $X$ = `observationVectorGraph(o_t)` |
| A04 스키마 | N=7, 의미 13 + self 7, R=5. 관계 교환·노드 이름 변경·교란 그래프는 오류 |
| A05 연산자 | 풀별 α 합 오차 ≤ 1.0e-9, softmax(점수) = α, 게이트·임베딩 재구성 ≤ 1e-12, 화면 값 = 기록 값 |
| A06 정직한 애니메이션 | 범례 네 층, 단계 재생 표시, 임베딩 → 간선 경로 없음 |
| A07 전체 사슬 | 카메라·VisionQuality·간선·LandingCondition·행동 선택 모두 원천 → 간선 → 리드아웃 → 명령. 미지 값은 UNKNOWN |
| A08 안전 주장 없음 | 169개 결정에 승인·보장 문구 없음. 한계값에서 특징 = 0.5 |
| A09 비간섭 | 비트 단위 일치(위 계약) |
| A10 체크포인트 | 서명·그래프 해시 검증, 다른 서명·없는 파일 거부, mock은 TEST ONLY |
| A11 성능 | 1662개 사건 손실 없음. 결정 공급 약 40 ms, 결정 렌더 약 13 ms |
| A12 재생·내보내기 | S1·S4 다시 불러오기가 동일하고 설명이 재현됨. live와 재생 화면이 같음. CSV / JSON / PNG 생성 |
| A13 용어 | 라벨 17쌍. KF 문구가 결정별 갱신 종류와 맞음. INCSL `glossary.tsv` canonical_ko 15개 일치(경로를 줄 때만 확인) |

## 사양과 다르게 한 점

- 루트 진입점 `run_live_tosm_trace.m`은 만들지 않았다. `AGENTS.md`가 루트에 다른 MATLAB 파일을 두는 것을 금지하므로 `run_scenario` 옵션과 `run_check('trace')`로 대신했다.
- 시험은 `tests/` 대신 `landing2d.trace.selfTest`에 두었다. 14개 계약 self-test는 그대로이고 이 시험은 별도다.
- 시험 이름은 사양의 A01–A13을 따른다.
- `TraceCollector`·`SituationExplanationBuilder` 클래스 대신 기존 패키지 방식의 함수로 나눴다(`recordEpisode`, `explainDecision`, `selectionChain`). 화면만 handle 클래스다.
- 사건 종류에 `kf_uninitialized`를 추가했다. 추정이 없을 때 시간 갱신으로 부르지 않기 위해서다.

## 알려진 한계

- S1·S4(시드 11, 반복 1)에서는 PnP 기각(`pnp_rejected`)이 한 번도 일어나지 않았다. 그래서 이 경로는 실제 데이터로 보이지 않았다.
- 시뮬레이션 항법은 항상 유효하고 결정 시각에 갱신된다. 항법 무효 화면은 실제 데이터로 확인하지 못했다.
- 마우스를 올렸을 때의 설명은 `uiaxes.CurrentPoint`에 의존한다. headless 시험은 클릭 대신 `select`를 직접 호출하므로, 실제 마우스 동작은 시험하지 않았다.
- live 공급은 결정마다 사건 표를 다시 만든다(약 40 ms). 4x에서는 공급 시간이 결정 간격(25 ms)보다 길어 에피소드 진행이 화면보다 느려진다. 이때도 기록은 손실되지 않는다.
- MP4 내보내기는 `getframe`이 느려 결정당 약 0.5 s가 걸린다.
