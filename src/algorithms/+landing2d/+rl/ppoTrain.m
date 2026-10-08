function [agent,history,lastAgent,snapshots] = ppoTrain(agent,c,rs)
% PPOTRAIN  클리핑 목적함수 PPO. 초기 정책은 모방 학습 결과를 그대로 사용합니다.
% 평가 점수가 가장 좋은 정책을 보관해 마지막에 돌려줍니다.
% history에는 평가 시점까지의 누적 학습 전이 수(environmentSteps, 결정 단위),
% 에피소드 수, 경과 시간을 기록합니다. snapshots는 학습 진행에 따른 정책
% 일관성 평가용 중간 정책(평가 전용, c.consistency.trainingSnapshots개 내외)입니다.
rl = agent.rl;
directTraining = isfield(rl,'trainingRegime') ...
    && strcmp(rl.trainingRegime,'direct_ppo_v1');
snapshotCount = 0;
if isfield(c,'consistency') && isfield(c.consistency,'trainingSnapshots')
    snapshotCount = c.consistency.trainingSnapshots;
end
snapshots = struct('iteration',{},'environmentSteps',{},'episodes',{}, ...
    'wallSeconds',{},'agent',{});
environmentSteps = 0; episodes = 0; wall = tic;
gs = c.graphState;
nCases = size(c.scenarioSpeeds,1);
% Per-episode training draws (environment seed, case) use their own stream when
% rl.episodeStreamSeedOffset is set (planar contract), so every method with the
% same training seed trains on the same episode sequence; minibatch shuffles,
% whose length depends on each policy's episode lengths, keep using RS.
episodeRs = rs;
if isfield(rl,'episodeStreamSeedOffset')
    episodeRs = RandStream('threefry','Seed',rl.seed+rl.episodeStreamSeedOffset);
end
% 망 본체와 그래프 부호기는 Adam 상태를 따로 둡니다. 학습률이 다르기 때문입니다.
% 기준 모델에서는 부호기가 비어 있어 아래 두 줄이 아무 일도 하지 않고,
% 본체 쪽 갱신은 부호기를 넣기 전과 완전히 같습니다.
policyState = landing2d.util.adamInit(policyCore(agent));
valueState = landing2d.util.adamInit(valueCore(agent));
policyEncoderState = landing2d.util.adamInit(agent.policy.encoder);
valueEncoderState = landing2d.util.adamInit(agent.value.encoder);
best = agent;
lastAgent = agent;
% 조기 종료: 평가 점수가 patience회 연속 나아지지 않으면 멈춥니다.
% 최고 점수의 정책은 따로 보관하므로 멈추어도 돌려주는 정책은 달라지지 않습니다.
patience = 0;
if isfield(rl,'earlyStopPatience')
    patience = rl.earlyStopPatience;
end
stagnant = 0;
windowReturnSum = 0;
windowSuccessCount = 0;
windowAbortCount = 0;
windowEpisodeCount = 0;
windowNominalSuccessCount = 0;
windowNominalEpisodeCount = 0;
windowCurrentSuccessCount = 0;
windowCurrentEpisodeCount = 0;
curriculumLevel = NaN;
if ~directTraining && strcmp(rl.curriculumMode,'performance')
    curriculumLevel = 0;
end
curriculumSuccessStreak = 0;
[~,bestScore,bestInfo] = landing2d.rl.evaluate(agent,c);
bestSelectionScore = -Inf;
bestFound = false;
bestHistoryIndex = NaN;
initialEligible = landing2d.rl.checkpointEligible(rl,curriculumLevel);
if initialEligible
    bestSelectionScore = bestInfo.selectionScore;
    bestFound = true;
    bestHistoryIndex = 1;
end
history = struct('iteration',0,'score',bestScore, ...
    'selectionScore',bestInfo.selectionScore, ...
    'landingRate',bestInfo.landingRate,'captureRate',bestInfo.meanCaptureRate, ...
    'unsafeRate',infoRate(bestInfo,'unsafeRate'), ...
    'safeAbortRate',infoRate(bestInfo,'safeAbortRate'), ...
    'timeoutRate',infoRate(bestInfo,'timeoutRate'), ...
    'trainReturn',NaN,'trainLandingRate',NaN,'trainNominalLandingRate',NaN, ...
    'trainCurriculumLandingRate',NaN, ...
    'trainSafeAbortRate',NaN, ...
    'curriculumLevel',curriculumLevel, ...
    'graphAdaptation',false, ...
    'checkpointEligible',initialEligible,'selected',false, ...
    'nodeMean',bestInfo.nodeMean, ...
    'nodeVariance',bestInfo.nodeVariance, ...
    'edgeAttentionMean',bestInfo.edgeAttentionMean, ...
    'graphSchema',bestInfo.graphSchema, ...
    'environmentSteps',0,'episodes',0,'wallSeconds',0);
if snapshotCount > 0
    snapshots(end+1) = struct('iteration',0,'environmentSteps',0,'episodes',0, ...
        'wallSeconds',0,'agent',agent);
end
notifyDashboard(c,history(end),rl.ppoIterations);
if rl.verbose
    fprintf(['  [BC] return %8.2f | select %8.2f | landing %3.0f%%' ...
        ' | capture %3.0f%%\n'],bestScore,bestInfo.selectionScore, ...
        100*bestInfo.landingRate,100*bestInfo.meanCaptureRate);
end
for iteration = 1:rl.ppoIterations
    if isfinite(curriculumLevel)
        curriculumLevel = max(curriculumLevel, ...
            landing2d.rl.curriculumFloor(rl,iteration));
    end
    state = cell(rl.episodesPerIteration,1);
    command = cell(rl.episodesPerIteration,1);
    logProbability = cell(rl.episodesPerIteration,1);
    advantage = cell(rl.episodesPerIteration,1);
    target = cell(rl.episodesPerIteration,1);
    episodeReturn = zeros(rl.episodesPerIteration,1);
    episodeSuccess = false(rl.episodesPerIteration,1);
    episodeAbort = false(rl.episodesPerIteration,1);
    % 에피소드별 난수 흐름을 미리 뽑습니다. 직렬/병렬 어느 쪽으로 돌려도 같은
    % 흐름을 쓰므로 rl.parallelEpisodes는 결과를 바꾸지 않고 속도만 바꿉니다.
    episodeSeed = randi(episodeRs,intmax('int32'),rl.episodesPerIteration,1);
    episodeCase = randi(episodeRs,nCases,rl.episodesPerIteration,1);
    if directTraining
        episodeCurriculum = ones(rl.episodesPerIteration,1);
    else
        episodeCurriculum = landing2d.rl.curriculumBatchLevels(rl, ...
            curriculumLevel,rl.episodesPerIteration);
    end
    if rl.parallelEpisodes
        parfor e = 1:rl.episodesPerIteration
            [state{e},command{e},logProbability{e},advantage{e}, ...
                target{e},episodeReturn(e),episodeSuccess(e),episodeAbort(e)] = ...
                collectEpisode(agent,c,rl, ...
                episodeCase(e),episodeSeed(e),iteration,episodeCurriculum(e), ...
                curriculumLevel);
        end
    else
        for e = 1:rl.episodesPerIteration
            [state{e},command{e},logProbability{e},advantage{e}, ...
                target{e},episodeReturn(e),episodeSuccess(e),episodeAbort(e)] = ...
                collectEpisode(agent,c,rl, ...
                episodeCase(e),episodeSeed(e),iteration,episodeCurriculum(e), ...
                curriculumLevel);
        end
    end
    windowReturnSum = windowReturnSum+sum(episodeReturn);
    windowSuccessCount = windowSuccessCount+sum(episodeSuccess);
    windowAbortCount = windowAbortCount+sum(episodeAbort);
    windowEpisodeCount = windowEpisodeCount+numel(episodeReturn);
    nominalMask = episodeCurriculum >= 1-1e-12;
    windowNominalSuccessCount = windowNominalSuccessCount+ ...
        sum(episodeSuccess(nominalMask));
    windowNominalEpisodeCount = windowNominalEpisodeCount+sum(nominalMask);
    currentMask = abs(episodeCurriculum-curriculumLevel)<1e-12;
    windowCurrentSuccessCount = windowCurrentSuccessCount+ ...
        sum(episodeSuccess(currentMask));
    windowCurrentEpisodeCount = windowCurrentEpisodeCount+sum(currentMask);
    X = [state{:}];
    U = [command{:}];
    oldLogProbability = [logProbability{:}];
    A = [advantage{:}];
    R = [target{:}];
    A = (A-mean(A))/(std(A)+1e-8);
    n = size(X,2);
    environmentSteps = environmentSteps+n;
    episodes = episodes+rl.episodesPerIteration;
    updatePolicy = iteration > rl.valueWarmup;
    gsUpdate = gs;
    gsUpdate.enableGraphAdaptation = directTraining || iteration > ceil( ...
        gs.graphAdaptationWarmupFraction*rl.ppoIterations);
    for epoch = 1:rl.ppoEpochs
        order = randperm(rs,n);
        for start = 1:rl.miniBatch:n
            index = order(start:min(start+rl.miniBatch-1,n));
            if updatePolicy
                [agent,policyState,policyEncoderState] = policyStep(agent, ...
                    policyState,policyEncoderState,X(:,index),U(:,index), ...
                    oldLogProbability(index),A(index),rl,gsUpdate);
            end
            [agent,valueState,valueEncoderState] = valueStep(agent,valueState, ...
                valueEncoderState,X(:,index),R(index),rl,gsUpdate);
        end
    end
    % Running input statistics follow the collected policy states. They are
    % updated after this iteration's update, so collection and update share
    % the same normalization, and frozen while the raw path is preserved.
    if isfield(agent,'inputNorm') && ~shouldPreserveRaw(gsUpdate,agent.encoderSpec)
        agent.inputNorm = landing2d.rl.updateInputNorm(agent.inputNorm, ...
            X(1:agent.encoderSpec.stateDim,:));
    end
    isLast = iteration == rl.ppoIterations;
    if mod(iteration,rl.evaluateEvery) == 0 || isLast
        trainReturn = windowReturnSum/max(windowEpisodeCount,1);
        trainLandingRate = windowSuccessCount/max(windowEpisodeCount,1);
        trainNominalLandingRate = NaN;
        if windowNominalEpisodeCount>0
            trainNominalLandingRate = windowNominalSuccessCount/ ...
                windowNominalEpisodeCount;
        end
        trainCurriculumLandingRate = windowCurrentSuccessCount/ ...
            max(windowCurrentEpisodeCount,1);
        trainSafeAbortRate = windowAbortCount/max(windowEpisodeCount,1);
        [~,score,info] = landing2d.rl.evaluate(agent,c);
        history(end+1) = struct('iteration',iteration,'score',score, ...
            'selectionScore',info.selectionScore, ...
            'landingRate',info.landingRate,'captureRate',info.meanCaptureRate, ...
            'unsafeRate',infoRate(info,'unsafeRate'), ...
            'safeAbortRate',infoRate(info,'safeAbortRate'), ...
            'timeoutRate',infoRate(info,'timeoutRate'), ...
            'trainReturn',trainReturn, ...
            'trainLandingRate',trainLandingRate, ...
            'trainNominalLandingRate',trainNominalLandingRate, ...
            'trainCurriculumLandingRate',trainCurriculumLandingRate, ...
            'trainSafeAbortRate',trainSafeAbortRate, ...
            'curriculumLevel',curriculumLevel, ...
            'graphAdaptation',gsUpdate.enableGraphAdaptation, ...
            'checkpointEligible',landing2d.rl.checkpointEligible( ...
                rl,curriculumLevel),'selected',false, ...
            'nodeMean',info.nodeMean, ...
            'nodeVariance',info.nodeVariance, ...
            'edgeAttentionMean',info.edgeAttentionMean, ...
            'graphSchema',info.graphSchema, ...
            'environmentSteps',environmentSteps,'episodes',episodes, ...
            'wallSeconds',toc(wall)); %#ok<AGROW>
        if snapshotCount > 0 && (isLast || floor(iteration*snapshotCount/rl.ppoIterations) ...
                > floor(snapshots(end).iteration*snapshotCount/rl.ppoIterations))
            snapshots(end+1) = struct('iteration',iteration, ...
                'environmentSteps',environmentSteps,'episodes',episodes, ...
                'wallSeconds',toc(wall),'agent',agent); %#ok<AGROW>
        end
        notifyDashboard(c,history(end),rl.ppoIterations);
        eligible = history(end).checkpointEligible;
        requiredImprovement = 0;
        if gsUpdate.enableGraphAdaptation ...
                && strcmp(agent.encoderSpec.readout,'raw_plus_groups')
            requiredImprovement = gs.graphSelectionMargin;
        end
        if eligible && (~bestFound || info.selectionScore > ...
                bestSelectionScore+requiredImprovement)
            bestScore = score;
            bestSelectionScore = info.selectionScore;
            best = agent;
            bestFound = true;
            bestHistoryIndex = numel(history);
            stagnant = 0;
        elseif eligible
            stagnant = stagnant+1;
        end
        if rl.verbose
            fprintf(['  [%2d/%2d] train %8.2f | eval %8.2f | select %8.2f' ...
                ' | train land %3.0f%% | current %3.0f%% | nominal %3.0f%%' ...
                ' | abort %3.0f%%' ...
                ' | eval land %3.0f%% | unsafe %3.0f%% | capture %3.0f%%' ...
                ' | curriculum %3.0f%%\n'], ...
                iteration,rl.ppoIterations, ...
                trainReturn,score,info.selectionScore,100*trainLandingRate, ...
                100*trainCurriculumLandingRate, ...
                100*trainNominalLandingRate,100*trainSafeAbortRate, ...
                100*info.landingRate,100*infoRate(info,'unsafeRate'), ...
                100*info.meanCaptureRate,100*finiteOrOne(curriculumLevel));
        end
        if patience > 0 && stagnant >= patience
            if rl.verbose
                fprintf(['  조기 종료: 평가 %d회 연속으로 최고 점수를 넘지 ' ...
                    '못했습니다 (%d/%d 반복에서 중단).\n'], ...
                    stagnant,iteration,rl.ppoIterations);
            end
            break;
        end
        if isfinite(curriculumLevel)
            [curriculumLevel,curriculumSuccessStreak] = ...
                landing2d.rl.advanceCurriculumLevel(rl,curriculumLevel, ...
                trainCurriculumLandingRate,curriculumSuccessStreak);
        end
        windowReturnSum = 0;
        windowSuccessCount = 0;
        windowAbortCount = 0;
        windowEpisodeCount = 0;
        windowNominalSuccessCount = 0;
        windowNominalEpisodeCount = 0;
        windowCurrentSuccessCount = 0;
        windowCurrentEpisodeCount = 0;
    end
end
if ~bestFound
    % Short diagnostics can end before reaching nominal difficulty. Return
    % the latest policy instead of silently restoring the easy initial one.
    best = agent;
    bestScore = score;
    bestSelectionScore = info.selectionScore;
    bestHistoryIndex = numel(history);
end
history(bestHistoryIndex).selected = true;
% Optional third output for guarded relation-only adaptation.  The usual
% return remains the best validation checkpoint, while callers that must
% calibrate a relational candidate against a frozen anchor can inspect the
% final trained candidate without weakening normal checkpoint selection.
lastAgent = agent;
best.trainingSelection = struct('iteration',history(bestHistoryIndex).iteration, ...
    'curriculumLevel',history(bestHistoryIndex).curriculumLevel, ...
    'selectionScore',bestSelectionScore, ...
    'checkpointEligible',history(bestHistoryIndex).checkpointEligible);
agent = best;
if rl.verbose
    fprintf('  선택한 정책: return %.2f | event-aware score %.2f\n', ...
        bestScore,bestSelectionScore);
end
end

function notifyDashboard(c,item,maxIteration)
if ~isfield(c,'showLiveDashboard') || ~c.showLiveDashboard ...
        || ~isfield(c,'figureVisible') || ~c.figureVisible
    return;
end
label = c.graphState.stateRepresentation;
if isfield(c,'dashboardAgentLabel') && ~isempty(c.dashboardAgentLabel)
    label = c.dashboardAgentLabel;
end
payload = struct('label',label,'iteration',item.iteration, ...
    'maxIteration',maxIteration,'score',item.score, ...
    'selectionScore',item.selectionScore, ...
    'trainReturn',item.trainReturn,'trainLandingRate',item.trainLandingRate, ...
    'trainNominalLandingRate',item.trainNominalLandingRate, ...
    'trainCurriculumLandingRate',item.trainCurriculumLandingRate, ...
    'trainSafeAbortRate',item.trainSafeAbortRate, ...
    'curriculumLevel',item.curriculumLevel, ...
    'landingRate',item.landingRate, ...
    'unsafeRate',item.unsafeRate,'safeAbortRate',item.safeAbortRate, ...
    'timeoutRate',item.timeoutRate, ...
    'captureRate',item.captureRate,'nodeMean',item.nodeMean, ...
    'nodeVariance',item.nodeVariance, ...
    'edgeAttentionMean',item.edgeAttentionMean, ...
    'graphSchema',item.graphSchema);
landing2d.viz.liveDashboard('training',payload);
end

% ------------------------------------------------------------ 정책 갱신 한 단계
% PPO 목적함수는 그대로입니다. 달라진 것은 망이 받는 것이 관측 벡터가 아니라
% PolicyNode 임베딩이라는 점, 그리고 기울기가 부호기까지 이어진다는 점뿐입니다.
function [agent,state,encoderState] = policyStep(agent,state,encoderState, ...
    X,U,oldLogProbability,A,rl,gs)
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.policy.encoder, ...
    agent.encoderSpec,X,'policy');
hasRelation = isfield(agent.policy,'relation');
if hasRelation
    raw = g(1:agent.encoderSpec.stateDim,:);
    context = g(agent.encoderSpec.stateDim+1:end,:);
    [mu,cache] = landing2d.rl.mlpForward(agent.policy.mean, ...
        landing2d.rl.mlpInput(agent,raw));
    [relationResidual,relationSlope] = ...
        landing2d.rl.relationPolicyResidual(agent.policy.relation.W, ...
        agent.encoderSpec,raw,context);
    mu = mu+relationResidual;
else
    [mu,cache] = landing2d.rl.mlpForward(agent.policy.mean, ...
        landing2d.rl.mlpInput(agent,g));
end
sigma = exp(agent.policy.logStd);
z = (U-mu)./sigma;
logProbability = sum(-0.5*z.^2-agent.policy.logStd-0.5*log(2*pi),1);
ratio = exp(logProbability-oldLogProbability);
clipped = min(max(ratio,1-rl.clipRatio),1+rl.clipRatio);
unclippedSelected = (ratio.*A) <= (clipped.*A);
batch = numel(A);
% 클리핑된 표본은 기울기를 만들지 않음 (PPO 표준 구현).
dLogProbability = -(A.*ratio.*double(unclippedSelected))/batch;
dMu = dLogProbability.*(z./sigma);
[grads.mean,dBase] = landing2d.rl.mlpBackward(agent.policy.mean,cache,dMu);
if hasRelation
    dRelation = dMu.*relationSlope;
    grads.relation.W = dRelation*context';
    dG = [dBase;agent.policy.relation.W'*dRelation];
else
    dG = dBase;
end
grads.logStd = sum(dLogProbability.*(z.^2-1),2)-rl.entropyWeight;
if shouldPreserveRaw(gs,agent.encoderSpec)
    for layer = 1:numel(grads.mean.W), grads.mean.W{layer}(:) = 0; end
    for layer = 1:numel(grads.mean.b), grads.mean.b{layer}(:) = 0; end
    grads.logStd(:) = 0;
end
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
core = policyCore(agent);
coreBefore = core;
[core,state] = landing2d.util.adamUpdate(core,grads,state,rl.policyLearnRate);
if shouldPreserveRaw(gs,agent.encoderSpec)
    core.mean = coreBefore.mean;
    core.logStd = coreBefore.logStd;
end
agent.policy.mean = core.mean;
if isfield(core,'relation'), agent.policy.relation = core.relation; end
agent.policy.logStd = core.logStd;
agent.policy.logStd = max(agent.policy.logStd,rl.minimumLogStd);
[agent.policy.encoder,encoderState] = encoderStep(agent.policy.encoder, ...
    agent.encoderSpec,encoderCache,dG,encoderState,rl,gs);
end

% ------------------------------------------------------------ 가치망 갱신 한 단계
function [agent,state,encoderState] = valueStep(agent,state,encoderState,X,R,rl,gs)
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.value.encoder, ...
    agent.encoderSpec,X,'value');
hasRelation = isfield(agent.value,'relation');
if hasRelation
    raw = g(1:agent.encoderSpec.stateDim,:);
    context = g(agent.encoderSpec.stateDim+1:end,:);
    [prediction,cache] = landing2d.rl.mlpForward(agent.value.net, ...
        landing2d.rl.mlpInput(agent,raw));
    prediction = prediction+agent.value.relation.W*context;
else
    [prediction,cache] = landing2d.rl.mlpForward(agent.value.net, ...
        landing2d.rl.mlpInput(agent,g));
end
dValue = 2*(prediction-R)/numel(R);
[netGrads,dBase] = landing2d.rl.mlpBackward(agent.value.net,cache,dValue);
grads.net = netGrads;
if hasRelation
    grads.relation.W = dValue*context';
    dG = [dBase;agent.value.relation.W'*dValue];
else
    dG = dBase;
end
if shouldPreserveRaw(gs,agent.encoderSpec)
    for layer = 1:numel(grads.net.W), grads.net.W{layer}(:) = 0; end
    for layer = 1:numel(grads.net.b), grads.net.b{layer}(:) = 0; end
end
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
core = valueCore(agent);
coreBefore = core;
[core,state] = landing2d.util.adamUpdate(core,grads,state,rl.valueLearnRate);
if shouldPreserveRaw(gs,agent.encoderSpec)
    core.net = coreBefore.net;
end
agent.value.net = core.net;
if isfield(core,'relation'), agent.value.relation = core.relation; end
[agent.value.encoder,encoderState] = encoderStep(agent.value.encoder, ...
    agent.encoderSpec,encoderCache,dG,encoderState,rl,gs);
end

% ------------------------------------------- 그래프 부호기 갱신 한 단계 (공통)
function [params,state] = encoderStep(params,spec,cache,dG,state,rl,gs)
% 기준 모델에서는 params가 빈 구조체이므로 아무 일도 하지 않습니다.
if isempty(fieldnames(params))
    return;
end
grads = landing2d.graphstate.encoderBackward(params,spec,cache,dG);
if isfield(gs,'enableGraphAdaptation') && ~gs.enableGraphAdaptation ...
        && ismember(spec.mode,{'context_node_pool','context_gat','context_rgat'})
    names = fieldnames(grads);
    for i = 1:numel(names), grads.(names{i})(:) = 0; end
end
if gs.freezeStaticBackbone && ismember(spec.mode,{'context_gat','context_rgat'})
    % Invariant ontology transforms are pretrained once. Runtime-state
    % adaptation is confined to attention gates and the grouped readout.
    for name = {'E1','W0','b0'}
        if isfield(grads,name{1}), grads.(name{1})(:) = 0; end
    end
end
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
[params,state] = landing2d.util.adamUpdate(params,grads,state, ...
    gs.encoderLearnRate);
end

% ------------------------------- Adam이 다룰 정책 본체 파라미터 (부호기 제외)
function core = policyCore(agent)
core = struct('mean',agent.policy.mean,'logStd',agent.policy.logStd);
if isfield(agent.policy,'relation'), core.relation=agent.policy.relation; end
end

function core = valueCore(agent)
core = struct('net',agent.value.net);
if isfield(agent.value,'relation'), core.relation=agent.value.relation; end
end

function yes=shouldPreserveRaw(gs,spec)
yes = isfield(gs,'enableGraphAdaptation') && gs.enableGraphAdaptation ...
    && gs.preserveRawPolicyDuringGraphAdaptation ...
    && strcmp(spec.readout,'raw_plus_groups');
end

% ------------------------------------------------- 에피소드 하나 수집 (병렬 단위)
function [state,command,logProbability,advantage,target,episodeReturn, ...
    episodeSuccess,episodeAbort] = ...
    collectEpisode(agent,c,rl,index,seed,iteration,curriculumLevel,contractLevel)
% CONTRACTLEVEL: current curriculum level of the run; replay episodes take
% their touchdown/terminal contract from it (rl.curriculumReplayContract).
if nargin < 8, contractLevel = NaN; end
localRs = RandStream('threefry','Seed',seed);
if isfield(c,'experiment') && isfield(c.experiment,'enabled') && c.experiment.enabled
    directTraining = isfield(rl,'trainingRegime') ...
        && strcmp(rl.trainingRegime,'direct_ppo_v1');
    if directTraining
        episodeConfig = c;
        scenarioHeightRange = c.experiment.scenario.heightRange;
    else
        [episodeConfig,scenarioHeightRange] = landing2d.rl.trainingEpisodeConfig( ...
            c,iteration,curriculumLevel,contractLevel);
    end
    options = struct('deterministic',false,'collect',true,'rs',localRs, ...
        'scenarioHeightRange',scenarioHeightRange);
    if directTraining
        options.descentPrefix = [];
    else
        options.descentPrefix = descentPrefix(rl,curriculumLevel,seed);
    end
    [result,traj] = landing2d.rl.rolloutEpisodeV2(agent,episodeConfig,seed,options);
    if traj.count == 0
        % The episode ended during the reference-driver prefix: no policy data.
        state = zeros(agent.encoderSpec.stateDim,0); command = zeros(rl.actionDim,0);
        logProbability = zeros(1,0); advantage = zeros(1,0); target = zeros(1,0);
        episodeReturn = 0; episodeSuccess = false; episodeAbort = false;
        return;
    end
    [advantage,target] = landing2d.rl.computeAdvantage(traj,rl);
    state = traj.state;
    command = traj.command;
    logProbability = traj.logProbability;
    episodeReturn = traj.return;
    episodeSuccess=strcmp(result.terminalReason,'SUCCESS');
    episodeAbort=strcmp(result.terminalReason,'SAFE_ABORT');
    return;
end
heightRange = landing2d.rl.curriculumRange(rl,iteration);
[r,s] = landing2d.rl.makeEpisode(c,index,rl,localRs,heightRange);
options = struct('deterministic',false,'collect',true,'rs',localRs);
[~,traj] = landing2d.rl.rolloutEpisode(agent,r,s,c,options);
[advantage,target] = landing2d.rl.computeAdvantage(traj,rl);
state = traj.state;
command = traj.command;
logProbability = traj.logProbability;
episodeReturn = traj.return;
episodeSuccess=isfinite(r.landingTime);
episodeAbort=false;
end

function prefix = descentPrefix(rl,level,seed)
% Planar descent-prefix curriculum (training only): with probability
% p*(1-level), at least rl.descentPrefixMinProbability when set, a
% reference-driver prefix that hands over at a height in
% rl.descentPrefixHandoverRange or at a time drawn from
% rl.descentPrefixMaxTimeRange (10 s without it), whichever comes first. Time
% handovers start the policy from tracked, speed-matched states at altitude
% after the UGV acceleration; height handovers start it near touchdown. Its own
% stream leaves the policy-sampling stream untouched.
prefix = [];
if ~isfield(rl,'descentPrefixProbability') || ~isfinite(level), return; end
rs = RandStream('threefry','Seed',double(seed)+7919);
probability = rl.descentPrefixProbability*(1-min(max(level,0),1));
if isfield(rl,'descentPrefixMinProbability')
    probability = max(probability,rl.descentPrefixMinProbability);
end
if rand(rs) < probability
    range = rl.descentPrefixHandoverRange;
    handoverHeight = range(1)+(range(2)-range(1))*rand(rs);
    maxTime = 10;
    if isfield(rl,'descentPrefixMaxTimeRange')
        times = rl.descentPrefixMaxTimeRange;
        maxTime = times(1)+(times(2)-times(1))*rand(rs);
    end
    prefix = struct('handoverHeight',handoverHeight,'maxTime',maxTime);
end
end

function value = finiteOrOne(value)
if ~isfinite(value), value = 1; end
end

function value=infoRate(info,name)
if isfield(info,name), value=info.(name); else, value=NaN; end
end
