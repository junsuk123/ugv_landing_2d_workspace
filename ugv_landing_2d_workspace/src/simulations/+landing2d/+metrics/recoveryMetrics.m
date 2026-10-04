function metrics = recoveryMetrics(r,c)
% RECOVERYMETRICS  Event-centered visibility, tracking, climb and landing data.
last = find(r.time <= landing2d.viz.flightEndTime(r)+1e-10,1,'last');
idx = 1:last;
t = r.time(idx);
visible = logical(r.visible(idx));

metrics = struct('firstLoss_s',NaN,'totalOcclusion_s',0, ...
    'firstReobservation_s',NaN,'firstReobservationDelay_s',NaN, ...
    'stableReacquire_s',NaN,'stableReacquireDelay_s',NaN, ...
    'trackingRecovery_s',NaN,'trackingRecoveryDelay_s',NaN, ...
    'peakClimbAfterLoss_m',0,'cumulativeClimbAfterLoss_m',0, ...
    'landing_s',r.landingTime,'landed',isfinite(r.landingTime));
if numel(t) > 1
    metrics.totalOcclusion_s = sum(~visible(1:end-1).*diff(t));
end
if isempty(r.lossTimes)
    return;
end

lossTime = r.lossTimes(1);
metrics.firstLoss_s = lossTime;
lossIndex = find(t >= lossTime,1);
if isempty(lossIndex)
    return;
end

rise = find(visible(lossIndex:end) & ...
    [true;~visible(lossIndex:end-1)],1);
if ~isempty(rise)
    metrics.firstReobservation_s = t(lossIndex+rise-1);
    metrics.firstReobservationDelay_s = metrics.firstReobservation_s-lossTime;
end
if ~isempty(r.reacquireTimes)
    metrics.stableReacquire_s = r.reacquireTimes(1);
    metrics.stableReacquireDelay_s = metrics.stableReacquire_s-lossTime;
end

relativeSpeed = r.vxUgv(idx)-r.vxDrone(idx);
tracking = visible & abs(r.xError(idx)) <= c.alignPositionTol ...
    & abs(relativeSpeed) <= c.alignSpeedTol;
holdSamples = max(1,ceil(c.reacquireHoldTime/c.dt));
runLength = 0;
for k = lossIndex:last
    if tracking(k)
        runLength = runLength+1;
        if runLength >= holdSamples
            metrics.trackingRecovery_s = t(k);
            metrics.trackingRecoveryDelay_s = t(k)-lossTime;
            break;
        end
    else
        runLength = 0;
    end
end

height = r.zDrone(lossIndex:last)-c.padHeight;
metrics.peakClimbAfterLoss_m = max(height)-height(1);
if numel(height) > 1
    metrics.cumulativeClimbAfterLoss_m = sum(max(diff(height),0));
end
end
