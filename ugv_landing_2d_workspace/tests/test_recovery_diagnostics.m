function test_recovery_diagnostics()
% TEST_RECOVERY_DIAGNOSTICS  Feasibility bound and event metrics.
c = landing2d.config.defaultConfig();
f = landing2d.metrics.horizontalRecoveryFeasibility(c);
assert(max(abs(f.SpeedStep_mps-[3;4;5])) < 1e-12);
assert(max(abs(f.IdealLag_m-[2.625;4.66666666666667;7.29166666666667])) < 1e-10);
assert(f.NoLossFeasible(1) && ~f.NoLossFeasible(2) && ~f.NoLossFeasible(3));

c.tEnd = 1;
c.segmentTimes = [0.3,0.7];
c.scenarioSpeeds = [1,1,1];
[r,~] = landing2d.simulation.initializeCase(c,1);
r.visible(:) = true;
r.visible(21:40) = false;
r.lossTimes = r.time(21);
r.reacquireTimes = r.time(45);
r.xError(:) = 0;
r.vxDrone = r.vxUgv;
r.zDrone(:) = c.padHeight+c.initialHeight;
r.status = 'Not landed';
m = landing2d.metrics.recoveryMetrics(r,c);
assert(abs(m.totalOcclusion_s-0.2) < 1e-12);
assert(abs(m.firstReobservation_s-r.time(41)) < 1e-12);
assert(m.trackingRecovery_s >= m.firstReobservation_s);
end
