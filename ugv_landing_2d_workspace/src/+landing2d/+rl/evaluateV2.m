function [results,score,info] = evaluateV2(agent,c,seeds)
% EVALUATEV2  Paired deterministic validation on a fixed manifest subset.
if nargin < 3 || isempty(seeds)
    count = 3;
    if isfield(c.experiment,'validationEpisodeCount')
        count = c.experiment.validationEpisodeCount;
    end
    count = min(count,numel(c.experiment.manifest.validationSeeds));
    seeds = c.experiment.manifest.validationSeeds(1:count);
end
resultCells = cell(1,numel(seeds));
returns = zeros(1,numel(seeds)); success = false(size(returns));
capture = zeros(size(returns)); unsafe = false(size(returns));
abort = false(size(returns));
timeout = false(size(returns));
traceGraph=~strcmp(agent.encoderSpec.mode,'baseline');
if traceGraph
    graphSchema=landing2d.graphstate.schemaFor(agent.encoderSpec.mode);
    finalNodeValues=nan(graphSchema.nNodes,numel(seeds));
    hasAttention=ismember(agent.encoderSpec.mode,{'context_rgat','context_gat'});
    if hasAttention, edgeAttention=nan(numel(graphSchema.src),numel(seeds)); end
end
for i = 1:numel(seeds)
    opts = struct('deterministic',true,'collect',true,'maxDecisions',Inf);
    [resultCells{i},traj] = landing2d.rl.rolloutEpisodeV2(agent,c,seeds(i),opts);
    returns(i) = traj.return;
    capture(i) = traj.captureRate;
    success(i) = strcmp(resultCells{i}.terminalReason,'SUCCESS');
    unsafe(i) = ismember(resultCells{i}.terminalReason,{'UNSAFE_CONTACT', ...
        'UNAUTHORIZED_CONTACT','MISSED_PAD_CONTACT','SAFETY_ENVELOPE_VIOLATION'});
    abort(i) = strcmp(resultCells{i}.terminalReason,'SAFE_ABORT');
    timeout(i) = strcmp(resultCells{i}.terminalReason,'TASK_TIMEOUT');
    if traceGraph && traj.count>0
        X=reshape(traj.state(:,end),graphSchema.inDim,graphSchema.nNodes);
        finalNodeValues(:,i)=X(1,:)';
        if hasAttention
            [~,cache]=landing2d.graphstate.encoderForward(agent.policy.encoder, ...
                agent.encoderSpec,traj.state(:,end),'policy');
            if isfield(cache,'cache2')
                edgeAttention(:,i)=cache.cache2.alpha(:,1);
            else
                edgeAttention(:,i)=cache.cache1.alpha(:,1);
            end
        end
    end
end
results = [resultCells{:}];
score = mean(returns);
reasons={results.terminalReason};
[selectionScore,outcomeRates] = landing2d.rl.selectionScoreV2(reasons,returns);
info = struct('returns',returns,'captureRate',capture,'landed',success, ...
    'landingTime',[results.landingTime],'landingRate',mean(success), ...
    'meanCaptureRate',mean(capture),'meanReturn',score, ...
    'selectionScore',selectionScore,'unsafeRate',mean(unsafe), ...
    'safeAbortRate',mean(abort),'timeoutRate',mean(timeout), ...
    'outcomeRates',outcomeRates,'nodeMean',[],'nodeVariance',[], ...
    'edgeAttentionMean',[],'graphSchema',struct());
if traceGraph
    info.nodeMean=mean(finalNodeValues,2,'omitnan');
    info.nodeVariance=var(finalNodeValues,0,2,'omitnan');
    info.graphSchema=graphSchema;
    if hasAttention, info.edgeAttentionMean=mean(edgeAttention,2,'omitnan'); end
end
end
