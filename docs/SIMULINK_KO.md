# Simulink 실행·학습

## 요약

- 목적: `planar_visibility_v2` 폐루프 전체를 Simulink 블록으로 실행하고, RL Toolbox `RL Agent` 블록 + `rlPPOAgent`로 학습
- 범위: 드론 동역학·UGV 패드 궤적·카메라 투영·측정 잡음·dropout·패드 추정기·결정 문맥·안전 감독기·종료 판정·보상·관측 생성
- 계약: 환경 블록은 기존 `landing2d` 환경 함수를 그대로 호출, 공통 reward·environment·action·termination 변경 없음
- 등가성: 같은 seed·같은 명령에서 MATLAB `environment.step`과 보상·관측 비트 동일 (§7)
- 실행: `run(struct('trainingBackend','simulink'))`, 결과 위치 `results/simulink`
- 비교군: baseline·semantic-flat·R-GAT 세 모델 모두 같은 모델 구조, 정책 상태 차원만 상이 (26 / 108)

## 1. 모델 구조

- 핵심: 결정 주기 $\Delta t_p=0.10$ s의 정책 루프와 물리 주기 $\Delta t_s=0.01$ s의 환경 루프

```
RL Agent ──u──► Action interface ──aNorm, aRequest, decisionIndex, aNormPrevious──►
  ▲              tanh · 가속도 한계 · 결정 계수기 · 직전 행동 지연(0.1 s)
  │
  └── observation, reward, isdone ◄── UGV landing environment ──► Stop on isdone
          ├ Episode memory                확정 상태 메모리 (0.01 s, 직접 통과 없음)
          ├ Mission logic                 결정 경계·packet·접촉 판정·문맥·종료 판정·확정
          ├ Vehicle (supervisor + dynamics)
          ├ UGV pad
          ├ Perception (camera noise + tracker)
          ├ Decision interface (policy rate) 관측·보상·종료 (0.1 s)
          └ Scopes · Episode outcome log (To Workspace)
```

| 블록 | 호출 함수 | 주기 | 역할 |
|---|---|---|---|
| Episode state | `environment.reset` 초기값 | 0.01 s | 직전 물리 스텝 확정 상태 보관 |
| Decision latch | — | 0.01 s | 결정 시작 처리, $dt=\min(\Delta t_s,\Delta t_p-\text{경과},T_d-t)$ |
| Packet builder | `sensing.buildPacket` | 0.01 s | 감독기 입력 packet |
| Safety supervisor | `control.safetySupervisor` | 0.01 s | 하강 차단·제동·복구 backup |
| Drone dynamics | `dynamics.stepPlanar` | 0.01 s | pitch 2차·추력 1차 지연·병진 적분, pitch 외란 |
| UGV trajectory | `scenario.evaluateTrajectory` | 0.01 s | CV–CA–CV 패드 궤적 |
| Contact check | `environment.evaluateTermination` | 0.01 s | 측정 전 접촉·범위·중단·시간 초과 판정 |
| Camera sensor | `sensing.generateMeasurement` | 0.01 s | 투영·시야각·dropout·측정 잡음 |
| Pad tracker | `sensing.updatePadTrack` | 0.01 s | 인과 등가속도 추정 |
| Decision context | `environment.updateDecisionContext` | 0.01 s | 하강 금지·중단 요청 |
| Termination check | `environment.evaluateTermination` | 0.01 s | 측정 갱신 후 종료 판정 |
| Commit | `scenario.evaluateTrajectory` | 0.01 s | 접촉 시점 보간·시각 진행·종료 사유 기록 |
| Decision output | `buildPacket`·`normalizePacket`/`contextGraph`·`rl.computeReward` | 0.10 s | 정책 상태·보상·종료·에피소드 결과 |

- 블록 구현: MATLAB System 블록(해석 실행), 클래스 `landing2d.simulink.*Block`
- 한 물리 스텝의 순서: `environment.step` 루프 본문과 동일 (감독기 → 동역학 → 패드 → 접촉 판정 → 측정 → 추정 → 문맥 → 종료 판정 → 확정)
- 접촉 스텝: 측정·추정·문맥 갱신 생략, 센서 난수 미소비
- 종료 이후: 다음 결정 경계까지 상태 고정, 경계에서 종료 보상·`isdone=1`
- 모델 파일: `landing2d.simulink.buildModel`이 매번 생성, `results/.../models/landing2d_<mode>.slx`

## 2. 신호와 에피소드 준비

- 핵심: 블록 사이 신호는 고정 길이 double 열벡터, 형식 정의는 `landing2d.simulink.signalCodec` 한 곳

| 신호 | 길이 | 내용 |
|---|---:|---|
| drone | 7 | $x,z,v_x,v_z,\theta,\omega,F$ |
| pad | 5 | $x_p,z_p,v_p,a_p$, 구간 번호 |
| measurement | 15 | 검출·유효·bearing 유효·$\tilde e_x$·$\tilde\beta$·신뢰도·투영 8개 |
| track | 16 | 추정기 상태 전체 |
| status | 20 | 종료·하강 금지·중단·직전 행동·감독기 시간·접촉 직전 값 |
| event | 13 | 종료 사건·시각·보간 비율·접촉 직전 값 |
| clock | 5 | 시각·결정 경과·결정 번호·직전 결정 행동 |
| snapshot | 12 | 결정 시작 시점 drone·pad (보상 계산 전용) |

- 에피소드 준비: `rlSimulinkEnv.ResetFcn` → `landing2d.simulink.prepareEpisode` → `environment.reset` → 블록 `resetImpl`이 초기값 수신
- 센서 잡음: reset이 만든 `threefry` 난수 흐름을 카메라 블록이 이어 사용, MATLAB 환경과 같은 표본 순서
- 실제 상태 사용 범위: 동역학·접촉 판정·보상(snapshot) 한정, 정책 입력은 packet 기반 상태만

## 3. 정책 망

- 핵심: `landing2d.rl.agentInit` 구조의 RL Toolbox 표현, 구조체 정책과 양방향 변환

| 구성 | RL Toolbox 층 |
|---|---|
| $f_\pi$, $f_V$ (48×2 tanh MLP) | `fullyConnectedLayer`·`tanhLayer` |
| $\sigma_\pi=\exp(\max(\log\sigma,\log\sigma_{\min}))$ | `landing2d.rlsim.StateIndependentStdLayer` |
| R-GAT 1층 + 그룹 readout → $c_t$ | `landing2d.rlsim.RelationalContextLayer` |
| $W_\pi c_t$, $w_V^\top c_t$ | `fullyConnectedLayer` (bias 0 고정) |
| 하강 gate $g_t$ | `landing2d.rlsim.DescentGateLayer` |

- 변환: `landing2d.rlsim.toolboxAgent` (구조체 → `rlPPOAgent`), `landing2d.rlsim.structAgent` (역방향)
- 수치: RL Toolbox 기본층 single 계산, 변환 후 Actor 평균 차이 $\le 2\times10^{-7}$
- 평가: 학습 후 구조체 정책으로 되돌려 기존 `evaluateV2`·논문 그림 경로 그대로 사용

## 4. 학습 절차

- 핵심: `landing2d.rl.trainAgent`의 초기화·사전학습·정적 부호기 고정 검사 공유, PPO 수집·갱신만 Simulink·RL Toolbox 담당
- 학습 함수: `landing2d.rlsim.ppoTrain` (입출력 계약 `landing2d.rl.ppoTrain`과 동일)

| 항목 | Simulink 학습 |
|---|---|
| 에피소드 분포 | `TrainingEpisodeSource`: 반복당 6개, 커리큘럼 난이도·쉬운/중간 재생·하한 일정 |
| 단계 학습 | 학습률 계수: 가치 예열 → raw (raw MLP·$\log\sigma$) → 관계 (attention·readout·관계 head) |
| 정적 변환 | $\rho_r$, $W_0$, $b_0$ 학습률 0 |
| PPO | clip 0.2, GAE $\lambda=0.95$, $\gamma=\exp(-\Delta t_p/\tau)$, epoch 8, mini-batch 256, Adam, 전역 노름 자르기 1, L2 0, advantage 정규화 |
| 갱신 주기 | 반복당 에피소드 6개 분량의 결정 수, 직전 구간 평균 길이로 조정 |
| 평가·선택 | 25회마다 검증 분할, $\ell=1$ 이후 후보, 관계 단계 여유 5.0 |
| 관계 경로 | 비활성 시 Simulink 관계 전용 PPO 25회 + 기존 검증 가드 |
| 종료 통계 | `episodeOutcome` (To Workspace) → 클라이언트 커리큘럼 승급 |

- MATLAB 학습과의 차이: PPO 구현(RL Toolbox), 망 정밀도(single), 난수 흐름, 갱신 주기(결정 수 기준)
- 동일 항목: 환경·보상·행동·종료·감독기, 망 구조·초기값, 커리큘럼 규칙, 검증 기반 선택, 시험 분할 미사용

## 5. 병렬 실행

- 핵심: `rl.parallelEpisodes` 참이면 병렬 풀 워커가 에피소드 분담, 기본 비동기(`async`)
- 워커 수: $\min(\text{코어 수},\text{반복당 에피소드 6})$
- 에피소드 준비: 각 워커의 ResetFcn이 구간 seed + 워커 번호 부분 흐름으로 seed 추출
- 실패 대응: 구간 실패 시 풀 재시작 후 1회 재시도, 재실패 시 직렬 전환
- 실행 설정: `c.simulink.parallelMode` (`'sync'`/`'async'`), 학습 서명 제외 항목

## 6. 실행 방법

```matlab
run(struct('trainingBackend','simulink'))                       % 전체 학습·평가
run(struct('executionMode','smoke','trainingBackend','simulink', ...
    'runSelfTest',false,'generatePaper',false,'figureVisible',false, ...
    'saveResults',false,'showLiveDashboard',false))              % 통합 점검
report = landing2d.simulink.verifyEquivalence()                 % 등가성 검증
run_scenario('S3',struct('backend','simulink'))                 % 대표 시나리오, 모델·Scope 표시
model = landing2d.simulink.buildModel(armConfig)                % 모델만 생성
```

- `run_scenario` Simulink 실행: `results/simulink` 체크포인트 우선, 없으면 `results`, `checkpointDir`로 지정 가능
- 2026-10-06 S3 확인 (`results` 체크포인트): baseline SAFE_ABORT, semantic-flat SUCCESS, R-GAT SUCCESS, MATLAB `run_scenario('S3')`와 종료 사유 동일

- 체크포인트: `results/simulink/ppo_<mode>_planar_visibility_v2.mat` (기존 MATLAB 결과와 분리)
- 논문 평가: `results/simulink/paper`
- 소스 경로: `run.m`이 추가하는 세 소스 루트, 직접 호출 시 동일 경로 추가 필요

## 7. 검증 결과

- 핵심: 2026-10-06, `landing2d.simulink.verifyEquivalence(struct('seedCount',3))`, 학습된 세 checkpoint, 검증 seed 2001–2003

| 비교군 | seed | MATLAB 종료 | 결정 수 | 재생 보상·관측 최대 차이 | 폐루프 종료 | 폐루프 보상 최대 차이 |
|---|---:|---|---:|---|---|---:|
| baseline | 2001 | SUCCESS | 148 | 0 / 0 | SUCCESS | $2.4\times10^{-6}$ |
| baseline | 2002 | SUCCESS | 125 | 0 / 0 | SUCCESS | $1.9\times10^{-6}$ |
| baseline | 2003 | SUCCESS | 241 | 0 / 0 | SUCCESS | $3.1\times10^{-6}$ |
| semantic-flat | 2001 | SUCCESS | 189 | 0 / 0 | SUCCESS | $1.4\times10^{-5}$ |
| semantic-flat | 2002 | UNAUTHORIZED_CONTACT | 184 | 0 / 0 | UNAUTHORIZED_CONTACT | $7.8\times10^{-6}$ |
| semantic-flat | 2003 | SUCCESS | 185 | 0 / 0 | SUCCESS | $1.7\times10^{-5}$ |
| R-GAT | 2001 | UNAUTHORIZED_CONTACT | 140 | 0 / 0 | UNAUTHORIZED_CONTACT | $1.1\times10^{-5}$ |
| R-GAT | 2002 | SUCCESS | 207 | 0 / 0 | SUCCESS | $9.0\times10^{-5}$ |
| R-GAT | 2003 | SUCCESS | 136 | 0 / 0 | SUCCESS | $5.4\times10^{-6}$ |

- 재생: MATLAB 결정론 rollout 명령을 Action player 모델에서 재생, 9/9 비트 동일
- 폐루프: 같은 정책의 `rlPPOAgent`가 RL Agent 블록에서 운전, 9/9 종료 사유·결정 수 동일, 보상 차이는 single 계산 오차

## 8. 실행 시간

- 측정 조건: 학습된 R-GAT 정책, 공칭 난이도, 25회 반복(150 에피소드) 1구간, 워커 6개

| 구성 | 1구간 학습 시간 | 반복당 |
|---|---:|---:|
| R-GAT, 동기 병렬 | 183 s | 7.3 s |
| semantic-flat, 동기 병렬 | 175 s | 7.0 s |
| R-GAT, 비동기 병렬 (기본) | 141 s | 5.6 s |

- 직렬 결정당 시간: MATLAB 2.7 ms, Simulink 11.8 ms (해석 실행 블록 호출 비용)
- 2500회 학습 추정: 위 반복당 5.6 s 기준 비교군당 약 4시간, 커리큘럼 초기의 짧은 에피소드 구간은 더 짧음 (전체 학습 미실행 추정치)
- MATLAB 학습 기록(README): 비교군당 1.14–1.91 h

## 9. 한계

- 해석 실행 블록: 코드 생성·Rapid Accelerator 미지원, 물리 스텝당 블록 호출 비용
- 병렬 비동기 수집: 수집 정책과 갱신 정책 사이 지연 가능, PPO 비율 보정에 의존
- 병렬 커리큘럼: 반복 번호를 워커 수로 근사, 직렬에서는 MATLAB 학습과 같은 일정
- 결과 비교: Simulink 학습 결과는 MATLAB 학습 결과와 다른 난수·PPO 구현의 별도 학습
