function summary = monteCarloSummary(runs,label,scenario,c)
% MONTECARLOSUMMARY  같은 시간축의 궤적 표본에서 평균과 2차원 공분산 계산.
nRuns = numel(runs);
n = numel(runs(1).time);
XAll = zeros(n,nRuns);
ZAll = zeros(n,nRuns);
X = nan(n,nRuns);
Z = nan(n,nRuns);
landed = false(1,nRuns);
landingTime = nan(1,nRuns);
eventNames = {'totalOcclusion_s','firstReobservationDelay_s', ...
    'stableReacquireDelay_s','trackingRecoveryDelay_s', ...
    'peakClimbAfterLoss_m','cumulativeClimbAfterLoss_m'};
eventValues = nan(numel(eventNames),nRuns);
for i = 1:nRuns
    XAll(:,i) = runs(i).xDrone;
    ZAll(:,i) = runs(i).zDrone;
    active = runs(i).time <= landing2d.viz.flightEndTime(runs(i))+1e-10;
    X(active,i) = runs(i).xDrone(active);
    Z(active,i) = runs(i).zDrone(active);
    landed(i) = isfinite(runs(i).landingTime);
    landingTime(i) = runs(i).landingTime;
    if nargin >= 4
        recovery = landing2d.metrics.recoveryMetrics(runs(i),c);
        for k = 1:numel(eventNames)
            eventValues(k,i) = recovery.(eventNames{k});
        end
    end
end
[meanX,varX,meanZ,varZ,covXZ,activeCount] = activeMoments(X,Z);
if any(landed)
    meanLandingTime = mean(landingTime(landed));
else
    meanLandingTime = NaN;
end
summary = struct('label',label,'scenario',scenario,'time',runs(1).time, ...
    'nRuns',nRuns,'meanX',meanX,'meanZ',meanZ, ...
    'varX',varX,'varZ',varZ,'covXZ',covXZ, ...
    'activeCount',activeCount,'terminalCount',nRuns-activeCount, ...
    'allRunMeanX',mean(XAll,2),'allRunMeanZ',mean(ZAll,2), ...
    'landingRate',mean(landed),'meanLandingTime',meanLandingTime);
if nargin >= 4
    summary.eventNames = eventNames;
    summary.eventMean = mean(eventValues,2,'omitnan');
    summary.eventVariance = var(eventValues,0,2,'omitnan');
    summary.eventSamples = eventValues;
end

function [meanX,varX,meanZ,varZ,covXZ,count] = activeMoments(X,Z)
count = sum(isfinite(X) & isfinite(Z),2);
meanX = sum(X,2,'omitnan')./max(count,1);
meanZ = sum(Z,2,'omitnan')./max(count,1);
meanX(count == 0) = NaN;
meanZ(count == 0) = NaN;
dx = X-meanX;
dz = Z-meanZ;
denom = max(count-1,1);
varX = sum(dx.^2,2,'omitnan')./denom;
varZ = sum(dz.^2,2,'omitnan')./denom;
covXZ = sum(dx.*dz,2,'omitnan')./denom;
varX(count == 0) = NaN;
varZ(count == 0) = NaN;
covXZ(count == 0) = NaN;
end
end
