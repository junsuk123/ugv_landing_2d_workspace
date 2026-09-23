function test_speed_segments()
% TEST_SPEED_SEGMENTS  구간 경계, 목표 속도, UGV 가속도 한계 검증.
c = landing2d.config.defaultConfig();
t = (0:round(c.tEnd/c.dt))'*c.dt;
[x,v,vCmd] = landing2d.scenario.makeUgvTrajectory(t,c.scenarioSpeeds(1,:),c);
id = landing2d.scenario.segmentIndex(t,c.segmentTimes);
assert(all(vCmd(id == 1) == c.scenarioSpeeds(1,1)));
assert(all(vCmd(id == 2) == c.scenarioSpeeds(1,2)));
assert(all(vCmd(id == 3) == c.scenarioSpeeds(1,3)));
assert(all(abs(diff(v)/c.dt) <= c.ugvAccelMax+1e-10));
assert(all(diff(x) >= 0));
t1 = c.segmentTimes(1); t2 = c.segmentTimes(2);
assert(isequal(landing2d.scenario.segmentIndex( ...
    [t1-0.01,t1,t2-0.01,t2],c.segmentTimes),[1,2,2,3]));
% 목표 전환 직후 실제 속도는 연속
assert(abs(v(find(t >= t1,1))-c.scenarioSpeeds(1,1)) < 1e-12);
end
