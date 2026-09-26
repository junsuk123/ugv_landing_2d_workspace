function summary = monteCarloSummary(runs,label,scenario,c)
% MONTECARLOSUMMARY  같은 시간축의 궤적 표본에서 평균과 2차원 공분산 계산.
nRuns = numel(runs);
n = numel(runs(1).time);
X = zeros(n,nRuns);
Z = zeros(n,nRuns);
landed = false(1,nRuns);
landingTime = nan(1,nRuns);
eventNames = {'totalOcclusion_s','firstReobservationDelay_s', ...
    'stableReacquireDelay_s','trackingRecoveryDelay_s', ...
    'peakClimbAfterLoss_m','cumulativeClimbAfterLoss_m'};
eventValues = nan(numel(eventNames),nRuns);
for i = 1:nRuns
    X(:,i) = runs(i).xDrone;
    Z(:,i) = runs(i).zDrone;
    landed(i) = isfinite(runs(i).landingTime);
    landingTime(i) = runs(i).landingTime;
    if nargin >= 4
        recovery = landing2d.metrics.recoveryMetrics(runs(i),c);
        for k = 1:numel(eventNames)
            eventValues(k,i) = recovery.(eventNames{k});
        end
    end
end
meanX = mean(X,2);
meanZ = mean(Z,2);
dx = X-meanX;
dz = Z-meanZ;
denom = max(nRuns-1,1);
summary = struct('label',label,'scenario',scenario,'time',runs(1).time, ...
    'nRuns',nRuns,'meanX',meanX,'meanZ',meanZ, ...
    'varX',sum(dx.^2,2)/denom,'varZ',sum(dz.^2,2)/denom, ...
    'covXZ',sum(dx.*dz,2)/denom,'landingRate',mean(landed), ...
    'meanLandingTime',mean(landingTime(landed)));
if nargin >= 4
    summary.eventNames = eventNames;
    summary.eventMean = mean(eventValues,2,'omitnan');
    summary.eventVariance = var(eventValues,0,2,'omitnan');
    summary.eventSamples = eventValues;
end
end
