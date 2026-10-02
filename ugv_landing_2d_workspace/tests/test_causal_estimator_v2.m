function test_causal_estimator_v2()
c = landing2d.config.primaryConfig(fileparts(fileparts(mfilename('fullpath'))));
s = c.experiment.sensor;
assert(abs(landing2d.sensing.differencedAcceleration(2,4,0,2)-1)<1e-12);
track = landing2d.sensing.initialPadTrack(s);
own = struct('x',0);
m = struct('detected',true,'valid',true,'relativeX',1,'confidence',1, ...
    'bearing',0,'bearingValid',true);
[track,info1] = landing2d.sensing.updatePadTrack(track,m,own,0,s);
[same,info2] = landing2d.sensing.updatePadTrack(track,m,own,0,s);
assert(info1.accepted && info2.idempotent && isequaln(track,same));
% Hidden future changes are absent from the update signature and cannot alter now.
[e,o,info] = landing2d.environment.reset(c,5); %#ok<ASGLU>
assert(~isfield(info.packet,'phase') && ~isfield(info.packet,'truePadAcceleration'));
assert(info.packet.trackInitialized && numel(o)==26);
e.observationMemory.lastMeasurementTime = 0;
e.observationMemory.timeSinceLastDetection = c.experiment.safety.prolongedLoss;
status = landing2d.environment.updateDecisionContext(e.episodeStatus, ...
    e.observationMemory,3,c);
assert(status.abortRequested && status.landingInhibited);
% Reacquisition does not clear a latched abort.
e.observationMemory.timeSinceLastDetection = 0;
status = landing2d.environment.updateDecisionContext(status,e.observationMemory,3.1,c);
assert(status.abortRequested && status.landingInhibited);
end
