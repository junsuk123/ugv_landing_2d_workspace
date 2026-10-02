function test_pn_v2()
% V2 reference guidance shares the causal environment and initial CV state.
c=landing2d.config.primaryConfig(fileparts(fileparts(mfilename('fullpath'))));
[env,~]=landing2d.environment.reset(c,2201);
assert(abs(env.physicalState.vx-env.pad.vx)<1e-12);
r=landing2d.control.rolloutPnV2(c,2201,struct('maxDecisions',5));
assert(strcmp(r.schemaVersion,'pn_rollout_result_v2') && r.truncated);
assert(numel(r.time)==6 && all(isfinite(r.xDrone)) && all(isfinite(r.zDrone)));
assert(all(diff(r.time)>0));
end
