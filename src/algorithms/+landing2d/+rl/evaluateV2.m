function [results,meanReturn,info] = evaluateV2(agent,c,seeds,options)
% EVALUATEV2  Deterministic evaluation on fixed seeds (default: the validation split).
%   [results,meanReturn,info] = landing2d.rl.evaluateV2(agent,c,[])        % validation
%   [results,meanReturn,info] = landing2d.rl.evaluateV2(agent,c,seeds,options)
% With seeds = [] the first experiment.validationEpisodeCount validation-split
% seeds are used; this is the checkpoint-selection evaluation of ppoTrain.
% OPTIONS: commandLog, commandLogStates, run, configHash, sensorNoiseScale
% (passed to landing2d.rl.rolloutEpisodeV2).
% meanReturn is the mean episode return (the checkpoint is selected by
% info.selectionScore, not by it). info: landing/unsafe/timeout/safe-abort
% rates, mean return, the outcome-ordered selection score
% (landing2d.rl.selectionScoreV2), the marker measurement-update rate
% (captureRate / meanCaptureRate, persisted names) and, for graph arms, the
% mean final first node feature and first-layer edge attention.
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
    count = min(c.experiment.validationEpisodeCount,numel(c.experiment.manifest.validationSeeds));
    seeds = c.experiment.manifest.validationSeeds(1:count);
end
n = numel(seeds);
resultCells = cell(1,n);
returns = zeros(1,n); markerUpdateRate = zeros(1,n); finalPolicyInputs = cell(1,n);
opts = logOptions; opts.deterministic = true; opts.collect = true; opts.maxDecisions = Inf;
% Seeds are independent: parfor when a pool is open (same result, faster).
if useParallel(c,n)
    parfor i = 1:n
        [resultCells{i},traj] = landing2d.rl.rolloutEpisodeV2(agent,c,seeds(i),opts);
        returns(i) = traj.return; markerUpdateRate(i) = traj.captureRate;
        finalPolicyInputs{i} = traj.state(:,max(traj.count,1):traj.count);
    end
else
    for i = 1:n
        [resultCells{i},traj] = landing2d.rl.rolloutEpisodeV2(agent,c,seeds(i),opts);
        returns(i) = traj.return; markerUpdateRate(i) = traj.captureRate;
        finalPolicyInputs{i} = traj.state(:,max(traj.count,1):traj.count);
    end
end
results = [resultCells{:}];
reasons = {results.terminalReason};
success = strcmp(reasons,'SUCCESS');
unsafe = ismember(reasons,{'UNSAFE_CONTACT','UNAUTHORIZED_CONTACT', ...
    'MISSED_PAD_CONTACT','SAFETY_ENVELOPE_VIOLATION'});
meanReturn = mean(returns);
[selectionScore,outcomeRates] = landing2d.rl.selectionScoreV2(reasons,returns);
info = struct('returns',returns,'captureRate',markerUpdateRate,'landed',success, ...
    'landingTime',[results.landingTime],'landingRate',mean(success), ...
    'meanCaptureRate',mean(markerUpdateRate),'meanReturn',meanReturn, ...
    'selectionScore',selectionScore,'unsafeRate',mean(unsafe), ...
    'safeAbortRate',mean(strcmp(reasons,'SAFE_ABORT')), ...
    'timeoutRate',mean(strcmp(reasons,'TASK_TIMEOUT')), ...
    'outcomeRates',outcomeRates,'nodeMean',[],'edgeAttentionMean',[], ...
    'graphSchema',struct());
if strcmp(agent.encoderSpec.mode,'baseline'), return; end
% Graph arms: the agent's own typed graph (canonical or relation-shuffled).
schema = agent.encoderSpec.schema;
firstNodeFeature = nan(schema.nNodes,n); edgeAttention = nan(numel(schema.src),n);
for i = 1:n
    if isempty(finalPolicyInputs{i}), continue; end
    X = reshape(finalPolicyInputs{i},schema.inDim,schema.nNodes);
    firstNodeFeature(:,i) = X(1,:)';
    [~,cache] = landing2d.graphstate.encoderForward(agent.policy.encoder, ...
        agent.encoderSpec,finalPolicyInputs{i},'policy');
    edgeAttention(:,i) = cache.cache1.alpha(:,1);
end
info.nodeMean = mean(firstNodeFeature,2,'omitnan');
info.edgeAttentionMean = mean(edgeAttention,2,'omitnan');
info.graphSchema = schema;
end

function tf = useParallel(c,count)
tf = count > 1 && isfield(c.rl,'parallelEpisodes') && c.rl.parallelEpisodes ...
    && ~isempty(ver('parallel')) && ~isempty(gcp('nocreate'));
end
