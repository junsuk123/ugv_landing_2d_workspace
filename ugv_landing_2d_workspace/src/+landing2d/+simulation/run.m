function results = run(cfg)
% RUN  같은 시간축에서 모든 시나리오를 갱신. 시각화는 수치 계산과 분리.
[results, states, t] = landing2d.simulation.initialize(cfg);
nCases = numel(results);
frameStride = max(1,round(1/(cfg.animationHz*cfg.dt)));
if cfg.animate
    live = landing2d.viz.createAnimation(cfg,nCases);
else
    live = struct('fig',[]);
end
wallClock = tic;
for k = 1:numel(t)
    for j = 1:nCases
        s = states(j);
        xp = results(j).xUgv(k);
        vp = results(j).vxUgv(k);
        [s,contact] = landing2d.environment.resolveContact(s,xp,vp,cfg);
        if contact.landed
            results(j).landingTime = t(k);
            results(j).status = 'Landed';
        elseif contact.failed
            results(j).failureTime = t(k);
            results(j).status = 'Unsafe contact / height violation';
        end
        obs = landing2d.sensing.observePad(s,xp,vp,cfg);
        [s,ax,az,descending,event] = landing2d.control.command(s,obs,cfg);
        if event == 1
            results(j).lossTimes(end+1) = t(k);
        elseif event == 2
            results(j).reacquireTimes(end+1) = t(k);
        end

        % 현재 시각의 상태 기록. 제어기에 전달하지 않는 참값도 평가용으로 기록.
        results(j).xDrone(k) = s.x;
        results(j).zDrone(k) = cfg.padHeight+s.h;
        results(j).vxDrone(k) = s.vx;
        results(j).vzDrone(k) = s.vz;
        results(j).xError(k) = xp-s.x;
        results(j).fovHalfWidth(k) = obs.halfWidth;
        results(j).mode(k) = s.mode;
        results(j).visible(k) = obs.visible;
        results(j).descending(k) = descending;
        results(j).axCommand(k) = ax;
        results(j).azCommand(k) = az;
        results(j).heightReference(k) = s.heightReference;
        if k < numel(t)
            s = landing2d.dynamics.stepDrone(s,ax,az,xp, ...
                results(j).xUgv(k+1),results(j).vxUgv(k+1),cfg);
        end
        states(j) = s;
    end

    % 배속은 표시만 변경. 창을 닫아도 수치 계산은 끝까지 계속 진행.
    if cfg.animate && isgraphics(live.fig) ...
            && (mod(k-1,frameStride) == 0 || k == numel(t))
        if isfinite(cfg.playbackSpeed)
            remaining = t(k)/cfg.playbackSpeed-toc(wallClock);
            if remaining > 0
                pause(remaining);
            end
        end
        if isgraphics(live.fig)
            landing2d.viz.updateAnimation(live,results,k,cfg);
            drawnow limitrate;
        end
    end
end
if cfg.animate && isgraphics(live.fig)
    drawnow;
end
end
