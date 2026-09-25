function r = rolloutCase(r,s,c)
% ROLLOUTCASE  주어진 초기 상태에서 유도 법칙 한 시나리오를 끝까지 실행.
t = r.time;
for k = 1:numel(t)
    xp = r.xUgv(k);
    vp = r.vxUgv(k);
    [s,contact] = landing2d.environment.resolveContact(s,xp,vp,c);
    if contact.landed
        r.landingTime = t(k);
        r.status = 'Landed';
    elseif contact.failed
        r.failureTime = t(k);
        r.status = 'Unsafe contact / height violation';
    end
    obs = landing2d.sensing.observePad(s,xp,vp,c);
    [s,ax,az,descending,event] = landing2d.control.command(s,obs,c);
    if event == 1
        r.lossTimes(end+1) = t(k);
    elseif event == 2
        r.reacquireTimes(end+1) = t(k);
    end
    r.xDrone(k) = s.x;
    r.zDrone(k) = c.padHeight+s.h;
    r.vxDrone(k) = s.vx;
    r.vzDrone(k) = s.vz;
    r.xError(k) = xp-s.x;
    r.fovHalfWidth(k) = obs.halfWidth;
    r.mode(k) = s.mode;
    r.visible(k) = obs.visible;
    r.descending(k) = descending;
    r.axCommand(k) = ax;
    r.azCommand(k) = az;
    r.heightReference(k) = s.heightReference;
    if k < numel(t)
        s = landing2d.dynamics.stepDrone(s,ax,az,xp, ...
            r.xUgv(k+1),r.vxUgv(k+1),c);
    end
end
end
