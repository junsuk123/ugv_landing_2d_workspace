function signature = designSignature(c)
% DESIGNSIGNATURE  저장된 보상 가중치 설계를 재사용해도 되는지 판단하는 지문.
% 온톨로지 스키마, 학습 설정, 데이터 생성에 쓰이는 환경 값이 모두 들어갑니다.
schema = landing2d.ontology.nodeSchema();
fields = {'dt','tEnd','segmentTimes','scenarioSpeeds','ugvAccelMax', ...
    'padHeight','padHalfLength','initialHeight','maxHeight','cameraFovDeg', ...
    'axMax','azMax','vxMax','vzMax','touchdownSpeedX','touchdownSpeedZ', ...
    'kpX','kdX','kpZ','kdZ','climbSpeed','descentSpeed','controller', ...
    'pnGain','pnApproachSpeed','pnApproachGain','pnClosingGain', ...
    'pnSpeedMatchGain','pnRecoveryGain','pnVerticalGain','pnHeightGain', ...
    'pnMinClosing','pnMinRange'};
signature = struct('ontology',c.ontology,'schema',schema);
signature.ontology.verbose = false;
signature.ontology.redesign = false;
for i = 1:numel(fields)
    signature.(fields{i}) = c.(fields{i});
end
% 데이터 수집과 의미 채널이 참조하는 강화학습 설정만 포함.
signature.actionInterval = c.rl.actionInterval;

signature.initialOffsetRange = c.rl.initialOffsetRange;
signature.initialSpeedRange = c.rl.initialSpeedRange;
signature.distanceScale = c.rl.distanceScale;
end
