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
% The validation split also selects the checkpoint; these numbers describe
% learning speed, they are not held-out performance.
targets = c.evaluation.learning.targets;
curves = {}; rows = {};
for r = 1:numel(runs)
    h = runs(r).history;
    if isempty(h) || ~isfield(h,'environmentSteps'), continue; end
    x = double([h.environmentSteps]); y = double([h.landingRate]);
    curves{end+1} = table(repmat(string(runs(r).id),numel(x),1), ...
        repmat(string(runs(r).label),numel(x),1),repmat(runs(r).trainSeed,numel(x),1), ...
        double([h.iteration])',x',y',double([h.score])', ...
        'VariableNames',{'MethodId','Method','TrainSeed','Iteration', ...
        'EnvironmentSteps','ValidationSuccess','ValidationReturn'}); %#ok<AGROW>
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
    rows{end+1} = row; %#ok<AGROW>
end
R = vertcat(rows{:});
metrics = [arrayfun(@(p)sprintf('StepsTo%02d',round(100*p)),targets,'UniformOutput',false), ...
    arrayfun(@(p)sprintf('Reached%02d',round(100*p)),targets,'UniformOutput',false), ...
    {'AUC','FinalValidationSuccess','BestValidationSuccess','SelectedIteration'}];
out = struct('curves',vertcat(curves{:}),'runs',R, ...
    'summary',landing2d.evaluation.seedSummary(R,{},metrics), ...
    'contrasts',landing2d.evaluation.methodContrasts(R,{},metrics), ...
    'metrics',{metrics},'targets',targets);
end
