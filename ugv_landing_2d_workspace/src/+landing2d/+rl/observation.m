function [o,memory] = observation(s,obs,memory,c,dtAction)
% OBSERVATION  정책 입력 벡터. 비가시 구간에서는 패드 참값을 넣지 않습니다.
% 보이지 않는 동안에는 마지막 관측값과 마지막 관측 패드 속도로만 추측합니다.
if obs.visible
    memory.lastError = obs.xError;
    memory.lastPadSpeed = obs.padSpeed;
    memory.timeSinceSeen = 0;
else
    % 마지막으로 본 패드 속도를 이용한 추측 항법. 현재 참값은 사용하지 않음.
    memory.lastError = memory.lastError+(memory.lastPadSpeed-s.vx)*dtAction;
    memory.timeSinceSeen = memory.timeSinceSeen+dtAction;
end
xScale = 5.0;
vScale = 3.0;
% 고도는 상승 한계 부근에서 포화시켜, 교사 데이터 밖으로 나가도
% 신경망 입력이 발산하지 않게 합니다.
visible = double(obs.visible);
if obs.visible
    normalizedError = obs.xError/xScale;
    normalizedRate = obs.vError/vScale;
    fovMargin = landing2d.util.saturate(obs.xError/max(obs.halfWidth,1e-6),1);
else
    normalizedError = 0;
    normalizedRate = 0;
    fovMargin = 0;
end
o = [visible; ...
    double(s.mode == 2); ...
    double(s.mode == 3); ...
    normalizedError; ...
    normalizedRate; ...
    fovMargin; ...
    landing2d.util.saturate(memory.lastError/xScale,2); ...
    min(memory.timeSinceSeen/2,1); ...
    min(s.h/c.maxHeight,1.2); ...
    (s.vx-memory.lastPadSpeed)/c.vxMax; ...
    s.vz/c.vzMax];
end
