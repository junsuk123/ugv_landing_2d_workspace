function test_pn_guidance()
% TEST_PN_GUIDANCE  비례 항법 유도의 출력 형식, 정보경계, 유도 방향 확인.
c = landing2d.config.defaultConfig();
assert(strcmpi(c.controller,'pn'),'The default controller must be PN guidance.');
[~,states,~] = landing2d.simulation.initialize(c);
base = states(1);

% 1) 출력은 가속도 명령이며 한계 안에 있어야 함.
s = base; s.h = 5; s.vx = 1; s.vz = -0.2;
obs = landing2d.sensing.observePad(s,s.x+0.4,3.0,c);
assert(obs.visible);
[~,ax,az] = landing2d.control.command(s,obs,c);
assert(isscalar(ax) && isscalar(az) && isfinite(ax) && isfinite(az));
assert(abs(ax) <= c.axMax+1e-12 && abs(az) <= c.azMax+1e-12);

% 2) 패드가 바로 아래에 있고 상대 속도가 0이면 시선각 속도도 0이므로
%    직교 성분은 사라지고 접근 성분만 남아 하강해야 함.
s = base; s.h = 5; s.vx = 1; s.vz = 0;
obs = landing2d.sensing.observePad(s,s.x,1.0,c);
assert(obs.visible);
[~,ax,az] = landing2d.control.command(s,obs,c);
assert(abs(ax) < 1e-12,'A zero LOS rate must give no lateral command.');
assert(az < 0,'The closing term must command a descent.');

% 3) 패드가 앞서 나가면 시선각 속도가 생기고 전방 가속도가 나와야 함.
s = base; s.h = 5; s.vx = 1; s.vz = 0;
obs = landing2d.sensing.observePad(s,s.x,2.0,c);
[~,axAhead] = landing2d.control.command(s,obs,c);
assert(axAhead > 0,'A pad pulling ahead must produce a forward command.');
obs = landing2d.sensing.observePad(s,s.x,0.0,c);
[~,axBehind] = landing2d.control.command(s,obs,c);
assert(axBehind < 0,'A pad falling behind must produce a rearward command.');

% 4) 비가시 구간에서 실제 패드 값이 달라도 같은 명령이어야 함.
s = base; s.h = 2; s.vx = 1; s.vz = 0; s.mode = 2; s.lastPadSpeed = 1.5;
a = landing2d.sensing.observePad(s,s.x+100,7,c);
b = landing2d.sensing.observePad(s,s.x+1000,30,c);
assert(~a.visible && ~b.visible);
[sa,axA,azA] = landing2d.control.command(s,a,c);
[sb,axB,azB] = landing2d.control.command(s,b,c);
assert(isequal(sa,sb) && axA == axB && azA == azB);
assert(axA > 0,'Matching the last observed pad speed must accelerate forward.');
assert(azA > 0,'The search phase must climb to widen the field of view.');

% 5) 상승 한계에서는 더 올라가지 않아야 함.
s.h = c.maxHeight; s.vz = 0;
[~,~,azTop] = landing2d.control.command(s,a,c);
assert(azTop <= 1e-12,'The climb must stop at maxHeight.');

% 6) 착륙/실패 상태에서는 명령이 0.
for mode = [3,4]
    s = base; s.mode = mode;
    obs = landing2d.sensing.observePad(s,s.x,1,c);
    [~,ax,az,descending,event] = landing2d.control.command(s,obs,c);
    assert(ax == 0 && az == 0 && ~descending && event == 0);
end

% 7) 세 시나리오 모두 안전 착륙해야 함.
run = landing2d.config.applyOptions(c,struct('animate',false, ...
    'makeFinalPlots',false,'saveResults',false));
results = landing2d.simulation.run(run);
for j = 1:numel(results)
    assert(strcmp(results(j).status,'Landed'), ...
        sprintf('PN guidance failed to land in scenario %d: %s',j,results(j).status));
    assert(~isempty(results(j).lossTimes) && ~isempty(results(j).reacquireTimes), ...
        'The scenario must still exercise FOV loss and reacquisition.');
    flying = results(j).mode < 3;
    assert(all(abs(results(j).axCommand(flying)) <= c.axMax+1e-12));
    assert(all(abs(results(j).azCommand(flying)) <= c.azMax+1e-12));
end
end
