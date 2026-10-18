function [agent,history] = ppoTrain(agent,c,rs)
% PPOTRAIN  Clipped-objective PPO from random weights on the planar scenario family.
%   [agent,history] = landing2d.rl.ppoTrain(agent,c,rs)
% Identical for every compared method: the same episode sequence for the same
% training seed, the same loss (clipped surrogate + value MSE + entropy bonus),
% budget and validation schedule. Only the state representation differs
% (plain 12-D o_t or the R-GAT embedding of the same o_t; the encoder is
% trained by the same gradients).
% Every rl.evaluateEvery updates the deterministic policy flies the first
% experiment.validationEpisodeCount validation-split episodes
% (landing2d.rl.evaluateV2); the best selection score is returned (validation
% only - test, stress and fixed-case seeds never select a checkpoint).
% history: one row per evaluation with the validation outcome, the training
% window (return, landing rate), cumulative environment steps (decisions),
% episodes and wall time, and selected = the returned checkpoint.
rl = agent.rl;
assert(isfield(c,'experiment') && c.experiment.enabled && ...
    strcmp(rl.trainingRegime,'direct_ppo_v1'),'landing2d:TrainingRegime', ...
    'ppoTrain supports the planar direct-PPO contract only.');
assert(~isfield(agent.policy,'relation') && ~isfield(agent.value,'relation'), ...
    'landing2d:RelationResidual','Relation-residual heads are not part of this contract.');
gs = c.graphState;
% Episode environment seeds come from their own stream and the reserved
% training range, so methods with the same training seed see the same episodes
% however many samples each collects; minibatch shuffles use RS.
episodeRs = RandStream('threefry','Seed',rl.seed+rl.episodeStreamSeedOffset);
seedRange = double(c.experiment.manifest.trainEpisodeSeedRange);
policyState = landing2d.util.adamInit(policyCore(agent));
valueState = landing2d.util.adamInit(valueCore(agent));
policyEncoderState = landing2d.util.adamInit(agent.policy.encoder);
valueEncoderState = landing2d.util.adamInit(agent.value.encoder);
patience = 0;
if isfield(rl,'earlyStopPatience'), patience = rl.earlyStopPatience; end
environmentSteps = 0; episodes = 0; wall = tic; stagnant = 0;
window = struct('returnSum',0,'success',0,'episodes',0);
[~,score,info] = landing2d.rl.evaluateV2(agent,c,[]);
history = historyRow(0,score,info,NaN,NaN,0,0,0);
best = agent; bestScore = score; bestSelection = info.selectionScore; bestIndex = 1;
if rl.verbose
    fprintf('  [INIT] return %8.2f | select %8.2f | landing %3.0f%%\n', ...
        score,info.selectionScore,100*info.landingRate);
end
for iteration = 1:rl.ppoIterations
    episodeSeed = randi(episodeRs,seedRange,rl.episodesPerIteration,1);
    state = cell(rl.episodesPerIteration,1); command = state;
    logProbability = state; advantage = state; target = state;
    episodeReturn = zeros(rl.episodesPerIteration,1);
    episodeSuccess = false(rl.episodesPerIteration,1);
    % Each episode uses its own seeded stream, so serial and parallel
    % collection give the same data (rl.parallelEpisodes changes speed only).
    if rl.parallelEpisodes
        parfor e = 1:rl.episodesPerIteration
            [state{e},command{e},logProbability{e},advantage{e},target{e}, ...
                episodeReturn(e),episodeSuccess(e)] = collectEpisode(agent,c,rl,episodeSeed(e));
        end
    else
        for e = 1:rl.episodesPerIteration
            [state{e},command{e},logProbability{e},advantage{e},target{e}, ...
                episodeReturn(e),episodeSuccess(e)] = collectEpisode(agent,c,rl,episodeSeed(e));
        end
    end
    window.returnSum = window.returnSum+sum(episodeReturn);
    window.success = window.success+sum(episodeSuccess);
    window.episodes = window.episodes+numel(episodeReturn);
    X = [state{:}]; U = [command{:}]; oldLogProbability = [logProbability{:}];
    A = [advantage{:}]; R = [target{:}];
    A = (A-mean(A))/(std(A)+1e-8);
    n = size(X,2);
    environmentSteps = environmentSteps+n;
    episodes = episodes+rl.episodesPerIteration;
    updatePolicy = iteration > rl.valueWarmup;
    for epoch = 1:rl.ppoEpochs
        order = randperm(rs,n);
        for start = 1:rl.miniBatch:n
            index = order(start:min(start+rl.miniBatch-1,n));
            if updatePolicy
                [agent,policyState,policyEncoderState] = policyStep(agent,policyState, ...
                    policyEncoderState,X(:,index),U(:,index),oldLogProbability(index), ...
                    A(index),rl,gs);
            end
            [agent,valueState,valueEncoderState] = valueStep(agent,valueState, ...
                valueEncoderState,X(:,index),R(index),rl,gs);
        end
    end
    isLast = iteration == rl.ppoIterations;
    if mod(iteration,rl.evaluateEvery) == 0 || isLast
        trainReturn = window.returnSum/max(window.episodes,1);
        trainLandingRate = window.success/max(window.episodes,1);
        [~,score,info] = landing2d.rl.evaluateV2(agent,c,[]);
        history(end+1) = historyRow(iteration,score,info,trainReturn,trainLandingRate, ...
            environmentSteps,episodes,toc(wall)); %#ok<AGROW>
        if info.selectionScore > bestSelection
            best = agent; bestScore = score; bestSelection = info.selectionScore;
            bestIndex = numel(history); stagnant = 0;
        else
            stagnant = stagnant+1;
        end
        if rl.verbose
            fprintf(['  [%3d/%3d] train %8.2f | land %3.0f%% | validation %8.2f | ' ...
                'select %8.2f | land %3.0f%% | unsafe %3.0f%% | timeout %3.0f%%\n'], ...
                iteration,rl.ppoIterations,trainReturn,100*trainLandingRate,score, ...
                info.selectionScore,100*info.landingRate,100*info.unsafeRate, ...
                100*info.timeoutRate);
        end
        window = struct('returnSum',0,'success',0,'episodes',0);
        if patience > 0 && stagnant >= patience
            if rl.verbose
                fprintf('  early stop: no improvement in %d evaluations (%d/%d).\n', ...
                    stagnant,iteration,rl.ppoIterations);
            end
            break;
        end
    end
end
history(bestIndex).selected = true;
best.trainingSelection = struct('iteration',history(bestIndex).iteration, ...
    'selectionScore',bestSelection);
agent = best;
if rl.verbose
    fprintf('  selected update %d: validation return %.2f | selection score %.2f\n', ...
        history(bestIndex).iteration,bestScore,bestSelection);
end
end

function row = historyRow(iteration,score,info,trainReturn,trainLandingRate,steps,episodes,seconds)
row = struct('iteration',iteration,'score',score,'selectionScore',info.selectionScore, ...
    'landingRate',info.landingRate,'unsafeRate',info.unsafeRate, ...
    'timeoutRate',info.timeoutRate,'captureRate',info.meanCaptureRate, ...
    'trainReturn',trainReturn,'trainLandingRate',trainLandingRate, ...
    'nodeMean',info.nodeMean,'edgeAttentionMean',info.edgeAttentionMean, ...
    'environmentSteps',steps,'episodes',episodes,'wallSeconds',seconds,'selected',false);
end

% ------------------------------------------------------------ policy update
% The PPO objective is the same for every method; for graph arms the gradient
% continues into the encoder (encoderStep).
function [agent,state,encoderState] = policyStep(agent,state,encoderState, ...
    X,U,oldLogProbability,A,rl,gs)
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.policy.encoder, ...
    agent.encoderSpec,X,'policy');
[mu,cache] = landing2d.rl.mlpForward(agent.policy.mean,g);
sigma = exp(agent.policy.logStd);
z = (U-mu)./sigma;
logProbability = sum(-0.5*z.^2-agent.policy.logStd-0.5*log(2*pi),1);
ratio = exp(logProbability-oldLogProbability);
clipped = min(max(ratio,1-rl.clipRatio),1+rl.clipRatio);
unclippedSelected = (ratio.*A) <= (clipped.*A);
batch = numel(A);
% Clipped samples give no gradient (standard PPO).
dLogProbability = -(A.*ratio.*double(unclippedSelected))/batch;
dMu = dLogProbability.*(z./sigma);
[grads.mean,dG] = landing2d.rl.mlpBackward(agent.policy.mean,cache,dMu);
grads.logStd = sum(dLogProbability.*(z.^2-1),2)-rl.entropyWeight;
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
[core,state] = landing2d.util.adamUpdate(policyCore(agent),grads,state,rl.policyLearnRate);
agent.policy.mean = core.mean;
agent.policy.logStd = max(core.logStd,rl.minimumLogStd);
[agent.policy.encoder,encoderState] = encoderStep(agent.policy.encoder, ...
    agent.encoderSpec,encoderCache,dG,encoderState,rl,gs);
end

% ------------------------------------------------------------- value update
function [agent,state,encoderState] = valueStep(agent,state,encoderState,X,R,rl,gs)
[g,encoderCache] = landing2d.graphstate.encoderForward(agent.value.encoder, ...
    agent.encoderSpec,X,'value');
[prediction,cache] = landing2d.rl.mlpForward(agent.value.net,g);
dValue = 2*(prediction-R)/numel(R);
[grads.net,dG] = landing2d.rl.mlpBackward(agent.value.net,cache,dValue);
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
[core,state] = landing2d.util.adamUpdate(valueCore(agent),grads,state,rl.valueLearnRate);
agent.value.net = core.net;
[agent.value.encoder,encoderState] = encoderStep(agent.value.encoder, ...
    agent.encoderSpec,encoderCache,dG,encoderState,rl,gs);
end

% --------------------------------------------------- graph encoder update
function [params,state] = encoderStep(params,spec,cache,dG,state,rl,gs)
% Plain PPO has an empty encoder: nothing to update.
if isempty(fieldnames(params)), return; end
grads = landing2d.graphstate.encoderBackward(params,spec,cache,dG);
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
[params,state] = landing2d.util.adamUpdate(params,grads,state,gs.encoderLearnRate);
end

function core = policyCore(agent)
core = struct('mean',agent.policy.mean,'logStd',agent.policy.logStd);
end

function core = valueCore(agent)
core = struct('net',agent.value.net);
end

% ------------------------------------------------ one episode (parallel unit)
function [state,command,logProbability,advantage,target,episodeReturn,episodeSuccess] = ...
    collectEpisode(agent,c,rl,seed)
localRs = RandStream('threefry','Seed',seed);
options = struct('deterministic',false,'collect',true,'rs',localRs);
[result,traj] = landing2d.rl.rolloutEpisodeV2(agent,c,seed,options);
[advantage,target] = landing2d.rl.computeAdvantage(traj,rl);
state = traj.state;
command = traj.command;
logProbability = traj.logProbability;
episodeReturn = traj.return;
episodeSuccess = strcmp(result.terminalReason,'SUCCESS');
end
