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
% window (return, landing rate, episode length), cumulative environment steps
% (decisions), episodes and wall time, selected = the returned checkpoint, and
% window means of the update diagnostics: actor surrogate loss, critic MSE,
% policy entropy, approximate KL, clip fraction and the pre-clip gradient
% norms of the actor/critic heads and encoders (encoder NaN for plain PPO).
% The diagnostics only read the update; they do not change it.
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
% Adam optimizer states (moments), not environment or policy-input states.
policyOptimizerState = landing2d.util.adamInit(policyCore(agent));
valueOptimizerState = landing2d.util.adamInit(valueCore(agent));
policyEncoderOptimizerState = landing2d.util.adamInit(agent.policy.encoder);
valueEncoderOptimizerState = landing2d.util.adamInit(agent.value.encoder);
patience = 0;
if isfield(rl,'earlyStopPatience'), patience = rl.earlyStopPatience; end
% Progress lines carry the run name (concurrent runs interleave output).
tag = '';
if isfield(c,'comparisonRun'), tag = [c.comparisonRun.runName,' ']; end
environmentSteps = 0; episodes = 0; wall = tic; evaluationsWithoutImprovement = 0;
stopReason = 'budget';
window = emptyWindow();
% validationReturn: mean episode return on the validation episodes;
% info.selectionScore: the outcome-ordered score that selects the checkpoint.
[~,validationReturn,info] = landing2d.rl.evaluateV2(agent,c,[]);
history = historyRow(0,validationReturn,info,NaN,NaN,0,0,0,windowDiagnostics(window));
best = agent; bestValidationReturn = validationReturn;
bestSelectionScore = info.selectionScore; bestIndex = 1;
if rl.verbose
    fprintf('  %s[INIT] return %8.2f | select %8.2f | landing %3.0f%%\n', ...
        tag,validationReturn,info.selectionScore,100*info.landingRate);
end
for iteration = 1:rl.ppoIterations
    episodeSeed = randi(episodeRs,seedRange,rl.episodesPerIteration,1);
    episodePolicyInput = cell(rl.episodesPerIteration,1); episodePreTanhAction = episodePolicyInput;
    episodeLogProbability = episodePolicyInput; episodeAdvantage = episodePolicyInput;
    episodeValueTarget = episodePolicyInput;
    episodeReturn = zeros(rl.episodesPerIteration,1);
    episodeSuccess = false(rl.episodesPerIteration,1);
    % Each episode uses its own seeded stream, so serial and parallel
    % collection give the same data (rl.parallelEpisodes changes speed only).
    if rl.parallelEpisodes
        parfor e = 1:rl.episodesPerIteration
            [episodePolicyInput{e},episodePreTanhAction{e},episodeLogProbability{e}, ...
                episodeAdvantage{e},episodeValueTarget{e},episodeReturn(e), ...
                episodeSuccess(e)] = collectEpisode(agent,c,rl,episodeSeed(e));
        end
    else
        for e = 1:rl.episodesPerIteration
            [episodePolicyInput{e},episodePreTanhAction{e},episodeLogProbability{e}, ...
                episodeAdvantage{e},episodeValueTarget{e},episodeReturn(e), ...
                episodeSuccess(e)] = collectEpisode(agent,c,rl,episodeSeed(e));
        end
    end
    window.returnSum = window.returnSum+sum(episodeReturn);
    window.success = window.success+sum(episodeSuccess);
    window.episodes = window.episodes+numel(episodeReturn);
    % Batch columns: policy input, pre-tanh action sample, its behaviour log
    % probability, GAE advantage (normalized below) and value target.
    policyInput = [episodePolicyInput{:}]; preTanhAction = [episodePreTanhAction{:}];
    oldLogProbability = [episodeLogProbability{:}];
    advantage = [episodeAdvantage{:}]; valueTarget = [episodeValueTarget{:}];
    advantage = (advantage-mean(advantage))/(std(advantage)+1e-8);
    n = size(policyInput,2);
    window.decisions = window.decisions+n;
    environmentSteps = environmentSteps+n;
    episodes = episodes+rl.episodesPerIteration;
    updatePolicy = iteration > rl.valueWarmup;
    for epoch = 1:rl.ppoEpochs
        order = randperm(rs,n);
        for start = 1:rl.miniBatch:n
            index = order(start:min(start+rl.miniBatch-1,n));
            if updatePolicy
                [agent,policyOptimizerState,policyEncoderOptimizerState,stats] = policyStep( ...
                    agent,policyOptimizerState,policyEncoderOptimizerState, ...
                    policyInput(:,index),preTanhAction(:,index),oldLogProbability(index), ...
                    advantage(index),rl,gs);
                window.policy = accumulate(window.policy,stats);
            end
            [agent,valueOptimizerState,valueEncoderOptimizerState,stats] = valueStep(agent, ...
                valueOptimizerState,valueEncoderOptimizerState,policyInput(:,index), ...
                valueTarget(index),rl,gs);
            window.value = accumulate(window.value,stats);
        end
    end
    isLast = iteration == rl.ppoIterations;
    if mod(iteration,rl.evaluateEvery) == 0 || isLast
        trainReturn = window.returnSum/max(window.episodes,1);
        trainLandingRate = window.success/max(window.episodes,1);
        [~,validationReturn,info] = landing2d.rl.evaluateV2(agent,c,[]);
        history(end+1) = historyRow(iteration,validationReturn,info,trainReturn,trainLandingRate, ...
            environmentSteps,episodes,toc(wall),windowDiagnostics(window)); %#ok<AGROW>
        if info.selectionScore > bestSelectionScore
            best = agent; bestValidationReturn = validationReturn;
            bestSelectionScore = info.selectionScore;
            bestIndex = numel(history); evaluationsWithoutImprovement = 0;
        else
            evaluationsWithoutImprovement = evaluationsWithoutImprovement+1;
        end
        if rl.verbose
            fprintf(['  %s[%3d/%3d] train %8.2f | land %3.0f%% | validation %8.2f | ' ...
                'select %8.2f | land %3.0f%% | unsafe %3.0f%% | timeout %3.0f%%\n'], ...
                tag,iteration,rl.ppoIterations,trainReturn,100*trainLandingRate,validationReturn, ...
                info.selectionScore,100*info.landingRate,100*info.unsafeRate, ...
                100*info.timeoutRate);
        end
        window = emptyWindow();
        if landing2d.rl.plateauReached(history,iteration,rl)
            stopReason = 'validation_plateau_v1';
            if rl.verbose
                fprintf('  %searly stop: last %d validations landed >= %.0f%% (%d/%d).\n', ...
                    tag,rl.earlyStop.window,100*rl.earlyStop.minimumLandingRate,iteration,rl.ppoIterations);
            end
            break;
        end
        if patience > 0 && evaluationsWithoutImprovement >= patience
            stopReason = 'patience';
            if rl.verbose
                fprintf('  early stop: no improvement in %d evaluations (%d/%d).\n', ...
                    evaluationsWithoutImprovement,iteration,rl.ppoIterations);
            end
            break;
        end
    end
end
history(bestIndex).selected = true;
best.trainingSelection = struct('iteration',history(bestIndex).iteration, ...
    'selectionScore',bestSelectionScore,'lastIteration',history(end).iteration, ...
    'stopReason',stopReason);
agent = best;
if rl.verbose
    fprintf('  %sselected update %d: validation return %.2f | selection score %.2f\n', ...
        tag,history(bestIndex).iteration,bestValidationReturn,bestSelectionScore);
end
end

function row = historyRow(iteration,validationReturn,info,trainReturn,trainLandingRate,steps, ...
    episodes,seconds,d)
% Persisted history field names are kept (checkpoint info.history and
% learning_curves.csv): score = validation mean return, captureRate = mean
% marker-update rate (landing2d.rl.evaluateV2).
row = struct('iteration',iteration,'score',validationReturn,'selectionScore',info.selectionScore, ...
    'landingRate',info.landingRate,'unsafeRate',info.unsafeRate, ...
    'timeoutRate',info.timeoutRate,'captureRate',info.meanCaptureRate, ...
    'trainReturn',trainReturn,'trainLandingRate',trainLandingRate, ...
    'trainEpisodeLength',d.episodeLength,'policyLoss',d.policyLoss,'valueLoss',d.valueLoss, ...
    'entropy',d.entropy,'approxKL',d.approxKL,'clipFraction',d.clipFraction, ...
    'policyHeadGradNorm',d.policyHeadGradNorm,'policyEncoderGradNorm',d.policyEncoderGradNorm, ...
    'valueHeadGradNorm',d.valueHeadGradNorm,'valueEncoderGradNorm',d.valueEncoderGradNorm, ...
    'nodeMean',info.nodeMean,'edgeAttentionMean',info.edgeAttentionMean, ...
    'environmentSteps',steps,'episodes',episodes,'wallSeconds',seconds,'selected',false);
end

% ------------------------------------------------------ update diagnostics
function w = emptyWindow()
w = struct('returnSum',0,'success',0,'episodes',0,'decisions',0, ...
    'policy',struct('count',0),'value',struct('count',0));
end

function acc = accumulate(acc,stats)
names = fieldnames(stats);
for i = 1:numel(names)
    if ~isfield(acc,names{i}), acc.(names{i}) = 0; end
    acc.(names{i}) = acc.(names{i})+stats.(names{i});
end
acc.count = acc.count+1;
end

function d = windowDiagnostics(w)
% Window means of the update diagnostics (NaN when nothing was updated).
d = struct('episodeLength',NaN, ...
    'policyLoss',windowMean(w.policy,'loss'),'valueLoss',windowMean(w.value,'loss'), ...
    'entropy',windowMean(w.policy,'entropy'),'approxKL',windowMean(w.policy,'approxKL'), ...
    'clipFraction',windowMean(w.policy,'clipFraction'), ...
    'policyHeadGradNorm',windowMean(w.policy,'headGradNorm'), ...
    'policyEncoderGradNorm',windowMean(w.policy,'encoderGradNorm'), ...
    'valueHeadGradNorm',windowMean(w.value,'headGradNorm'), ...
    'valueEncoderGradNorm',windowMean(w.value,'encoderGradNorm'));
if w.episodes > 0, d.episodeLength = w.decisions/w.episodes; end
end

function value = windowMean(acc,name)
value = NaN;
if acc.count > 0 && isfield(acc,name), value = acc.(name)/acc.count; end
end

% ------------------------------------------------------------ policy update
% The PPO objective is the same for every method (landing2d.rl.policyLossGradient);
% for graph arms the gradient continues into the encoder (encoderStep).
function [agent,optimizerState,encoderOptimizerState,stats] = policyStep(agent, ...
    optimizerState,encoderOptimizerState,policyInput,preTanhAction,oldLogProbability, ...
    advantage,rl,gs)
[grads,encoderGrads,stats] = landing2d.rl.policyLossGradient(agent,policyInput, ...
    preTanhAction,oldLogProbability,advantage,rl);
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
[core,optimizerState] = landing2d.util.adamUpdate(policyCore(agent),grads,optimizerState, ...
    rl.policyLearnRate);
agent.policy.mean = core.mean;
agent.policy.logStd = max(core.logStd,rl.minimumLogStd);
[agent.policy.encoder,encoderOptimizerState] = encoderStep(agent.policy.encoder, ...
    encoderGrads,encoderOptimizerState,rl,gs);
end

% ------------------------------------------------------------- value update
function [agent,optimizerState,encoderOptimizerState,stats] = valueStep(agent, ...
    optimizerState,encoderOptimizerState,policyInput,valueTarget,rl,gs)
[grads,encoderGrads,stats] = landing2d.rl.valueLossGradient(agent,policyInput,valueTarget);
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
[core,optimizerState] = landing2d.util.adamUpdate(valueCore(agent),grads,optimizerState, ...
    rl.valueLearnRate);
agent.value.net = core.net;
[agent.value.encoder,encoderOptimizerState] = encoderStep(agent.value.encoder, ...
    encoderGrads,encoderOptimizerState,rl,gs);
end

% --------------------------------------------------- graph encoder update
function [params,optimizerState] = encoderStep(params,grads,optimizerState,rl,gs)
% Plain PPO has an empty encoder: nothing to update.
if isempty(fieldnames(params)), return; end
grads = landing2d.util.clipGradient(grads,rl.maxGradNorm);
[params,optimizerState] = landing2d.util.adamUpdate(params,grads,optimizerState, ...
    gs.encoderLearnRate);
end

function core = policyCore(agent)
core = struct('mean',agent.policy.mean,'logStd',agent.policy.logStd);
end

function core = valueCore(agent)
core = struct('net',agent.value.net);
end

% ------------------------------------------------ one episode (parallel unit)
function [policyInput,preTanhAction,logProbability,advantage,valueTarget,episodeReturn, ...
    episodeSuccess] = collectEpisode(agent,c,rl,seed)
localRs = RandStream('threefry','Seed',seed);
options = struct('deterministic',false,'collect',true,'rs',localRs);
[result,traj] = landing2d.rl.rolloutEpisodeV2(agent,c,seed,options);
[advantage,valueTarget] = landing2d.rl.computeAdvantage(traj,rl);
policyInput = traj.state;           % policy input (traj.state, rollout_v2 field name)
preTanhAction = traj.command;       % pre-tanh Gaussian sample (traj.command)
logProbability = traj.logProbability;
episodeReturn = traj.return;
episodeSuccess = strcmp(result.terminalReason,'SUCCESS');
end
