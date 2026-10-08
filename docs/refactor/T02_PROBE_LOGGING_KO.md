# T02: 고정 관측 재생·인과적 센서 오차·요청/적용 명령 로그

## 요약

- 범위: 2차원 평면 계약 한정, 3차원 옵션은 fingerprint·학습 서명·관측·보상·종료·최종 상태 비트 동일 확인
- 센서 잡음: 검출 시에만 뽑던 순차 난수를 시간 기준 표준정규 잡음표로 교체, 같은 시각의 잡음이 정책·검출 이력·조기 종료와 무관
- 관측오차 배율: 같은 표준정규 표본에 배율만 곱함 (`[0, 0.5, 1, 2]`, 명목 1, 기준 0)
- 고정 probe: 비교군과 무관한 인과적 구동기의 실제 환경 궤적 → 측정 단계부터 배율별 재계산 → 정책 입력·문맥·참값 분리 저장
- 명령 로그: tanh 이전 평균, 감독기 이전 요청 명령, 물리 스텝 적용 명령·감독기 사유, 실제 기체 가속도(참값)를 구역별로 분리
- 성능 수치: 없음 (학습 미실행, 미학습 정책은 실행 확인 전용)

## 1. 시간 기준 센서 잡음

| 잡음원 | 잡음표 크기 | 색인 | 난수열 |
|---|---|---|---|
| 마커 코너 | $2\times4\times M\times(K+1)$ | 결정 시점 $k$, 등록 슬롯 | `markerOffset` |
| 융합 측위 (pitch, 기체 $v_x$, $v_z$) | $3\times(K+1)$ | 결정 시점 $k$ | `navigationOffset` |
| 평면 tracker (상대 $x$, bearing) | $2\times J\times(K+1)$ | 결정 시점 $k$, 물리 스텝 $j$ | `trackerOffset` (신규) |

- 생성: `landing2d.sensing.exogenousNoise`, reset에서 1회, $K=\lceil T_{deadline}/\Delta t_{policy}\rceil+1$, $J=\Delta t_{policy}/\Delta t_{physics}+2$
- 사용: `detectMarkers`·`navigationEstimate`·`generateMeasurement`가 숫자 블록을 받으면 해당 시각 값 사용, RandStream이면 기존 순차 추출 (3차원 옵션·Simulink 블록)
- 외생 사건(dropout·pitch 외란): 기존 `sensorOffset` 난수열 유지
- 설정 표식: `experiment.commonObservation.randomStreams.indexing = 'time_indexed_v1'` → 평면 task fingerprint·학습 서명 변경 (T01 smoke 체크포인트 재생성 필요)
- 수치 영향: 분포 동일, 실현값 상이 (아래 4절 harness 비교)

## 2. 관측오차 배율

$$
\epsilon_s = s\,\sigma\,z,\qquad z\sim\mathcal N(0,1)\ \text{(시간 기준 표본)},\qquad \mathrm{Cov}(\epsilon_s)=s^2\,\mathrm{Cov}(\epsilon_1)
$$

- 적용: `landing2d.environment.reset(c,seed,struct('sensorNoiseScale',s))`, 평면 전용 (3차원은 `landing2d:NoiseScale` 오류)
- 대상: 마커 코너 0.5 px, 측위 속도 0.05 m/s·자세 0.5°, 평면 tracker 0.02 m·0.15°의 표준편차
- 불변: UGV 상태추정기 잡음 가정(`estimator`), 검출 조건, dropout·pitch 외란 일정, 시간 상관(백색)
- 짝짓기: 배율이 달라도 같은 $z$ 사용
- 검출 판정: T02 시점에는 코너 잡음이 검출 판정 이후에 더해져 배율이 검출 집합을 바꾸지 않았음 → T03 전 후속 수정으로 잡음이 더해진 관측 코너로 판정 (배율이 경계 근처 검출 여부에도 영향)
- 설정: 최상위 `c.consistency`(`landing2d.config.defaultConsistencyConfig`), 학습 서명·fingerprint 제외 (self-test 확인)

## 3. 외생 manifest

- 함수: `landing2d.environment.exogenousManifest(env)`, reset 직후 전용
- 내용: 난수열 시드·잡음 색인 방식·배율, 초기 물리 상태, UGV 운동 일정(시나리오 파라미터), dropout·pitch 외란 일정, 잡음표 SHA-256
- 해시: 위 내용 JSON의 SHA-256 (Inf·NaN 문자열 보존)
- 성질: 같은 시드·같은 배율이면 비교군과 무관하게 같은 해시, 미래 사건 포함 → 평가 전용
- `resetInfo.provenance` 보강: 시드, 잡음 색인, 배율, tracker·마커·측위 잡음 시드

## 4. 고정 probe

### 4.1 경로

| 단계 | 함수 | 내용 |
|---|---|---|
| 기준 궤적 | `landing2d.probe.recordReference` | 인과적 구동기로 실제 평면 환경 비행 (명목 배율 1), 결정 시각의 물리 참값·카메라 프레임 사건·환경 관측·결정 문맥 기록 |
| 구동기 | `landing2d.probe.referenceDriver` | `causal_tracking_v1`: $o_t$·$\Gamma$·공개 설정만 사용, 광축 정렬 추종·고도 비례 하강·시야 상실 시 상승, 명령 잡음 0.10 (전용 난수열 `consistency.probe.randomOffset`) |
| 측정 재생 | `landing2d.probe.replaySensing` | 같은 상태·같은 프레임 사건에서 배율별 잡음표로 검출·측위 → PnP·KF → $o_t$ → 결정 문맥 재계산 |
| 은행 | `landing2d.probe.buildBank` | validation/test 분할 시드, stride 5 결정마다 probe, 배율별 정책 입력·문맥·참값 저장 |
| 정책 평가 | `landing2d.rl.probeActions` | 결정론적 tanh 이전 평균·요청 명령, 은행 수정 없음 |

- 도달 가능 상태: 실제 환경 동역학·감독기 아래에서 비행한 궤적의 결정 시점
- 정책 비관여: 구동기는 세 비교군과 무관, 평가 정책의 행동은 궤적·이후 관측에 미반영
- 인과적 이력: 에피소드 시작부터 같은 측정 순서로 재계산 → $H_t$·KF 기억·결정 문맥 latch가 정책과 무관하게 동일
- 재귀 정책: 세 비교군 모두 $o_t$만 받는 비재귀 정책, 내부 상태 선언 정책은 `landing2d:RecurrentProbe` 거부
- 재생 일치: 명목 배율 재생 관측·결정 문맥 = 환경 기록 비트 일치, 은행 생성 시 에피소드마다 검사 (불일치 시 `landing2d:ProbeReplay`)
- 그래프 입력: 같은 $o_t$의 `observationGraph` 노드 특징 (관계 배치 무관) → 두 RGAT 비교군 동일 입력, 교란군은 자기 체크포인트 위상으로 순전파

### 4.2 은행 구조 (`fixed_probe_bank_v1`)

| 구역 | 내용 | 정책 입력 여부 |
|---|---|---|
| `policyInput.vector` | 24 × probe × 배율 | 예 |
| `policyInput.graph` | 108 × probe × 배율 | 예 |
| `context` | 영상 보정·추정 초기화·PnP 채택·검출 수·측위 유효·기록 유효·영상 경과시간, 착륙 금지·복구 요청·최종 하강, `sameConfidence`·`sameSafety`·`sameContext` | 아니오 |
| `truth` | 드론·패드 참값, 배율별 UGV 추정 오차 | 아니오 (평가 전용) |
| `probe`, `episodes`, `meta` | 시드·결정 시점·시각, manifest 해시, 배율·구동기·스키마·설정 해시·fingerprint | 아니오 |

### 4.3 문맥 구분

- 기준: 배율 0 (같은 상태·같은 측정 이력의 잡음 없는 관측)
- 관측 신뢰도 변경: 영상 보정·추정 초기화·PnP 채택·검출 수·측위 유효·기록 유효·영상 경과시간 중 하나라도 기준과 다름
- 안전 판단 경계 변경: 착륙 금지·복구 요청·최종 하강 상태 중 하나라도 기준과 다름
- 동일 문맥: 두 조건 모두 불변 (`sameContext`), T03의 $D_{obs}$ 집계 대상

## 5. 명령 로그

### 5.1 롤아웃 기록 (`traj`, 항상)

| 필드 | 의미 |
|---|---|
| `time` | 정책 결정 시각 [s] |
| `actorMean` | tanh 이전 actor 평균 (진단용, 결정론 평가에서 `command`와 동일) |
| `command` | tanh 이전 명령 (확률 정책이면 표본) |
| `requestedAcceleration` | tanh × 축별 한계, 감독기 적용 전 [m/s²] |
| `appliedAccelerationIntervalMean` | 결정 구간 평균 적용 명령 [m/s²] (이전 `appliedAcceleration`, 고주파 실행 명령 아님) |

### 5.2 명령 로그 (`commandLog` 옵션, `command_log_v1`)

| 구역 | 내용 |
|---|---|
| `identity` | 시드, 실행 식별(method_id·학습 시드·그래프 시드·graph_hash·checkpoint_hash), 설정 해시, 상태 표현, 배율, 주기, 행동 한계·축 이름 |
| `policy` | 결정 시각, 정책 관측, tanh 이전 평균, 명령, tanh 행동, 요청 명령 (선택: 정책 상태) |
| `decision` | 결정 문맥(착륙 금지·복구 요청·최종 하강), 감독기 개입·사유, 구간 평균 적용 명령 (정책 입력 아님) |
| `physics` | 물리 스텝 종료 시각·간격·결정 번호, 감독기 적용 명령, 개입 여부, 사유 코드·사유 이름 |
| `truth` | 결정 경계의 드론·패드 참값, 물리 스텝 실제 기체 가속도(지연 동역학), UGV 추정 오차 (평가 전용) |
| `exogenous` | 외생 manifest (미래 사건 포함, 평가 전용) |
| `outcome` | 종료 사유·수익·착륙 시각·결정 수 |
| `labels` | 한글 명칭·단위 |

- 사유 코드: `landing2d.control.supervisorReasonCode` (0 없음, 1 recovery_backup, 2 descent_inhibited, 3 vertical_stopping_margin)
- 평가 함수: `evaluateV2(agent,c,seeds,struct('commandLog',true,'run',run,'configHash',hash,'sensorNoiseScale',s))`, 기본값은 기존 체크포인트 선택 경로와 동일
- 설정 해시: `landing2d.util.resolvedConfig` (JSON·SHA-256, 함수 핸들 문자열화·에피소드 시나리오 제외)

## 6. 검증 (MATLAB R2025b 실제 실행)

- 3차원 옵션: 변경 전 기준과 fingerprint·학습 서명 3개·관측·보상·종료 사유·최종 상태 비트 동일
- self-test 12개 통과, 신규 `probe-replay`:
  - 일관성 설정의 fingerprint·학습 서명 제외
  - 같은 시드의 잡음표 동일, 서로 다른 행동 이후에도 불변, 검출 코너 잡음 = 표준편차 × 해당 슬롯 표 값, 검출 집합 불변
  - 배율 0 잡음표 0, 배율 2 = 2 × 배율 1, 3차원 배율 거부
  - manifest 해시: 같은 시드 동일, 배율·시드 변경 시 상이, reset 이후 생성 거부
  - 명목 재생 = 환경 관측·결정 문맥 비트 일치, 배율 0 재생 첫 관측 = 배율 0 reset 관측, 검출 수 불변
  - 은행: 정책 입력 필드 2개(벡터·그래프), 기준 배율 전 probe 동일 문맥, 배율 10에서 문맥 변경 probe 존재, train 분할 거부
  - probe 평가: 세 비교군 출력 크기, 요청 명령 = 한계 × tanh(평균), 한계 이내, 은행 불변, 재귀 정책 거부
  - 명령 로그: 구역·policy 필드 고정, manifest 해시 일치, 물리 스텝 간격 합 = 결정 간격 합, 구간 평균 = 시간 가중 평균, 감독기 개입 = 적용≠요청, 결정 사유 = 물리 스텝 사유 코드, 실제 가속도 ≠ 적용 명령, 기본 롤아웃의 로그 없음
- smoke 파이프라인: 정상 종료 (세 비교군 1 반복, 수치 무의미)
- S3 실행 확인: 1 반복 smoke 체크포인트로 `run_scenario('S3')` 정상 (수치 무의미)
- 스크립트 비행 harness (검증 시드 2001–2040, 참값 기반 궤적 생성기):

| 항목 | T01 (순차 잡음) | T02 (시간 기준 잡음) |
|---|---|---|
| 착륙 | 40/40 | 40/40 |
| 감독기 개입 결정 수 | descent_inhibited 97, recovery_backup 55 | 97, 55 |
| UGV 추정 RMSE 전체 (위치/속도) | 0.059 m / 0.135 m/s | 0.061 m / 0.136 m/s |
| 영상 보정 중 | 0.064 / 0.149 | 0.065 / 0.149 |
| 예측 중 | 0.032 / 0.032 | 0.039 / 0.034 |

- 개발 점검 (검증 시드 2–3개, 미학습 정책, 실행 확인 전용):
  - 구동기 6개 시드 모두 착륙, 영상 보정 비율 0.60–0.90
  - 배율 0·0.5·1·2: 2개 에피소드 121 probe에서 문맥 변경 0건
  - 배율 10·40: 동일 문맥 비율 관측 신뢰도 21.5%·1.7%, 안전 경계 57%·11.6%, 검출 수 불변 (2절 검출 모델 특성과 일치)

## 7. 미실행·한계

- 학습·평가: 미실행, 성능 수치 없음
- 전체 probe 은행(분할별 100 에피소드): 미생성, T03 임계값 결정 시 validation 은행 생성 예정
- 명목 범위(배율 ≤ 2)의 문맥 변경 빈도: 2개 에피소드 기준 0건 → 동일 문맥 probe가 대부분일 가능성, 전체 은행에서 확인 필요
- 검출 모델: (해결) 관측 코너 기준 검출 판정으로 수정, `docs/refactor/T03_VALIDITY_METRICS_KO.md` 0절
- 극단 배율(≥ 10): (해결) PnP 퇴화 시 기각, 경고 없음 (self-test `probe-replay`)
- Simulink 백엔드: 24차원 관측·인지 기반 감독기·시간 기준 잡음 미반영 (T00 확인 사항 유지)
- 관계 경로: smoke·S3에서 두 RGAT 비교군 관계 경로 비활성(`Wg` = 0) → 동일 행동 (T01 확인 사항 유지)

## 8. 구현 위치

| 파일 | 역할 |
|---|---|
| `src/simulations/+landing2d/+sensing/exogenousNoise.m` | 시간 기준 잡음표 |
| `src/simulations/+landing2d/+sensing/generateMeasurement.m`, `detectMarkers.m`, `navigationEstimate.m` | 숫자 잡음 블록 입력 |
| `src/simulations/+landing2d/+environment/reset.m`, `step.m` | 잡음표 사용·배율 옵션·provenance, 물리 스텝 로그·구간 평균 필드명 |
| `src/simulations/+landing2d/+environment/exogenousManifest.m` | 외생 manifest |
| `src/simulations/+landing2d/+control/supervisorReasonCode.m` | 감독기 사유 코드 |
| `src/simulations/+landing2d/+probe/referenceDriver.m`, `recordReference.m`, `replaySensing.m` | 구동기·기준 궤적·측정 재생 |
| `src/orchestration/+landing2d/+probe/buildBank.m` | probe 은행 |
| `src/algorithms/+landing2d/+rl/probeActions.m` | probe 정책 평가 |
| `src/algorithms/+landing2d/+rl/rolloutEpisodeV2.m`, `evaluateV2.m` | 결정 시각·tanh 이전 평균·명령 로그 |
| `src/orchestration/+landing2d/+config/defaultConsistencyConfig.m` | 배율·probe·로그 설정 |
| `src/orchestration/+landing2d/+util/resolvedConfig.m` | 실행 설정 JSON·해시 |
| `src/orchestration/+landing2d/+paper/trajectoryMetrics.m` | 구간 평균 필드명 반영 |
