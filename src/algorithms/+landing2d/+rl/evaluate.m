function [results,score,info] = evaluate(agent,c)
% EVALUATE  공칭 초기 조건에서 결정론적 정책으로 모든 시나리오를 모사.
% 비교 그림과 정책 선택 점수 모두 이 함수의 결과를 사용합니다.
if isfield(c,'experiment') && isfield(c.experiment,'enabled') && c.experiment.enabled
    [results,score,info] = landing2d.rl.evaluateV2(agent,c,[]);
    return;
end
nCases = size(c.scenarioSpeeds,1);
traceRgat = ismember(agent.encoderSpec.mode,{'gat','ontology_rgat'});
options = struct('deterministic',true,'collect',true,'rs',[], ...
    'traceGraph',traceRgat);
returns = zeros(nCases,1);
captureRate = zeros(nCases,1);
landed = false(nCases,1);
landingTime = nan(nCases,1);
occlusion = zeros(nCases,1);
stableDelay = zeros(nCases,1);
trackingDelay = zeros(nCases,1);
cumulativeClimb = zeros(nCases,1);
postEventClimb = zeros(nCases,1);
postEventXErrorRms = zeros(nCases,1);
if traceRgat
    graphSchema = landing2d.graphstate.schemaFor(agent.encoderSpec.mode);
    finalNodeValues = nan(graphSchema.nNodes,nCases);
    edgeAttention = nan(numel(graphSchema.src),nCases);
end
for j = 1:nCases
    [r,s] = landing2d.rl.makeEpisode(c,j,agent.rl,[]);
    [r,traj] = landing2d.rl.rolloutEpisode(agent,r,s,c,options);
    results(j) = r; %#ok<AGROW>
    returns(j) = traj.return;
    captureRate(j) = traj.captureRate;
    landed(j) = isfinite(r.landingTime);
    landingTime(j) = r.landingTime;
    recovery = landing2d.metrics.recoveryMetrics(r,c);
    occlusion(j) = recovery.totalOcclusion_s;
    stableDelay(j) = terminalPenalty(recovery.stableReacquireDelay_s, ...
        recovery.firstLoss_s,c.tEnd);
    trackingDelay(j) = terminalPenalty(recovery.trackingRecoveryDelay_s, ...
        recovery.firstLoss_s,c.tEnd);
    cumulativeClimb(j) = recovery.cumulativeClimbAfterLoss_m;
    [postEventClimb(j),postEventXErrorRms(j)] = postEventMetrics(r,c);
    if traceRgat && ~isempty(traj.graphValues)
        finalNodeValues(:,j) = traj.graphValues(:,end);
        [~,encoderCache] = landing2d.graphstate.encoderForward( ...
            agent.policy.encoder,agent.encoderSpec,traj.graphStates(:,end));
        edgeAttention(:,j) = encoderCache.cache2.alpha(:,1);
    end
end
score = mean(returns);
eventCost = occlusion+stableDelay+trackingDelay ...
    +5*postEventClimb+2*postEventXErrorRms;
selectionScore = 10000*mean(landed)+1000*min(double(landed)) ...
    +20*min(captureRate)-mean(eventCost)+1e-3*score;
info = struct('returns',returns,'captureRate',captureRate, ...
    'landed',landed,'landingTime',landingTime, ...
    'landingRate',mean(landed),'meanCaptureRate',mean(captureRate), ...
    'meanReturn',score,'selectionScore',selectionScore, ...
    'eventCost',eventCost,'meanEventCost',mean(eventCost), ...
    'totalOcclusion',occlusion,'stableReacquireDelay',stableDelay, ...
    'trackingRecoveryDelay',trackingDelay,'cumulativeClimb',cumulativeClimb);
info.postEventClimb = postEventClimb;
info.postEventXErrorRms = postEventXErrorRms;
if traceRgat
    info.nodeMean = mean(finalNodeValues,2,'omitnan');
    info.nodeVariance = var(finalNodeValues,0,2,'omitnan');
    info.edgeAttentionMean = mean(edgeAttention,2,'omitnan');
    info.graphSchema = graphSchema;
else
    info.nodeMean = [];
    info.nodeVariance = [];
    info.edgeAttentionMean = [];
    info.graphSchema = struct();
end
end

function value = terminalPenalty(delay,lossTime,tEnd)
if isnan(lossTime)
    value = 0;
elseif isfinite(delay)
    value = delay;
else
    value = max(tEnd-lossTime,0);
end
end

function [climb,xErrorRms] = postEventMetrics(r,c)
tEnd = landing2d.viz.flightEndTime(r);
index = find(r.time >= c.segmentTimes(1) & r.time <= tEnd+1e-10);
if isempty(index)
    climb = 0;
    xErrorRms = 0;
    return;
end
height = r.zDrone(index)-c.padHeight;
climb = sum(max(diff(height),0));
xErrorRms = sqrt(mean(r.xError(index).^2));
end
