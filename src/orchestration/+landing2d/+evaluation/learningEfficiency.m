function out = learningEfficiency(runs,c)
% LEARNINGEFFICIENCY  Sample efficiency from the training histories (validation split).
%   out = landing2d.evaluation.learningEfficiency(runs,c)
% During PPO every run is evaluated on the same validation-split episodes
% every rl.evaluateEvery updates (landing2d.rl.ppoTrain). x = cumulative
% environment decisions (interactions), y = validation landing rate.
%   StepsTo<p>   first x with landing rate >= p (c.evaluation.learning.targets);
%                runs that never reach p are censored at their budget TotalSteps
%                and Reached<p> = 0 (report both)
%   AUC          area under the landing-rate curve / TotalSteps (0-1)
%   FinalValidationSuccess, BestValidationSuccess, SelectedIteration
%   LateGain     plateau check: mean landing rate over the last
%                plateauFraction of the evaluations minus the mean over the
%                plateauFraction before them (near 0 = the curve has levelled
%                off within the budget; clearly positive = still improving)
% The validation split also selects the checkpoint; these numbers describe
% learning speed, they are not held-out performance.
% curves also carry the training-window diagnostics recorded by
% landing2d.rl.ppoTrain (return, landing rate, episode length, losses,
% entropy, approximate KL, clip fraction, gradient norms) when present.
targets = c.evaluation.learning.targets;
diagnostics = {'trainReturn','TrainReturn';'trainLandingRate','TrainLandingRate'; ...
    'trainEpisodeLength','TrainEpisodeLength';'policyLoss','PolicyLoss';'valueLoss','ValueLoss'; ...
    'entropy','Entropy';'approxKL','ApproxKL';'clipFraction','ClipFraction'; ...
    'policyHeadGradNorm','ActorHeadGradNorm';'policyEncoderGradNorm','ActorEncoderGradNorm'; ...
    'valueHeadGradNorm','CriticHeadGradNorm';'valueEncoderGradNorm','CriticEncoderGradNorm'};
curves = {}; rows = {};
for r = 1:numel(runs)
    h = runs(r).history;
    if isempty(h) || ~isfield(h,'environmentSteps'), continue; end
    x = double([h.environmentSteps]); y = double([h.landingRate]);
    curve = table(repmat(string(runs(r).id),numel(x),1), ...
        repmat(string(runs(r).label),numel(x),1),repmat(runs(r).trainSeed,numel(x),1), ...
        double([h.iteration])',x',y',double([h.score])', ...
        'VariableNames',{'MethodId','Method','TrainSeed','Iteration', ...
        'EnvironmentSteps','ValidationSuccess','ValidationReturn'});
    for k = 1:size(diagnostics,1)
        value = nan(numel(x),1);
        if isfield(h,diagnostics{k,1}), value = double([h.(diagnostics{k,1})])'; end
        curve.(diagnostics{k,2}) = value;
    end
    curves{end+1} = curve; %#ok<AGROW>
    total = max(x(end),1);
    row = table(string(runs(r).id),string(runs(r).label),runs(r).trainSeed,total, ...
        'VariableNames',{'MethodId','Method','TrainSeed','TotalSteps'});
    for p = targets
        index = find(y>=p,1,'first');
        tag = sprintf('%02d',round(100*p));
        if isempty(index)
            row.(['StepsTo',tag]) = total; row.(['Reached',tag]) = 0;
        else
            row.(['StepsTo',tag]) = x(index); row.(['Reached',tag]) = 1;
        end
    end
    row.AUC = trapz(x,y)/total;
    row.FinalValidationSuccess = y(end);
    row.BestValidationSuccess = max(y);
    selected = find([h.selected],1);
    row.SelectedIteration = NaN;
    if ~isempty(selected), row.SelectedIteration = h(selected).iteration; end
    row.LateGain = lateGain(y,c.evaluation.learning.plateauFraction);
    rows{end+1} = row; %#ok<AGROW>
end
R = vertcat(rows{:});
metrics = [arrayfun(@(p)sprintf('StepsTo%02d',round(100*p)),targets,'UniformOutput',false), ...
    arrayfun(@(p)sprintf('Reached%02d',round(100*p)),targets,'UniformOutput',false), ...
    {'AUC','FinalValidationSuccess','BestValidationSuccess','SelectedIteration','LateGain'}];
out = struct('curves',vertcat(curves{:}),'runs',R, ...
    'summary',landing2d.evaluation.seedSummary(R,{},metrics), ...
    'contrasts',landing2d.evaluation.methodContrasts(R,{},metrics), ...
    'metrics',{metrics},'targets',targets);
end

function gain = lateGain(y,fraction)
% Mean of the last FRACTION of the evaluations minus the mean of the FRACTION before.
n = numel(y); k = max(1,round(fraction*n));
gain = NaN;
if n < 2*k, return; end
gain = mean(y(n-k+1:n))-mean(y(n-2*k+1:n-k));
end
