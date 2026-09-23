function [s, ax, az, descending, event] = pdController(s, obs, c)
% mode: 1=TRACK/LAND, 2=SEARCH/CLIMB, 3=LANDED, 4=FAILED
ax = 0; az = 0; descending = false; event = 0;
if s.mode >= 3
    return;
end
if obs.visible
    s.lastPadSpeed = obs.padSpeed;
end

% 시야를 잃으면 상승. 재포착은 중앙 영역에서 일정 시간 보인 뒤 확정.
if ~obs.visible && s.mode ~= 2
    s.mode = 2;
    s.heightReference = s.h;
    s.seenTime = 0;
    event = 1;
elseif s.mode == 2
    if obs.visible && abs(obs.xError) <= c.reacquireInnerRatio * obs.halfWidth
        s.seenTime = s.seenTime + c.dt;
    else
        s.seenTime = 0;
    end
    if s.seenTime + 1e-12 >= c.reacquireHoldTime
        s.mode = 1;
        s.heightReference = s.h;
        s.seenTime = 0;
        event = 2;
    end
end

% 수평 PD. 패드가 안 보이면 현재의 실제 패드 위치/속도를 사용하지 않음.
if obs.visible
    ax = c.kpX * obs.xError + c.kdX * obs.vError;
else
    ax = c.kdX * (s.lastPadSpeed - s.vx);
end
ax = landing2d.util.saturate(ax, c.axMax);

% 수직 PD의 기준 궤적 생성
oldReference = s.heightReference;
if s.mode == 2
    s.heightReference = min(c.maxHeight, oldReference + c.climbSpeed * c.dt);
    vzReference = (s.heightReference - oldReference) / c.dt;
elseif abs(obs.xError) <= c.alignPositionTol && abs(obs.vError) <= c.alignSpeedTol
    descending = true;
    downSpeed = min(c.descentSpeed, c.nearPadDescentGain * max(s.h, 0));
    s.heightReference = max(0, oldReference - downSpeed * c.dt);
    vzReference = (s.heightReference - oldReference) / c.dt;
else
    % 재포착했어도 수평 오차가 크면 하강을 멈추고 먼저 정렬.
    s.heightReference = s.h;
    vzReference = 0;
end
az = c.kpZ * (s.heightReference - s.h) + c.kdZ * (vzReference - s.vz);
az = landing2d.util.saturate(az, c.azMax);
end
