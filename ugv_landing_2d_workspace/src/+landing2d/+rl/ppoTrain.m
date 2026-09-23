function [agent,history] = ppoTrain(agent,c,rs)
% PPOTRAIN  클리핑 목적함수 PPO. 초기 정책은 모방 학습 결과를 그대로 사용합니다.
% 평가 점수가 가장 좋은 정책을 보관해 마지막에 돌려줍니다.
rl = agent.rl;
gs = c.graphState;
nCases = size(c.scenarioSpeeds,1);
% 망 본체와 그래프 부호기는 Adam 상태를 따로 둡니다. 학습률이 다르기 때문입니다.
% 기준 모델에서는 부호기가 비어 있어 아래 두 줄이 아무 일도 하지 않고,
% 본체 쪽 갱신은 부호기를 넣기 전과 완전히 같습니다.
policyState = landing2d.util.adamInit(policyCore(agent));
valueState = landing2d.util.adamInit(agent.value.net);
policyEncoderState = landing2d.util.adamInit(agent.policy.encoder);
valueEncoderState = landing2d.util.adamInit(agent.value.encoder);
best = agent;
[~,bestScore,bestInfo] = landing2d.rl.evaluate(agent,c);
history = struct('iteration',0,'score',bestScore, ...
    'landingRate',bestInfo.landingRate,'captureRate',bestInfo.meanCaptureRate, ...
    'trainReturn',NaN);
if rl.verbose
    fprintf('  [BC] score %8.2f | landing %3.0f%% | capture %3.0f%%\n', ...
        bestScore,100*bestInfo.landingRate,100*bestInfo.meanCaptureRate);
end
for iteration = 1:rl.ppoIterations
    state = cell(rl.episodesPerIteration,1);
    command = cell(rl.episodesPerIteration,1);
    logProbability = cell(rl.episodesPerIteration,1);
    advantage = cell(rl.episodesPerIteration,1);
    target = cell(rl.episodesPerIteration,1);
    episodeReturn = zeros(rl.episodesPerIteration,1);
    heightRange = landing2d.rl.curriculumRange(rl,iteration);
    % 에피소드별 난수 흐름을 미리 뽑습니다. 직렬/병렬 어느 쪽으로 돌려도 같은
    % 흐름을 쓰므로 rl.parallelEpisodes는 결과를 바꾸지 않고 속도만 바꿉니다.
    episodeSeed = randi(rs,intmax('int32'),rl.episodesPerIteration,1);
    episodeCase = randi(rs,nCases,rl.episodesPerIteration,1);
    if rl.parallelEpisodes
        parfor e = 1:rl.episodesPerIteration
            [state{e},command{e},logProbability{e},advantage{e}, ...
                target{e},episodeReturn(e)] = collectEpisode(agent,c,rl, ...
                episodeCase(e),episodeSeed(e),heightRange);
        end
    else
        for e = 1:rl.episodesPerIteration
            [state{e},command{e},logProbability{e},advantage{e}, ...
                target{e},episodeReturn(e)] = collectEpisode(agent,c,rl, ...
                episodeCase(e),episodeSeed(e),heightRange);
        end
    end
    X = [state{:}];
    U = [command{:}];
    oldLogProbability = [logProbability{:}];
    A = [advantage{:}];
    R = [target{:}];
    A = (A-mean(A))/(std(A)+1e-8);
    n = size(X,2);
    updatePolicy = iteration > rl.valueWarmup;
    for epoch = 1:rl.ppoEpochs
        order = randperm(rs,n);
        for start = 1:rl.miniBatch:n
            index = order(start:min(start+rl.miniBatch-1,n));
            if updatePolicy
                [agent,policyState,policyEncoderState] = policyStep(agent, ...
                    policyState,policyEncoderState,X(:,index),U(:,index), ...
                    oldLogProbability(index),A(index),rl,gs);
            end
            [agent,valueState,valueEncoderState] = valueStep(agent,valueState, ...
                valueEncoderState,X(:,index),R(index),rl,gs);
        end
    end
    isLast = iteration == rl.ppoIterations;
    if mod(iteration,rl.evaluateEvery) == 0 || isLast
        [~,score,info] = landing2d.rl.evaluate(agent,c);
        history(end+1) = struct('iteration',iteration,'score',score, ...
            'landingRate',info.landingRate,'captureRate',info.meanCaptureRate, ...
            'trainReturn',mean(episodeReturn)); %#ok<AGROW>
        if score > bestScore
            bestScore = score;
            best = agent;
        end
        if rl.verbose
            fprintf(['  [%2d/%2d] train %8.2f | eval %8.2f | landing %3.0f%%' ...
                ' | capture %3.0f%%\n'],iteration,rl.ppoIterations, ...
                mean(episodeReturn),score,100*info.landingRate, ...
                100*info.meanCaptureRate);
        end
    end
end
agent = best;
if rl.verbose
    fprintf('  선택한 정책 점수: %.2f\n',bestScore);
end
end

% ------------------------------------------------------------ 정책 갱신 한 단계
% PPO 목적함수는 그대로입니다. 달라진 것은 망이 받는 것이 관측 벡터가 아니라
% 그래프 수준 표현 g_t라는 점, 그리고 기울기가 부호기까지 이어진다는 점뿐입니다.
function [agent,state,encoderState] = policyStep(agent,state,encoderState, ...
    X,U,oldLogProbability,A,rl,gs)
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.policy.encoder, ...
    agent.encoderSpec,X);
[mu,cache] = landing2d.rl.mlpForward(agent.policy.mean,g);
sigma = exp(agent.policy.logStd);
z = (U-mu)./sigma;
logProbability = sum(-0.5*z.^2-agent.policy.logStd-0.5*log(2*pi),1);
ratio = exp(logProbability-oldLogProbability);
clipped = min(max(ratio,1-rl.clipRatio),1+rl.clipRatio);
unclippedSelected = (ratio.*A) <= (clipped.*A);
batch = numel(A);
% 클리핑된 표본은 기울기를 만들지 않음 (PPO 표준 구현).
dLogProbability = -(A.*ratio.*double(unclippedSelected))/batch;
[grads.mean,dG] = landing2d.rl.mlpBackward(agent.policy.mean,cache, ...
    dLogProbability.*(z./sigma));
grads.logStd = sum(dLogProbability.*(z.^2-1),2)-rl.entropyWeight;
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
core = policyCore(agent);
[core,state] = landing2d.util.adamUpdate(core,grads,state,rl.policyLearnRate);
agent.policy.mean = core.mean;
agent.policy.logStd = core.logStd;
[agent.policy.encoder,encoderState] = encoderStep(agent.policy.encoder, ...
    agent.encoderSpec,encoderCache,dG,encoderState,rl,gs);
end

% ------------------------------------------------------------ 가치망 갱신 한 단계
function [agent,state,encoderState] = valueStep(agent,state,encoderState,X,R,rl,gs)
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.value.encoder, ...
    agent.encoderSpec,X);
[prediction,cache] = landing2d.rl.mlpForward(agent.value.net,g);
[grads,dG] = landing2d.rl.mlpBackward(agent.value.net,cache, ...
    2*(prediction-R)/numel(R));
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
[agent.value.net,state] = landing2d.util.adamUpdate(agent.value.net,grads, ...
    state,rl.valueLearnRate);
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
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
[params,state] = landing2d.util.adamUpdate(params,grads,state, ...
    gs.encoderLearnRate);
end

% ------------------------------- Adam이 다룰 정책 본체 파라미터 (부호기 제외)
function core = policyCore(agent)
core = struct('mean',agent.policy.mean,'logStd',agent.policy.logStd);
end

% ------------------------------------------------- 에피소드 하나 수집 (병렬 단위)
function [state,command,logProbability,advantage,target,episodeReturn] = ...
    collectEpisode(agent,c,rl,index,seed,heightRange)
localRs = RandStream('threefry','Seed',seed);
[r,s] = landing2d.rl.makeEpisode(c,index,rl,localRs,heightRange);
options = struct('deterministic',false,'collect',true,'rs',localRs);
[~,traj] = landing2d.rl.rolloutEpisode(agent,r,s,c,options);
[advantage,target] = landing2d.rl.computeAdvantage(traj,rl);
state = traj.state;
command = traj.command;
logProbability = traj.logProbability;
episodeReturn = traj.return;
end
