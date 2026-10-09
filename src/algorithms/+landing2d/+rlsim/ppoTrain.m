function [agent,history,lastAgent] = ppoTrain(agent,c,rs)
% PPOTRAIN  Simulink 모델 + RL Toolbox rlPPOAgent로 하는 PPO 학습.
%
% landing2d.rl.ppoTrain과 입출력 계약이 같습니다(구조체 정책 입력, 검증 최고
% checkpoint·학습 이력·마지막 정책 출력). 에피소드 수집은 Simulink 모델의
% RL Agent 블록이, 정책 갱신은 rlPPOAgent가 합니다. 아래는 MATLAB 판과 같습니다.
%   - 학습 분포: TrainingEpisodeSource (커리큘럼, 쉬운·중간 재생, 하한 일정)
%   - 단계 학습: 가치 예열 -> raw semantic -> 관계 적응 (학습률 계수로 고정)
%   - 평가·선택: evaluateEvery 반복마다 landing2d.rl.evaluate 검증 점수,
%     공칭 커리큘럼 도달 뒤에만 선택, 관계 단계 선택 여유 graphSelectionMargin
% 한 번의 train() 호출이 평가 구간 하나(또는 단계 경계까지)를 학습합니다.
% rl.parallelEpisodes가 참이면 병렬 풀 워커들이 에피소드를 나눠 시뮬레이션합니다.
% 갱신 주기는 반복당 episodesPerIteration개 에피소드에 해당하는 결정 수로
% 맞추며, 직전 구간의 평균 에피소드 길이로 조정합니다.
rl = agent.rl;
gs = c.graphState;
settings = landing2d.rlsim.backendSettings(c);
template = agent;
episodesPerIteration = rl.episodesPerIteration;
maxSteps = ceil(c.experiment.maxMissionTime/c.experiment.policyDt)+1;
relational = isfield(agent.policy,'relation') ...
    && ismember(agent.encoderSpec.readout, ...
    {'raw_plus_groups','observation_plus_groups'});
warmupIteration = ceil(gs.graphAdaptationWarmupFraction*rl.ppoIterations);
if ~relational, warmupIteration = Inf; end

[env,model,workers] = landing2d.rlsim.environment(c);
source = landing2d.rlsim.TrainingEpisodeSource(c);
cleanup = onCleanup(@()landing2d.simulink.episodeServer('clear'));

[~,bestScore,bestInfo] = landing2d.rl.evaluate(agent,c);
best = agent;
bestSelectionScore = -Inf;
bestFound = false;
bestHistoryIndex = NaN;
initialEligible = landing2d.rl.checkpointEligible(rl,source.CurriculumLevel);
if initialEligible
    bestSelectionScore = bestInfo.selectionScore;
    bestFound = true;
    bestHistoryIndex = 1;
end
history = historyEntry(0,bestScore,bestInfo,emptyStats(), ...
    source.CurriculumLevel,false,initialEligible);
if rl.verbose
    fprintf(['  [Simulink %s, workers %d] init eval %8.2f | select %8.2f' ...
        ' | landing %3.0f%%\n'],model,workers,bestScore, ...
        bestInfo.selectionScore,100*bestInfo.landingRate);
end

horizon = episodesPerIteration*100;
stage = '';
toolbox = [];
iteration = 0;
outcomes = zeros(0,8);
windowTimer = tic;
patience = 0;
if isfield(rl,'earlyStopPatience'), patience = rl.earlyStopPatience; end
stagnant = 0;
while iteration < rl.ppoIterations
    wanted = stageFor(iteration+1,rl.valueWarmup,warmupIteration);
    stop = nextEvaluation(iteration,rl);
    stop = min([stop,boundaryAfter(iteration,rl.valueWarmup), ...
        boundaryAfter(iteration,warmupIteration)]);
    if ~strcmp(wanted,stage)
        if ~isempty(toolbox), agent = landing2d.rlsim.structAgent(toolbox,template); end
        toolbox = landing2d.rlsim.toolboxAgent(agent,c,wanted,horizon);
        stage = wanted;
    end
    toolbox = setHorizon(toolbox,horizon,rl);
    chunkSeed = randi(rs,intmax('int32'));
    attempt = 0;
    while true
        assignin('base','landing2dAgent',toolbox);
        source.beginChunk(iteration,stop,chunkSeed,workers);
        env.ResetFcn = @(in)landing2d.simulink.prepareEpisode(in,source);
        options = rlTrainingOptions('MaxEpisodes',(stop-iteration)*episodesPerIteration, ...
            'MaxStepsPerEpisode',maxSteps,'StopTrainingCriteria','none', ...
            'ScoreAveragingWindowLength',episodesPerIteration, ...
            'Plots','none','Verbose',false,'SaveAgentCriteria','none', ...
            'SimulationStorageType','memory','UseParallel',workers > 1);
        if workers > 1
            options.ParallelizationOptions.Mode = settings.parallelMode;
        end
        try
            result = train(toolbox,env,options);
            break;
        catch err
            % 몇 시간짜리 학습에서 병렬 워커가 끊기면 풀을 다시 열어 같은 구간을
            % 재시도하고, 그래도 실패하면 직렬로 계속합니다.
            if workers <= 1, rethrow(err); end
            attempt = attempt+1;
            delete(gcp('nocreate'));
            serial = attempt > settings.retries;
            warning('landing2d:SimulinkTrainingRetry', ...
                'Parallel Simulink training failed at iteration %d (%s). %s', ...
                iteration,err.message,ternary(serial,'Continuing serially.', ...
                'Restarting the pool and retrying.'));
            retryConfig = c;
            if serial, retryConfig.rl.parallelEpisodes = false; end
            [env,~,workers] = landing2d.rlsim.environment(retryConfig);
        end
    end
    chunk = collectOutcomes(result);
    outcomes = [outcomes;chunk]; %#ok<AGROW>
    if ~isempty(chunk), horizon = episodesPerIteration*mean(chunk(:,6)); end
    iteration = stop;
    source.raiseFloor(iteration);
    agent = landing2d.rlsim.structAgent(toolbox,template);
    if mod(iteration,rl.evaluateEvery) ~= 0 && iteration < rl.ppoIterations
        continue;
    end
    stats = source.windowStats(outcomes);
    outcomes = zeros(0,8);
    [~,score,info] = landing2d.rl.evaluate(agent,c);
    adaptation = strcmp(stage,'relation');
    eligible = landing2d.rl.checkpointEligible(rl,source.CurriculumLevel);
    history(end+1) = historyEntry(iteration,score,info,stats, ...
        source.CurriculumLevel,adaptation,eligible); %#ok<AGROW>
    required = 0;
    if adaptation, required = gs.graphSelectionMargin; end
    if eligible && (~bestFound || info.selectionScore > bestSelectionScore+required)
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
        fprintf(['  [%4d/%4d %-8s] train %8.2f | eval %8.2f | select %8.2f' ...
            ' | train land %3.0f%% | eval land %3.0f%% | unsafe %3.0f%%' ...
            ' | curriculum %3.0f%% | episodes %d | %.0f s\n'],iteration, ...
            rl.ppoIterations,stage,stats.trainReturn,score,info.selectionScore, ...
            100*stats.trainLandingRate,100*info.landingRate, ...
            100*info.unsafeRate,100*finiteOrOne(source.CurriculumLevel), ...
            stats.episodes,toc(windowTimer));
    end
    windowTimer = tic;
    if patience > 0 && stagnant >= patience, break; end
    source.advanceCurriculum(stats.trainCurriculumLandingRate);
end
if ~bestFound
    best = agent;
    bestSelectionScore = history(end).selectionScore;
    bestHistoryIndex = numel(history);
end
history(bestHistoryIndex).selected = true;
lastAgent = agent;
best.trainingSelection = struct('iteration',history(bestHistoryIndex).iteration, ...
    'curriculumLevel',history(bestHistoryIndex).curriculumLevel, ...
    'selectionScore',bestSelectionScore, ...
    'checkpointEligible',history(bestHistoryIndex).checkpointEligible, ...
    'trainingBackend','simulink','model',model);
agent = best;
clear cleanup
end

function outcomes = collectOutcomes(result)
% 에피소드별 SimulationOutput.episodeOutcome (마지막 결정 값)
info = result.SimulationInfo;
n = info.NumSimulations;
outcomes = nan(n,8);
for k = 1:n
    out = info(k);
    try
        value = out.episodeOutcome;
    catch
        value = [];
    end
    last = lastSample(double(value));
    if numel(last) == 8, outcomes(k,:) = last(:)'; end
end
outcomes = outcomes(all(isfinite(outcomes(:,[1 4 5 6])),2),:);
end

function last = lastSample(value)
% To Workspace 배열 형식은 [8 x 1 x 시간] 또는 [시간 x 8]입니다.
last = [];
if isempty(value), return; end
if ndims(value) == 3
    last = value(:,:,end);
elseif size(value,1) == 8 && size(value,2) == 1
    last = value;
elseif size(value,2) == 8
    last = value(end,:);
elseif size(value,1) == 8
    last = value(:,end);
end
last = last(:);
end

function stage = stageFor(iteration,valueWarmup,warmupIteration)
if iteration <= valueWarmup
    stage = 'value';
elseif iteration > warmupIteration
    stage = 'relation';
else
    stage = 'raw';
end
end

function stop = nextEvaluation(iteration,rl)
stop = min(rl.ppoIterations,(floor(iteration/rl.evaluateEvery)+1)*rl.evaluateEvery);
end

function stop = boundaryAfter(iteration,boundary)
% 단계가 바뀌는 반복 직전까지만 한 번에 학습합니다.
if isfinite(boundary) && iteration < boundary
    stop = boundary;
else
    stop = Inf;
end
end

function toolbox = setHorizon(toolbox,horizon,rl)
horizon = max(rl.miniBatch,round(horizon));
options = toolbox.AgentOptions;
options.ExperienceHorizon = horizon;
options.LearningFrequency = horizon;
options.MaxMiniBatchPerEpoch = ceil(horizon/rl.miniBatch);
toolbox.AgentOptions = options;
end

function stats = emptyStats()
stats = struct('trainReturn',NaN,'trainLandingRate',NaN, ...
    'trainNominalLandingRate',NaN,'trainCurriculumLandingRate',NaN, ...
    'trainSafeAbortRate',NaN,'episodes',0);
end

function entry = historyEntry(iteration,score,info,stats,level,adaptation,eligible)
entry = struct('iteration',iteration,'score',score, ...
    'selectionScore',info.selectionScore, ...
    'landingRate',info.landingRate,'captureRate',info.meanCaptureRate, ...
    'unsafeRate',info.unsafeRate,'safeAbortRate',info.safeAbortRate, ...
    'timeoutRate',info.timeoutRate,'trainReturn',stats.trainReturn, ...
    'trainLandingRate',stats.trainLandingRate, ...
    'trainNominalLandingRate',stats.trainNominalLandingRate, ...
    'trainCurriculumLandingRate',stats.trainCurriculumLandingRate, ...
    'trainSafeAbortRate',stats.trainSafeAbortRate, ...
    'curriculumLevel',level,'graphAdaptation',adaptation, ...
    'checkpointEligible',eligible,'selected',false, ...
    'nodeMean',info.nodeMean,'nodeVariance',info.nodeVariance, ...
    'edgeAttentionMean',info.edgeAttentionMean,'graphSchema',info.graphSchema);
end

function value = finiteOrOne(value)
if ~isfinite(value), value = 1; end
end

function value = ternary(condition,a,b)
if condition, value = a; else, value = b; end
end
