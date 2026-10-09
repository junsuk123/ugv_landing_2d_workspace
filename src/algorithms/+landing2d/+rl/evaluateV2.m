function [results,score,info] = evaluateV2(agent,c,seeds,options)
% EVALUATEV2  Paired deterministic validation on a fixed manifest subset.
% OPTIONS (evaluation logging; defaults keep the checkpoint-selection path):
%   commandLog        true keeps each episode's command log in results(i).commandLog
%   commandLogStates  also keep the policy states (graph arms: 108 x decisions)
%   run               policy identity (landing2d.rl.runIdentity) copied into each log
%   configHash        resolved-configuration hash copied into each log
%   sensorNoiseScale  planar sensor-noise standard-deviation scale (default 1)
if nargin < 4, options = struct(); end
logOptions = struct('commandLog',false,'commandLogStates',false, ...
    'run',struct(),'configHash','','sensorNoiseScale',[]);
names = fieldnames(options);
for i = 1:numel(names)
    assert(isfield(logOptions,names{i}),'landing2d:EvaluateOption', ...
        'Unknown evaluateV2 option %s.',names{i});
    logOptions.(names{i}) = options.(names{i});
end
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
relationResidualMean = zeros(c.rl.actionDim,numel(seeds));
verticalGateFraction = zeros(size(returns));
traceGraph=~strcmp(agent.encoderSpec.mode,'baseline');
if traceGraph
    % The agent's own typed graph (canonical or relation-shuffled), not a
    % schema rebuilt from the mode string.
    graphSchema=agent.encoderSpec.schema;
    finalNodeValues=nan(graphSchema.nNodes,numel(seeds));
    hasAttention=ismember(agent.encoderSpec.mode,{'context_rgat','context_gat'});
    if hasAttention, edgeAttention=nan(numel(graphSchema.src),numel(seeds)); end
end
% Deterministic, seed-independent rollouts: with an open pool and parallel
% episodes enabled the seeds run in parfor (same per-seed computation, only
% faster); otherwise serially.
opts = mergeOptions(struct('deterministic',true,'collect',true,'maxDecisions',Inf), ...
    logOptions);
episodeReturn = zeros(1,numel(seeds)); episodeCapture = zeros(1,numel(seeds));
finalStates = cell(1,numel(seeds));
if useParallel(c,numel(seeds))
    parfor i = 1:numel(seeds)
        [resultCells{i},traj] = landing2d.rl.rolloutEpisodeV2(agent,c,seeds(i),opts);
        episodeReturn(i) = traj.return; episodeCapture(i) = traj.captureRate;
        finalStates{i} = traj.state(:,max(traj.count,1):traj.count);
    end
else
    for i = 1:numel(seeds)
        [resultCells{i},traj] = landing2d.rl.rolloutEpisodeV2(agent,c,seeds(i),opts);
        episodeReturn(i) = traj.return; episodeCapture(i) = traj.captureRate;
        finalStates{i} = traj.state(:,max(traj.count,1):traj.count);
    end
end
for i = 1:numel(seeds)
    returns(i) = episodeReturn(i);
    capture(i) = episodeCapture(i);
    success(i) = strcmp(resultCells{i}.terminalReason,'SUCCESS');
    unsafe(i) = ismember(resultCells{i}.terminalReason,{'UNSAFE_CONTACT', ...
        'UNAUTHORIZED_CONTACT','MISSED_PAD_CONTACT','SAFETY_ENVELOPE_VIOLATION'});
    abort(i) = strcmp(resultCells{i}.terminalReason,'SAFE_ABORT');
    timeout(i) = strcmp(resultCells{i}.terminalReason,'TASK_TIMEOUT');
    if isfield(resultCells{i},'policyDiagnostics')
        relationResidualMean(:,i) = ...
            resultCells{i}.policyDiagnostics.meanAbsRelationResidual;
        verticalGateFraction(i) = ...
            resultCells{i}.policyDiagnostics.verticalGateFraction;
    end
    if traceGraph && ~isempty(finalStates{i})
        graphState=finalStates{i};
        if strcmp(agent.encoderSpec.readout,'observation_plus_groups')
            graphState=graphState(agent.encoderSpec.rawDim+1:end,:);
        end
        X=reshape(graphState,graphSchema.inDim,graphSchema.nNodes);
        finalNodeValues(:,i)=X(1,:)';
        if hasAttention
            [~,cache]=landing2d.graphstate.encoderForward(agent.policy.encoder, ...
                agent.encoderSpec,finalStates{i},'policy');
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
    'edgeAttentionMean',[],'graphSchema',struct(), ...
    'meanAbsRelationResidual',mean(relationResidualMean,2), ...
    'meanVerticalGateFraction',mean(verticalGateFraction));
if traceGraph
    info.nodeMean=mean(finalNodeValues,2,'omitnan');
    info.nodeVariance=var(finalNodeValues,0,2,'omitnan');
    info.graphSchema=graphSchema;
    if hasAttention, info.edgeAttentionMean=mean(edgeAttention,2,'omitnan'); end
end
end

function opts = mergeOptions(opts,extra)
names = fieldnames(extra);
for i = 1:numel(names), opts.(names{i}) = extra.(names{i}); end
end

function tf = useParallel(c,count)
tf = count > 1 && isfield(c.rl,'parallelEpisodes') && c.rl.parallelEpisodes ...
    && ~isempty(ver('parallel')) && ~isempty(gcp('nocreate'));
end
