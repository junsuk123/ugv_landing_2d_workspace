function [r,s] = initializeCase(cfg,index,t)
% INITIALIZECASE  시나리오 하나의 UGV 궤적, 결과 로그, 드론 초기 상태 생성.
% initialize와 강화학습 rollout이 같은 초기화를 쓰도록 분리한 함수입니다.
if nargin < 3 || isempty(t)
    nSteps = round(cfg.tEnd/cfg.dt);
    t = (0:nSteps)'*cfg.dt;
end
[xp,vp,vCommand] = landing2d.scenario.makeUgvTrajectory(t,cfg.scenarioSpeeds(index,:),cfg);
r = struct('name',sprintf('Scenario %d',index), ...
    'speeds',cfg.scenarioSpeeds(index,:),'time',t, ...
    'xUgv',xp,'zPad',cfg.padHeight+zeros(size(t)), ...
    'vxUgv',vp,'vxUgvCommand',vCommand);
logNames = {'xDrone','zDrone','vxDrone','vzDrone','xError', ...
    'fovHalfWidth','mode','axCommand','azCommand','heightReference'};
for f = 1:numel(logNames)
    r.(logNames{f}) = nan(size(t));
end
r.segmentId = landing2d.scenario.segmentIndex(t,cfg.segmentTimes);
r.visible = false(size(t));
r.descending = false(size(t));
r.lossTimes = [];
r.reacquireTimes = [];
r.landingTime = NaN;
r.failureTime = NaN;
r.status = 'Not landed';

% 내부 상태 h는 지면 기준이 아니라 패드 면 기준의 상대 고도.
s = struct('x',xp(1),'h',cfg.initialHeight, ...
    'vx',vp(1),'vz',0,'heightReference',cfg.initialHeight, ...
    'mode',1,'lastPadSpeed',vp(1),'seenTime',0);
end
