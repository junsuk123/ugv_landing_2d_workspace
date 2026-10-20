# 변수 명명 감사 (INCSL 용어 DB 기준, 2026-10-19)

이 문서는 MATLAB 식별자를 연구실 용어 DB(`INCSL_용어DB` v1.0, 개념 4,034개 · 비권장 표기 2,776개)에 맞춰 점검하고 고친 기록이다. **이름만 바꿨고 수치·알고리즘·실험 계약은 바꾸지 않았다.** 바뀐 수치가 없음을 비트 단위로 확인했다(§6).

- 기준 커밋: `59af798` (`main`). 작업 브랜치: `naming-incsl-terms`
- 대상: 추적 중인 MATLAB 파일 170개 전부. 디스크에는 174개가 있는데, 나머지 4개는 gitignore된 `results/optimization/`의 미추적 스크립트라 수정하지 않았다
- 결과: 34개 파일, 약 155개 식별자 변경(P0 145 · P1 7 · P2 3). 같은 날 2차 결정(§8)에서 스키마 라벨 6개와 evidence 필드 1개를 더 바꾸고 문서 서술 2곳을 바로잡았다. 보류 12건(§4). 실행되지 않던 보조 코드 37개 파일은 삭제했다(§9)

## 1. 기준과 방법

**용어 결정.** 식별자마다 실제 계산을 먼저 확인했다. 그다음 `lookup.json`과 `terms.jsonl`에서 개념을 찾아 `canonical_en`을 camelCase로 옮겼다. `avoid_list.jsonl`은 `scope`에 맞는 경우에만 적용했다(contextual 항목은 해당 개념일 때만). DB에 개념이 없으면 "공학 권고"로 표시했다.

**우선순위.**
- P0: 지역 변수·인자·지역 함수. 범위 안에서 모든 참조를 고쳤다.
- P1: 저장되지 않는 내부 공유 필드(예: R-GAT 순전파→역전파 cache). 저장소 전체 참조를 함께 고쳤다.
- P2: 체크포인트·CSV·`results.mat`·스키마 버전에 남는 이름, 학습 서명·그래프 해시에 들어가는 이름. 하위 호환을 검증할 수 있는 3건만 바꾸고 나머지는 보류했다.

**바꾸지 않은 것.**
- 문서에 정의된 수학 기호: $\Gamma$=`G`, $o_t$ 구조체 `O`, $X_t$=`X`, 노드 상태 `H`, `A`/`M` 게이트, $W_r$·$a_r$·$E_r$=`W`·`a`·`E`, `Z`, $\alpha$=`alpha`, $g_t$=`g`, $\mu$·$\sigma$=`mu`·`sigma`, TD 오차 `delta`, KF의 `F`·`Q`·`C`·`P`·`y`·`A`, PnP의 `R`·`t`·`K`·`J`, 미터 단위 `ex`·`h`, $m$=`aimSlope`(보상·평가와 같은 이름)
- 루프 지표 `i`/`j`/`k`, 설정 구조체 `c`/`cfg`/`rl`/`gs`
- 계약 파일: `+rl/computeReward.m`, `+environment/step.m`·`reset.m`·`evaluateTermination.m`·`updateDecisionContext.m`·`perceptionView.m`, `+dynamics/*`. AGENTS.md의 "공통 reward·environment·action·termination 변경 금지"를 보수적으로 지켜 열지 않았다(§4).
- 설정 필드 전체: `c.rl`·`c.experiment`·`c.graphState`는 학습 서명에 들어가므로 이름을 바꾸면 모든 체크포인트가 무효가 된다.
- 실행되지 않는 보조 코드(`+consistency`·`+livetest`·`+unlink`·`.codex-build`): 이름 변경 대상에서 뺐다(§7 E2). R-GAT cache 필드 참조 한 줄만 일관성을 위해 고쳤고, 이후 이 코드는 모두 삭제했다(§9).

## 2. 핵심 발견

| # | 발견 | DB 근거 | 조치 |
|---|---|---|---|
| F1 | 행동 표현 세 가지가 섞여 있었다. `u`·`traj.command`는 tanh 이전 가우시안 표본(무차원, 범위 없음), `aNorm`은 tanh 이후 [-1,1], `requestedAcceleration`은 물리 가속도 [m/s²]다. 또 `docs/NOTATION_KO.md`는 $u_t\in[-1,1]^2$를 정규화 행동으로 정의하는데 코드의 `u`는 tanh 이전 값이었다. | T15-0040(행동 ≠ 스케일된 제어 입력), T15-0193(가우시안 정책 μ, σ), T07-0059(가속도 명령) | 지역 변수: `preTanhAction`·`normalizedAction`·`requestedAcceleration`. `traj.command`는 스키마라 보류(§4 D1) |
| F2 | 정책 입력(`S`, `state`, `X`)이 환경 상태로 읽혔다. 같은 파일 안에서 `state`가 물리 상태, Adam 상태(`policyState`), 정책 입력을 모두 뜻했다. `ppoTrain`의 `X`는 일반 PPO에서 12차원 $o_t$인데, NOTATION의 $X_t$는 노드 특징이다. | T15-0035(관측) vs T15-0129(상태), T15-0083·T15-0025(옵티마이저) | `policyInput`, `policyOptimizerState` 등 |
| F3 | `relationForward`의 입력 이름이 `H`였다. 그러나 `encoderForward`와 문서에서 `H`는 출력 노드 상태이고, 입력은 노드 특징 $X_t$다. | T16-0022(노드 특징=입력) vs T15-0113(노드 임베딩=출력) | 입력 `X`, 역전파 출력 `dX` |
| F4 | attention 단계 이름이 불분명했다. `raw`는 leaky ReLU 이전, `score`는 이후(softmax 입력), `alpha`는 softmax 정규화 계수다. | T15-0250(로짓=softmax 입력), T15-0326(어텐션 계수=softmax 정규화, '어텐션 점수'는 정규화 전) | `attentionPreActivation` → `attentionScore` → `alpha`. 사양서 제안 `attentionLogits`는 DB 정의와 맞지 않아 쓰지 않았다 |
| F5 | **N3 `crossTrack` 특징은 미터 단위 aim error $e_x-mh$가 아니다.** (2026-10-20 v2.3 `tosm7_v2`에서 특징 자체를 제거했다.) 정규화된 $o_t$ 성분의 결합 $s_x(e_x)-m\,s_h(h)$이고, 축마다 척도(3 m, 8 m)가 달라 광축 기준점에서도 0이 아니다. 예: $h=6$ m, $e_x=mh=3.46$ m에서 $0.536-0.577\times0.429=0.288$. | T19-0164(횡방향 오차) | 지역 변수 `normalizedCrossTrack`과 주석. 2차 결정(§8)에서 스키마 라벨·evidence 필드도 바꾸고 EXPERIMENT_DESIGN의 서술을 바로잡았다 |
| F6 | MATLAB 내장 함수를 가리는 변수가 있었다: `norm`·`get`(observationVectorGraph), `det`(detectMarkers), `gamma`(computeAdvantage), `log`(rolloutEpisodeV2), `text`(plotTrajectories). | 공학 권고 | 모두 이름 변경 |
| F7 | `captureRate`는 결정마다 마커 측정 갱신(`visionUpdated`)이 있었던 비율이다. 카메라 촬영률이 아니다. | T03-0001(측정 갱신) | 지역 변수 `markerUpdateRate`, `markerUpdateCount`. 저장 필드는 보류(§4 D2) |
| F8 | `schema.riskNodes`는 LandingCondition 노드를 가리킨다. 이 노드는 위험 예측도 guard도 아니다(AGENTS.md 계약). | 공학 권고 | `landingConditionNodes`로 변경. 읽는 코드가 없음을 확인했다(§6) |
| F9 | KF·PnP 한글 주석이 포즈를 "자세"로, 측정치를 "관측"으로 썼다. | T04-0031(포즈≠자세 T01-0058), T03-0032(측정치≠관측 T15-0035) | 주석을 "포즈", "측정치", "측정 갱신"으로 수정 |
| F10 | 저장소의 "dropout"은 마커 검출 누락이다. DB의 dropout(T15-0072)은 신경망 정칙화 기법이다. | T15-0072 | 식별자는 유지. sensorEvents가 외생 manifest 해시에 들어가고 설정 필드명이기 때문이다. 문서 표기 권고만 남긴다(§4 D13) |
| F11 | "Norm" 접미사가 정규화(`bearingNorm`, `aNorm`)와 노름(크기)으로 둘 다 읽혔다. | T18-0020(정규화), T03-0008 note('Norm'=노름) | `normalizedBearing`, `normalizedAction` |

## 3. 구현한 변경

범위 표기: 지역 = 함수 안 변수·인자, P1 = 저장되지 않는 내부 공유 필드, P2 = 저장되는 메타데이터. 위험도는 모두 "낮음(비트 동일 검증)"이다. 다른 값이면 따로 적었다.

### 3.1 그래프 상태 (`src/algorithms/+landing2d/+graphstate`)

| 파일 | 기존 → 변경 | 의미 · 단위/차원 | DB |
|---|---|---|---|
| observationVectorGraph.m | `v` → `observationVector` | 12차원 공통 관측 $o_t$(정규화), 12×1 | T15-0035 |
| 〃 | 출력 `S` → `policyInput` | 평탄화 노드 특징 $X_t$(:), 42×1 | T15-0035, T16-0022 |
| 〃 | `vs` → `observationSchema`, `evidence` → `semanticEvidence` | $o_t$ 스키마 / 출력 필드명과 일치 | 공학 권고 |
| 〃 | `get` → `observationComponent` | 이름으로 $o_t$ 성분을 읽는 함수 핸들(내장 `get` 가림 제거) | 공학 권고 |
| 〃 | `ex`,`h`,`rvx`,`ugvVx`,`vz`,`rate` → `normalizedRelativeX`,`normalizedHeight`,`normalizedRelativeVx`,`normalizedUgvVx`,`normalizedDroneVz`,`normalizedPitchRate` | 정규화 성분 $x/(\lvert x\rvert+s)\in(-1,1)$. 다른 파일의 같은 이름은 미터 단위였다 | T18-0020 |
| 〃 | `st`,`ct` → `sinTheta`,`cosTheta` | $\sin\hat\theta,\cos\hat\theta$ (드론 pitch 자세) | T01-0058 |
| 〃 | `norm` → `normalizationScales` | Γ 정규화 척도 구조체(내장 `norm` 가림 제거) | T18-0020 |
| 〃 | `exM`,`hM` → `relativeXMeters`,`heightMeters` | 역정규화 값 [m] | — |
| 〃 | `crossTrack` → `normalizedCrossTrack` | 정규화 좌표의 m-기울기 결합(F5) | T19-0164 |
| 〃 | `bearingNorm` → `normalizedBearing` | $\hat\beta/(\theta_{FOV}/2)$, 무차원 | T18-0020 |
| 〃 | `ratio`,`condition` → `touchdownLimitRatio`,`landingCondition` | 접지 한계 비율 $r$ 5×1, $r/(1+r)$ 5×1 | — |
| 〃 (P1) | `semanticEvidence.landingRatio` → `.touchdownLimitRatio` | 일시 구조체. 읽는 코드 없음 | — |
| environmentGraph.m, observationGraph.m | `S` → `policyInput`, `v` → `observationVector` | 위와 같음 | T15-0035 |
| encoderForward.m | 인자 `S` → `policyInput` | [stateDim×B] | T15-0035 |
| encoderBackward.m | 출력 `dS` → `dPolicyInput` | 입력 기울기 | — |
| contextSchema.m (P2) | `schema.riskNodes` → `schema.landingConditionNodes` | LandingCondition 노드 색인(F8) | 공학 권고 |
| 〃 (P2) | `nodeFeatureNames` 라벨 `'geometryEnergy'` → `'geometryQuadratic'` | $\tfrac12(c^2+h^2)$, 정규화 값의 이차식(에너지 아님) | 공학 권고 |
| 〃 (P2) | `nodeFeatureNames` 라벨 `'bearing'` → `'normalizedBearing'` | N6 f2 = $\hat\beta/(\theta_{FOV}/2)$ (원래 라벨은 값과 달랐다) | T18-0020 |

### 3.2 R-GAT (`src/algorithms/+landing2d/+rgat`)

| 파일 | 기존 → 변경 | 의미 · 차원 | DB |
|---|---|---|---|
| relationForward.m | 인자 `H` → `X`, `Hf` → `Xf` | 입력 노드 특징 [din×N×B] / [din×NB] | T16-0022 vs T15-0113 |
| 〃 | `HW`,`HWr`,`HWall` → `projected`,`projectedR`,`projectedAll` | 관계별 사영 $W_rX$ [dout×NB×R] | T18-0092 |
| 〃 | `an`,`bn`,`sc` → `srcAttentionTerm`,`dstAttentionTerm`,`relationAttentionTerm` | attention 출발·도착 항 [R×NB], 관계 임베딩 항 [R×1] | T15-0212 |
| 〃 | `raw` → `attentionPreActivation`, `score` → `attentionScore` | leaky ReLU 이전 / 이후(softmax 입력) [nEdges×B] | T15-0250, T15-0326 |
| 〃 | `relationRaw` → `fixedRelationPreActivation` | fixed_relation_v1의 관계별 고정값 [R×1] | — |
| 〃 | `msgs`,`weighted`,`dstPart` → `edgeMessages`,`weightedMessages`,`dstTerm` | 간선 메시지 [dout×nEdges×B] | T15-0119 |
| 〃 (P1) | cache 필드 `H`,`Hf`,`HW`,`raw`,`msgs`,`relationRaw` → `X`,`Xf`,`projected`,`attentionPreActivation`,`edgeMessages`,`fixedRelationPreActivation` | 순전파→역전파 전달용. 저장되지 않음. `alpha`·`diagnosticEdgeKeep`·`originalAlpha`는 유지 | — |
| relationBackward.m | 출력 `dH` → `dX`, 그리고 `dWeighted`,`dMsgs`,`dHWall`,`dScore`,`dRaw`,`dRelationScore`,`dAall`,`dBall`,`dan`,`dbn`,`HWr`,`dHWr`,`dHf` → 순전파 이름에 맞춘 `d*` | 역전파 중간값 | — |
| 〃 | 주석: 존재하지 않는 `tests/test_rgat_gradients.m` → selfTest relation-attention | 문서 오류 수정 | — |
| +livetest/cutSelfTest.m | `c.msgs` → `c.edgeMessages` | cache 필드 변경을 따라감(실행 불가 코드, §7). 이후 파일 삭제(§9) | — |

### 3.3 강화학습 (`src/algorithms/+landing2d/+rl`)

| 파일 | 기존 → 변경 | 의미 · 단위/차원 | DB |
|---|---|---|---|
| policyAction.m | 출력 `u` → `preTanhAction`, 인자 `S` → `policyInput` | 가우시안 표본(결정론적이면 μ), 2×B, 무차원·무범위 | T15-0193, T15-0040 |
| valueForward.m | `S` → `policyInput` | — | T15-0104 |
| policyLossGradient.m | `X`,`U`,`A` → `policyInput`,`preTanhAction`,`advantage`; `ratio`,`clipped` → `probabilityRatio`,`clippedRatio`; `graph` → `hasGraphEncoder` | PPO 확률비 $r_t(\theta)$, 클리핑된 비 | T15-0325, T18-0296, 공학 권고 |
| valueLossGradient.m | `X`,`R` → `policyInput`,`valueTarget`; `graph` → `hasGraphEncoder` | GAE 가치 목표(advantage + V) | T15-0104, T15-0357 |
| computeAdvantage.m | 출력 `target` → `valueTarget`; `gamma` → `discount`(내장 `gamma` 가림 제거); `running` → `runningAdvantage` | 할인율 γ, GAE 누적 | T15-0357, T15-0064 |
| ppoTrain.m | `score`,`bestScore`,`bestSelection`,`stagnant` → `validationReturn`,`bestValidationReturn`,`bestSelectionScore`,`evaluationsWithoutImprovement` | validation 평균 return과 체크포인트 선택 점수를 구분 | — |
| 〃 | `policyState`,`valueState`,`policyEncoderState`,`valueEncoderState` → `*OptimizerState` (하위 함수 인자 `state`,`encoderState` → `optimizerState`,`encoderOptimizerState`) | Adam 모멘트 | T15-0083, T15-0025 |
| 〃 | 에피소드 cell `state`,`command`,`logProbability`,`advantage`,`target` → `episodePolicyInput`,`episodePreTanhAction`,`episodeLogProbability`,`episodeAdvantage`,`episodeValueTarget`; 배치 `X`,`U`,`A`,`R` → `policyInput`,`preTanhAction`,`advantage`,`valueTarget`; `collectEpisode`·`historyRow` 인자 | PPO 배치 열 | T15-0035, T15-0325 |
| rolloutEpisodeV2.m | `u`,`aNorm` → `preTanhAction`,`normalizedAction`; `state`,`finalState` → `policyInput`,`finalPolicyInput`; 지역 함수 `policyState` → `buildPolicyInput` | F1, F2, F11 | T15-0040, T18-0020 |
| 〃 | `detections` → `markerUpdateCount`; 지역 함수 `visionAvailable` → `visionUpdated` | 마커 측정 갱신 횟수/여부 | T03-0001 |
| 〃 | `log` → `truthLog` (내장 `log` 가림 제거, buildCommandLog 인자명과 일치) | 평가 전용 참값 기록 | — |
| 〃 | 머리말: `traj` 필드 의미 명시(command = tanh 이전 표본 등) | 이름은 스키마 보류(§4 D1) | — |
| evaluateV2.m | 출력 `score` → `meanReturn`; `capture` → `markerUpdateRate`; `finalStates` → `finalPolicyInputs`; `nodeValues` → `firstNodeFeature` | — | T03-0001 |
| profileAgent.m | `state` → `policyInput` | — | T15-0035 |

### 3.4 평가·그림 (`src/orchestration/+landing2d`)

| 파일 | 기존 → 변경 | 의미 · 단위 | DB |
|---|---|---|---|
| +evaluation/trainingDiagnostics.m | `X`,`U`,`L`,`A`,`T` → `policyInput`,`preTanhAction`,`logProbability`,`advantage`,`valueTarget` (`T`는 다른 곳에서 topology); `graph` → `hasGraphEncoder` | 기울기 진단 배치 | T15-0325 |
| +evaluation/episodeMetrics.m | `command` → `requestedAcceleration` | 요청 가속도 [m/s²], 2×n (`traj.command`와 다른 양) | T07-0059 |
| 〃 | `visible` → `visionUpdated`; `geometricVisible` → `padInGeometricView` | 마커 측정 갱신 여부 / 패드 중심이 카메라 FOV·거리 안(참값) | T03-0001, T12-0001, T07-0015 |
| 〃 | `contact` → `contactLimitRatio` (지역 함수 인자 `ratio` 포함) | 접촉 순간 상태 ÷ 접지 한계, 1×5 | — |
| 〃 | `reacquisition`,`rematch`,`recovery` → `reacquisitionLatency`,`speedRematch`,`recoveryTime` | 지표 열 이름과 일치 [s] | T01-0032 |
| 〃 | `window` → `eventWindow`, `s` → `scenario` | [t0,t1] 사건 구간 | — |
| +evaluation/rolloutSet.m | `window` → `eventWindow`; 저장 필드 `command`에 주석 | — | — |
| +evaluation/openLoopProbes.m | `state` → `policyInput`, `quality` → `visionQualityNode` | — | T15-0035 |
| +viz/plotTrajectories.m | 지역 함수 출력 `text` → `label` (내장 `text` 가림 제거) | — | — |

### 3.5 시뮬레이션 (`src/simulations/+landing2d`)

| 파일 | 기존 → 변경 | 의미 · 단위 | DB |
|---|---|---|---|
| +observation/toVector.m | `x` → `observationVector`; `s`,`u`,`d` → `scales`,`ugv`,`drone`; `rvx` → `relativeVx` | `u`가 행동 표기와 겹치던 문제 해소. `ex`,`h`는 미터라 유지 | T15-0035 |
| +observation/updateUgvEstimate.m | `e` → `estimator`, `gain` → `kalmanGain`; 주석 관측→측정치, 보정→측정 갱신 | 칼만 이득 4×2 | T03-0021, T03-0032, T03-0001 |
| +observation/ugvPositionMeasurement.m | `c`,`s` → `cosTheta`,`sinTheta` (`c`는 저장소 전체에서 설정 구조체); 주석 자세→포즈, 관측→측정치 | — | T04-0031, T03-0032 |
| +observation/capture.m, estimatePadPose.m, +config/defaultCommonObservationConfig.m | 주석만 수정: "패드 자세" → "패드 포즈", "위치 관측" → "위치 측정치" (설정값은 그대로라 학습 서명 불변) | — | T04-0031, T03-0032 |
| +sensing/detectMarkers.m | `det` → `detector` (내장 `det` 가림 제거); `c`,`s` → `cosTheta`,`sinTheta` | — | — |
| +sensing/generateMeasurement.m | `m` → `measurement`, `p` → `projection`; `confidence` 주석 | 검출기 점수일 뿐 보정된 신뢰도·공분산이 아님 | T03-0032, T18-0092, T12-0177 |
| +sensing/buildPacket.m | `fakeState`,`fakePad` → `predictedState`,`predictedPad` | 예측 지평 상대 상태 | — |
| +probe/referenceDriver.m | 출력 `aNorm` → `normalizedAction`; `u` → `ugv` | 기준 구동기 행동 [-1,1] | T18-0020 |
| +probe/replaySensing.m | `u` → `ugv` | — | — |

## 4. 보류한 변경 (이름 결정 또는 마이그레이션 필요)

| # | 현재 이름 → 제안 | 이유 | 영향 범위 · 마이그레이션 |
|---|---|---|---|
| D1 | `traj.command` → `preTanhAction`, `traj.actorMean` → `preTanhActionMean`, `traj.state` → `policyInput`, `traj.value` → `stateValueEstimate`, 그리고 commandLog.policy의 같은 필드 | `command_log_v1` 스키마. selfTest probe-replay가 `fieldnames(L.policy)`를 단언한다 | `command_log_v2`로 버전을 올리고 selfTest·ppoTrain·trainingDiagnostics를 함께 고친다. 지금은 머리말 주석으로 의미만 고정했다 |
| D2 | `captureRate`(traj/result/info), `meanCaptureRate`, `history.captureRate` → `markerUpdateRate` | 체크포인트 `info.history`에 저장됨 | 읽기 쪽 별칭을 둔 뒤 새 필드를 쓴다 |
| D3 | `history.score` → `validationReturn` | 체크포인트 저장. CSV 열은 이미 `ValidationReturn`이다 | D2와 같은 방식 |
| D4 | `history.nodeMean` / `info.nodeMean` → `firstNodeFeatureMean` | 노드별 첫 특징의 평균. 저장됨 | D2와 같은 방식 |
| D5 | `result.visible` → `visionUpdated` (`rollout_result_v2`, `results.mat` factorial.display) | 저장 결과·그림 입력 | 결과 스키마 버전 변경 필요 |
| D6 | `results.mat` `factorial.display.*.command` → `requestedAcceleration` | 저장 결과. plotCaseTimeSeries가 읽는다 | 결과 재생성 시 함께 변경 |
| D7 | ~~스키마 라벨 `'crossTrack'`, `semanticEvidence.crossTrack` → `normalizedCrossTrack`~~ | **해결(§8)** | — |
| D8 | `typeId` (값 = node/N) | **유지 결정(§8).** 의미를 주석과 TOSM7 문서에 명시했다 | — |
| D9 | `schema.goalNode`, `T.goalNode` (= LandingCondition, 읽는 코드 없음) | **유지 결정(§8).** 주석으로 레거시 별칭임을 명시했다 | — |
| D10 | ~~LandingCondition 라벨 `positionRatio` 등 → `boundedPositionRatio` 등~~ | **해결(§8)** | — |
| D11 | 노드 이름 `VisionQuality` 등, 관계 이름 | 그래프 해시에 들어가 R-GAT 체크포인트 검증(`verifyCheckpointGraph`)이 실패한다. VisionQuality는 마커 갱신 여부·경과시간일 뿐 보정된 품질이 아니다(문서가 이미 그렇게 명시) | 바꾸지 않음 |
| D12 | 방법 ID, `stateRepresentation` 값, 설정 필드(`bearingNoiseStd`, `confidenceFloor`, `perturbation.*Dropout*` 등) | 학습 서명. 바꾸면 모든 체크포인트가 무효 | 바꾸지 않음 |
| D13 | "dropout" 용어 | F10 | 문서에서는 "마커 검출 누락"으로 쓰기를 권장 |
| D14 | 저장 지표 열: `NoiseActionVar`(= 잡음 재생 간 요청 가속도 $\mathrm{tr\,Cov}$ [(m/s²)²]), `CommandRateRMS_mps3`(= 요청 가속도 변화율 RMS [m/s³]), `MeasuredViewLoss_s`(= 마커 측정 갱신이 없던 시간 [s]) | CSV·문서·논문이 참조한다. 단위와 의미는 이름으로 짐작 가능 | 바꾸지 않음. 의미는 이 표로 고정 |
| D15 | 계약 파일의 `aNorm`·`requested`(step.m), `aNorm`·사용되지 않는 `previousNorm`(computeReward.m), `aRequest`(dynamics) | 계약 파일은 열지 않는다(§1) | 사용자가 결정하면 비트 동일 검증과 함께 적용 |
| D16 | 보조 패키지 지표 `C_valid`, `D_obs_mean/P95`, `D_seed`, `J_policy`, `J_applied` | 현재 파이프라인이 만들지 않는다(실행 불가 코드, §7). 정의는 확인했다: `C_valid` = 맥락별 평균 후 동일 가중 평균한 (기준·교란 모두 유효) 비율 [%]; `D_obs` = 같은 맥락 probe의 [0,1] 정규화 요청 가속도 차이 노름/√2(평균·P95); `D_seed` = 학습 시드 쌍 간 같은 양의 평균; `J_policy`/`J_applied` = 정상 구간 요청/적용 가속도 변화율의 시간 가중 RMS [m/s³] | 패키지를 정리할 때 함께 결정 |

## 5. 유지한 이름의 근거 (요약)

- `alpha`: 문서의 $\alpha_{ij}^{(r)}$이자 여러 진단이 읽는 필드다. T15-0326 어텐션 계수와 같은 뜻이다.
- `innovation` (updatePadTrack): 갱신 전 차이(측정 − 예측)이므로 T03-0012 정의와 맞다. residual로 바꾸지 않았다.
- `pose`, `estimatePadPose`: 회전과 이동을 함께 추정하므로 T04-0031 포즈가 맞다(자세 아님).
- `confidence`, `detectionConfidence`: 시뮬레이션 검출기 점수(T12-0177). 보정된 신뢰도로 해석하지 않는다는 주석을 달았다.
- `aimError`(episodeMetrics 지역 변수): 문서의 $e_{aim}$ 그대로다.

## 6. 검증

모든 실행은 실제 MATLAB R2025b(`-batch`)로 했다. 진행 중이던 시드 확장 평가를 방해하지 않도록 별도 git worktree에서 실행했다.

| 검사 | 변경 전 (59af798) | 변경 후 |
|---|---|---|
| `run_check` self-test | 14/14 PASS | 14/14 PASS |
| `run_check` smoke | 통과 | 통과. 출력된 contrast 수치 줄이 변경 전과 글자 단위로 같음 |
| 수치 회귀 결정성 (변경 전 두 번 실행) | 21,782개 값, 차이 0 | — |
| 수치 회귀 (변경 전 vs 변경 후) | — | 21,780개 값 비교. 차이 8건은 모두 의도한 메타데이터(§3.1 P2 3건을 M2·M3 스키마에서 확인). 그 밖에는 비트 단위로 같음 |
| Code Analyzer (`checkcode`, 34개 파일) | 경고 2(ISMAT) | 같은 2개. 새 경고 없음 |
| 바뀐 필드명 잔존 참조 (`raw`,`msgs`,`HW`,`Hf`,`relationRaw`,`riskNodes`,`landingRatio`,`geometryEnergy`) | — | 저장소 전체(보조 코드, `.codex-build`, `results/optimization` 포함)에서 0건 |

수치 회귀(`naming_regression`)가 비교한 항목은 세 비교군 각각에 대해 다음과 같다.
- 고정 행동열로 진행한 공통 관측과 Γ 기억, 노드 특징 행렬, semantic evidence 값, 구조체 경로와 벡터 경로의 그래프 일치
- 초기 에이전트의 인코더 출력, 노드 상태, typed 게이트, 관계 cache 값(사영·사전 활성·메시지·α), 정책 행동·로그 확률(확률적·결정론적), Critic 값, 인코더 역전파
- 확률적 rollout, GAE, PPO actor·critic 손실 기울기와 통계
- 결정론적 rollout과 command log, episode 지표(구간 있음·없음)
- 3 iteration PPO 학습(학습된 파라미터, history, 선택 결과)과 validation 평가
- 학습 서명, task fingerprint, 그래프 해시, 파라미터 수(6,101)

추가로 기존 체크포인트 3개(`ppo_s01`, `onto_rgat_ppo_s01`, `shuffled_rgat_ppo_s01_g01`)를 로드했다. 학습 서명과 그래프 해시를 검증했고, 평가 6개 절(learning, training, heldout, factorial, generalization, probes)을 smoke 규모로 실행했다.

**체크포인트 호환.** 기존 체크포인트의 저장 스키마에는 여전히 `riskNodes`와 옛 라벨이 남아 있다. 그러나 이 필드를 읽는 코드가 없고 학습 서명·그래프 해시와도 무관해서, 로드·검증·추론 결과가 같다(위 비교에서 차이 0). 새로 학습하는 체크포인트에는 새 이름이 저장된다. `algorithmVersion`은 바꾸지 않았다(수치 변경 없음).

## 7. 별도 보고: 기존 결함 (이번 작업에서 고치지 않음)

- **E1. crossTrack 특징의 의미(F5). → 해결(§8).** EXPERIMENT_DESIGN_KO.md §7의 learnability 가설은 "R-GAT 입력에는 보상의 추종 목표인 aim error(`crossTrack`)가 … 파생 특징으로 들어가지만"이라고 썼다. 실제 특징은 정규화 좌표의 결합이라 aim error와 같지 않고, 기준점에서 0도 아니다.
- **E2. 실행 불가 보조 코드. → 삭제(§9).** `+consistency`(15개 파일), `+livetest`(7개), `+unlink`(8개), `.codex-build/*.m`(2개)는 run·run_check·run_scenario에서 호출되지 않는다. 이들은 존재하지 않는 함수 12개를 호출한다: `landing2d.paper.*` 3개, `probe.buildBank`, `rl.probeActions`, `rl.normalizeAgent`, `util.resolvedConfig`, `viz.graphLayout`, `metrics.{admissibleActions, behaviorValidity, validityContext, trajectorySpatialStatistics}`. 없는 설정 필드(`c.consistency`, `registry.ablations`)도 쓴다. `livetest/infer.m`은 `encoderForward`(현재 4개 인자)를 6개 인자로, `policyAction`을 6개, `valueForward`를 3개 인자로 호출한다. AGENTS.md 소스 구조에도 이 패키지들이 없었다.
- **E3. `.vscode/tasks.json`.** JSON 문법 오류가 있다("Temporary Git status" 객체가 Smoke 작업 중간에 끼어 있음). 또 runPipeline이 거부하는 옛 옵션(`executionMode`, `spatialDimension`, `generatePaper`, `showLiveDashboard`)을 쓴다.
- **E4. 옛 차원 주석.** reset.m(104행), replaySensing.m(11행), selfTest.m checkCommonObservation(445행)이 관측을 "24-D"로 적는다. 현재는 12차원이다.
- **E5. 사용되지 않는 인자.** `computeReward(…,previousNorm)`의 마지막 인자는 쓰이지 않는다(계약 파일이라 손대지 않음).
- **E6. 한글 문서 표기.** COMMON_OBSERVATION_KO.md 등은 `visionUpdated`를 "영상 보정 여부"라고 쓴다. DB 원칙(update → 갱신, T03-0001)에 따르면 "영상 측정 갱신 여부"가 맞다.
- **E7. bearing.** DB의 방위각(T08-0064)은 수평면 각이다. 이 코드의 bearing은 x–z 평면에서 광축으로부터 잰 각이다. 이름은 카메라 관례대로 유지했고, 처음 나올 때 정의를 밝히기를 권한다.

## 8. 2차 결정 (2026-10-19, 사용자 위임)

§4의 라벨 보류 항목과 F5 서술은 사용자가 판단을 위임했다. 다음과 같이 정했다.

| 항목 | 결정 | 근거 |
|---|---|---|
| N3 라벨 `crossTrack`, `semanticEvidence.crossTrack` | `normalizedCrossTrack`으로 변경 | F5. 라벨은 읽는 코드가 없고 evidence는 저장되지 않는 일시 구조체다(selfTest는 `.bearing`, `.landingCondition`만 읽는다) |
| N7 라벨 `positionRatio`, `relativeSpeedRatio`, `descentSpeedRatio`, `pitchRatio`, `pitchRateRatio` | `bounded*`로 변경 | 값은 $r/(1+r)$이지 비율 $r$가 아니다 |
| `typeId` | 유지 | TOSM7 문서·Notion·논문에 쓰이는 이름이고 바꿔도 계산상 이득이 없다. 값 node/N이 노드 식별 코드이며 `nodeClasses`의 클래스 번호가 아니라는 점을 주석과 TOSM7 문서에 적었다 |
| `goalNode` | 유지 | 모든 체크포인트의 topology에 저장되어 있고 읽는 코드가 없다. 레거시 별칭이라는 주석을 달았다 |
| EXPERIMENT_DESIGN_KO.md §5 aim error 문단 | "TOSM crossTrack 특징이 쓰는 기울기와 같다" → 같은 $m$을 쓰지만 정규화 좌표에 적용하므로 $e_{aim}$과 같은 값이 아님 | 사실 정정. 결론에는 영향 없음 |
| EXPERIMENT_DESIGN_KO.md §7 learnability 가설 | 가설로 유지하고 사실과 다른 부분만 정정: 특징은 보상과 같은 기울기의 cross-track이지만 aim error 자체가 아니다($h=6$ m 기준점에서 0.29). 착지 한계 비율은 물리 값으로 계산되므로 그대로 둔다 | "R-GAT가 aim error를 직접 받는다"는 서술은 논문에 쓰지 않는다 |
| aimError.m 주석 | 같은 정정 | — |

검증(실제 MATLAB R2025b): `run_check` 14/14 PASS, smoke 통과(contrast 출력 줄 변경 전과 동일). 변경 전 기준과의 수치 회귀는 21,780개 값을 비교했고 차이 20건은 모두 의도한 메타데이터다(M2·M3 각각 `riskNodes`→`landingConditionNodes`와 `nodeFeatureNames` 셀 {7,13,14,17,21,24,28,35}). semantic evidence 값, 노드 특징, 그래프 해시, 학습 서명을 포함한 그 밖의 값은 비트 단위로 같다.

## 9. 보조 코드 삭제 (2026-10-19, 사용자 결정)

§7 E2에서 실행 불가로 확인한 코드를 삭제했다. 내용은 git 기록(커밋 `7d5b93f`까지)에 남아 있다.

| 경로 | 파일 수 | 실행 불가 근거 |
|---|---:|---|
| `src/orchestration/+landing2d/+consistency` | 15 | 없는 함수(`probe.buildBank`, `rl.probeActions`, `rl.normalizeAgent`, `util.resolvedConfig`, `metrics.*` 3개)와 없는 설정(`c.consistency`, `registry.ablations`) |
| `src/orchestration/+landing2d/+livetest` | 7 | `encoderForward`·`policyAction`·`valueForward`를 현재와 다른 인자 수로 호출, `viz.graphLayout` 없음 |
| `src/orchestration/+landing2d/+unlink` | 8 | `landing2d.paper.*`·`viz.graphLayout` 없음, 위 livetest에 의존 |
| `.codex-build` | 7 | `.m` 2개는 `landing2d.paper.*`·`metrics.trajectorySpatialStatistics` 호출. `build_presentation.ps1`은 없는 `docs/assets/paper/...` 폴더를 읽음. 나머지는 옛 설계의 smoke 출력과 livetest 미리보기 그림 |

- 남은 참조: run·run_check·run_scenario와 남은 소스·문서 어디에도 없다. 추적 중인 MATLAB 파일은 170개에서 138개로 줄었다.
- gitignore된 `results/optimization/`의 미추적 스크립트 4개 중 일부가 `landing2d.consistency`를 호출한다. 저장소 밖 생성물이라 손대지 않았다.
- 메인 코드에 남은 선택 기능: `relationForward`의 `diagnosticEdgeKeep` 인자(메인 파이프라인은 항상 빈 값)와 그 역전파 금지 assert, `evaluateTrajectory`의 `liveAccelerationPulses` 필드(없으면 원래 경로). 둘 다 꺼져 있으면 수치에 영향이 없다. 지우려면 함수 시그니처와 시나리오 파일을 바꿔야 하므로 이번에는 남겼다.
- 검증(실제 MATLAB R2025b): `run_check` 14/14 PASS, smoke 통과(contrast 출력 줄 변경 전과 동일). 삭제 직전 상태와의 수치 회귀는 21,782개 값, 차이 0이다.
