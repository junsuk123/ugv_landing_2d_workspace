function s = stepDrone(s, ax, az, xp, xpNext, vpNext, c)
% STEPDRONE  중력 보상된 2차원 이중 적분기 + 속도 한계.
% 착륙 시 수평 위치를 중심으로 순간 이동시키지 않고 접촉 위치 유지.
if s.mode == 3
    s.x = s.x + xpNext - xp;
    s.vx = vpNext;
elseif s.mode < 3
    vxNext = landing2d.util.saturate(s.vx+ax*c.dt, c.vxMax);
    vzNext = landing2d.util.saturate(s.vz+az*c.dt, c.vzMax);
    s.x = s.x + 0.5*(s.vx+vxNext)*c.dt;
    s.h = s.h + 0.5*(s.vz+vzNext)*c.dt;
    s.vx = vxNext;
    s.vz = vzNext;
    % 운용 고도 상한. 유도 법칙은 maxHeight에서 멈추므로 여기에 닿지 않습니다.
    if s.h > c.ceilingHeight
        s.h = c.ceilingHeight;
        s.vz = min(s.vz,0);
    end
end
end
