function P = buildProbeSet(c)
% BUILDPROBESET  Policy-independent open-loop probe inputs (landing2d.evaluation.openLoopProbes).
%   P = landing2d.evaluation.buildProbeSet(c)
% For the first c.evaluation.probes.episodes test-split seeds the reference
% driver flies the real environment (landing2d.probe.recordReference). Every
% stride-th decision with an initialized UGV estimate, a fresh marker update
% and height above minimumHeight becomes a probe:
%   velocity(i).plus/minus  common observation with the UGV velocity estimate
%                           shifted by +/- velocityDelta
%   update(i).fresh/stale   the same decision replayed with the marker frames of
%                           the last staleAge seconds dropped (estimator predicts)
% The nominal replay must reproduce the environment observation exactly
% (otherwise the probe would not be the state the policy would see).
q = c.evaluation.probes;
seeds = c.experiment.manifest.testSeeds(1:q.episodes);
velocity = struct('episode',{},'decision',{},'height',{},'plus',{},'minus',{});
update = struct('episode',{},'decision',{},'height',{},'fresh',{},'stale',{}, ...
    'estimateShift',{},'estimateShiftV',{});
context = [];
for e = 1:numel(seeds)
    record = landing2d.probe.recordReference(c,seeds(e));
    rep = landing2d.probe.replaySensing(record,c,1);
    assert(isequal(rep.observation,record.observation),'landing2d:ProbeReplay', ...
        'Nominal sensing replay differs from the environment (seed %d).',seeds(e));
    context = rep.context;
    height = record.state(2,:)-record.pad(2,:);   % drone above the pad surface (truth)
    for k = 1:q.stride:record.decisions
        if ~(rep.flags.estimateInitialized(k) && rep.flags.visionUpdated(k) ...
                && height(k)>q.minimumHeight)
            continue;
        end
        O = rep.O{k};
        plus = O; plus.ugv.velocityXZ(1) = plus.ugv.velocityXZ(1)+q.velocityDelta;
        minus = O; minus.ugv.velocityXZ(1) = minus.ugv.velocityXZ(1)-q.velocityDelta;
        velocity(end+1) = struct('episode',e,'decision',k-1,'height',height(k), ...
            'plus',plus,'minus',minus); %#ok<AGROW>
        if record.time(k) < q.staleAge+1, continue; end
        stale = staleReplay(record,c,k,q.staleAge);
        if ~stale.flags.estimateInitialized(k) || stale.flags.visionUpdated(k), continue; end
        update(end+1) = struct('episode',e,'decision',k-1,'height',height(k), ...
            'fresh',O,'stale',stale.O{k}, ...
            'estimateShift',abs(stale.perceptionError.position(1,k))- ...
                abs(rep.perceptionError.position(1,k)), ...
            'estimateShiftV',abs(stale.perceptionError.velocity(1,k))- ...
                abs(rep.perceptionError.velocity(1,k))); %#ok<AGROW>
    end
end
P = struct('velocity',velocity,'update',update,'context',context, ...
    'meta',struct('seeds',seeds,'velocityDelta',q.velocityDelta, ...
    'staleAge',q.staleAge,'stride',q.stride,'minimumHeight',q.minimumHeight, ...
    'driver',c.evaluation.probe.driver));
end

function rep = staleReplay(record,c,k,age)
% Replay decisions 1..k with the frames of [t_k - age, t_k] dropped.
keep = 1:k;
r = record;
for name = {'time','frameDropout','frameCaptured','observation','landingInhibited', ...
        'abortRequested','finalDescentActive'}
    r.(name{1}) = record.(name{1})(:,keep);
end
r.state = record.state(:,keep); r.pad = record.pad(:,keep);
t = r.time;
r.frameDropout = r.frameDropout | (t>=t(k)-age-1e-9 & t<=t(k)+1e-9);
rep = landing2d.probe.replaySensing(r,c,1);
end
