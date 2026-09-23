function test_observation_boundary()
% TEST_OBSERVATION_BOUNDARY  비가시 패드 참값을 제어기가 받지 않는지 확인.
c = landing2d.config.defaultConfig();
[~,states,~] = landing2d.simulation.initialize(c);
s = states(1); s.h = 2; s.heightReference = s.h;
a = landing2d.sensing.observePad(s,s.x+100,7,c);
b = landing2d.sensing.observePad(s,s.x+1000,30,c);
assert(~a.visible && ~b.visible);
assert(all(isnan([a.xError,a.vError,a.padSpeed])));
[sa,axA,azA] = landing2d.control.pdController(s,a,c);
[sb,axB,azB] = landing2d.control.pdController(s,b,c);
assert(isequal(sa,sb) && axA == axB && azA == azB);
assert(sa.mode == 2 && sa.heightReference > s.heightReference);
end
