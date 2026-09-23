function test_rl_observation_boundary()
% TEST_RL_OBSERVATION_BOUNDARY  강화학습 관측도 비가시 패드 참값을 받지 않는지 확인.
c = landing2d.config.defaultConfig();
[~,states,~] = landing2d.simulation.initialize(c);
s = states(1);
s.h = 2;
s.mode = 2;
far = landing2d.sensing.observePad(s,s.x+100,7,c);
farther = landing2d.sensing.observePad(s,s.x+1000,30,c);
assert(~far.visible && ~farther.visible);
memory = landing2d.rl.initialMemory(1.0);
[a,memoryA] = landing2d.rl.observation(s,far,memory,c,0.1);
[b,memoryB] = landing2d.rl.observation(s,farther,memory,c,0.1);
assert(isequal(a,b),'Invisible pad truth must not change the observation.');
assert(isequal(memoryA,memoryB));
assert(all(isfinite(a)) && numel(a) == c.rl.observationDim);

% 보이는 동안에는 관측 오차가 그대로 들어오고 기억도 갱신되어야 함.
s.mode = 1;
near = landing2d.sensing.observePad(s,s.x+0.2,1.5,c);
assert(near.visible);
[o,memoryNear] = landing2d.rl.observation(s,near,memory,c,0.1);
assert(o(1) == 1 && abs(memoryNear.lastError-0.2) < 1e-12);
assert(memoryNear.timeSinceSeen == 0 && memoryNear.lastPadSpeed == 1.5);
end
