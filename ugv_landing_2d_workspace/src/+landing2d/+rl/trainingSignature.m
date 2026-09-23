function signature = trainingSignature(c)
% TRAININGSIGNATURE  저장된 정책을 그대로 쓸 수 있는지 판단하는 설정 지문.
% 환경이나 학습 설정이 바뀌면 값이 달라지므로 다시 학습합니다.
% 교사 시연을 만드는 유도 법칙이 바뀌면 모방 학습 결과가 달라지므로 함께 포함합니다.
fields = {'dt','tEnd','segmentTimes','scenarioSpeeds','ugvAccelMax', ...
    'padHeight','padHalfLength','initialHeight','maxHeight','cameraFovDeg', ...
    'axMax','azMax','vxMax','vzMax','reacquireInnerRatio','reacquireHoldTime', ...
    'touchdownHeight','touchdownSpeedX','touchdownSpeedZ','controller', ...
    'pnGain','pnApproachSpeed','pnApproachGain','pnClosingGain', ...
    'pnSpeedMatchGain','pnRecoveryGain','pnVerticalGain','pnHeightGain', ...
    'pnMinClosing','pnMinRange', ...
    'kpX','kdX','kpZ','kdZ','climbSpeed','descentSpeed','nearPadDescentGain', ...
    'alignPositionTol','alignSpeedTol'};
signature = struct('rl',c.rl);
for i = 1:numel(fields)
    signature.(fields{i}) = c.(fields{i});
end
% 학습 결과에 영향을 주지 않는 표시 설정은 지문에서 제외.
signature.rl.verbose = false;
signature.rl.retrain = false;
% 상태 표현은 기준 모델일 때 지문에 넣지 않습니다. 그래야 이 항목이 생기기 전에
% 저장해 둔 기준 모델 정책 파일을 그대로 다시 쓸 수 있습니다.
if isfield(c,'graphState') && ~strcmp(c.graphState.stateRepresentation,'baseline')
    signature.graphState = c.graphState;
    signature.graphState.policyFile = '';
end
end
