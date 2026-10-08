function [view,track] = perceptionView(O,state,status,t,scenario,c)
% PERCEPTIONVIEW  공통 관측 UGV 추정 -> 안전 감독기 입력과 결정 문맥용 추적 요약 (평면).
% 정책 관측과 같은 마커 카메라 인지 결과로 안전 감독기·착륙 승인을 구동합니다.
%   track  updateDecisionContext 입력: 추정 초기화 여부, 마지막 영상 보정 후 경과시간
%          (초기화 전 Inf), 신뢰도(채택된 PnP 관측이 있으면 1)
%   view   safetySupervisor 입력: 패드 기준 고도 h(알려진 패드 높이), 착륙 금지·중단 요청,
%          결정 시각 O.decisionTime의 UGV 추정을 시각 t까지 등속 예측한 패드 상대 위치·속도
% 기체 자기 상태는 기존 감독기와 같이 동기화된 기체 상태(state)를 씁니다.
ugv = O.ugv;
track = struct('initialized',ugv.estimateInitialized, ...
    'timeSinceLastDetection',ugv.visionAge, ...
    'lastConfidence',double(ugv.estimateInitialized));
ex = 0; relativeVx = 0;
if ugv.estimateInitialized
    offset = c.experiment.commonObservation.ugv.padOffset;
    padX = ugv.positionXZ(1)+ugv.velocityXZ(1)*(t-O.decisionTime)+offset(1);
    ex = padX-state.x;
    relativeVx = ugv.velocityXZ(1)-state.vx;
end
view = struct('h',state.z-scenario.padHeight, ...
    'abortRequested',status.abortRequested,'landingInhibited',status.landingInhibited, ...
    'trackInitialized',ugv.estimateInitialized,'exEstimate',ex, ...
    'relativeVxEstimate',relativeVx);
end
