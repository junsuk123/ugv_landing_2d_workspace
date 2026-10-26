function [methods,contrasts] = summarize(bySeed,groups,metrics,pairs)
% SUMMARIZE Method means and paired seed contrasts of training-seed values.
% BYSEED has one row per (MethodId, TrainSeed, GROUPS...): the training seed is
% the unit; episodes or states are never counted as independent replicates.
% Intervals are two-sided 95% t intervals over seeds (descriptive; no gate).
keys = [{'MethodId'},groups];
[g,methods] = findgroups(bySeed(:,keys));
for m = metrics
    x = bySeed.(m{1});
    methods.([m{1},'_mean']) = splitapply(@(v)mean(v,'omitnan'),x,g);
    methods.([m{1},'_sd']) = splitapply(@(v)std(v,'omitnan'),x,g);
    methods.([m{1},'_n']) = splitapply(@(v)sum(isfinite(v)),x,g);
    methods.([m{1},'_ci95']) = halfWidth(methods.([m{1},'_sd']),methods.([m{1},'_n']));
end
rows = {};
if isempty(groups)
    levels = table(1,'VariableNames',{'All__'}); select = @(T,i)true(height(T),1);
else
    levels = unique(bySeed(:,groups),'rows');
    select = @(T,i)ismember(T(:,groups),levels(i,:));
end
for i = 1:height(levels)
    part = bySeed(select(bySeed,i),:);
    for p = 1:size(pairs,1)
        A = sortrows(part(part.MethodId==pairs{p,1},:),'TrainSeed');
        B = sortrows(part(part.MethodId==pairs{p,2},:),'TrainSeed');
        if isempty(A) || isempty(B), continue; end
        assert(isequal(A.TrainSeed,B.TrainSeed),'landing2d:BiasDiagnosticsPairs','Seeds must pair.');
        row = table(string(pairs{p,1}),string(pairs{p,2}), ...
            'VariableNames',{'MethodA','MethodB'});
        if ~isempty(groups), row = [levels(i,:),row]; end %#ok<AGROW>
        for m = metrics
            delta = A.(m{1})-B.(m{1}); ok = isfinite(delta);
            sd = std(delta(ok)); n = sum(ok); hw = halfWidth(sd,n);
            row.([m{1},'_delta']) = mean(delta(ok)); row.([m{1},'_ci95low']) = mean(delta(ok))-hw;
            row.([m{1},'_ci95high']) = mean(delta(ok))+hw; row.([m{1},'_positiveSeeds']) = sum(delta(ok)>0);
            row.([m{1},'_n']) = n;
        end
        rows{end+1} = row; %#ok<AGROW>
    end
end
contrasts = vertcat(rows{:});
end

function hw = halfWidth(sd,n)
hw = NaN(size(sd));
for k = 1:numel(sd)
    if n(k)>=2
        q = betaincinv(0.05,(n(k)-1)/2,0.5);          % two-sided 95% t quantile
        hw(k) = sqrt((n(k)-1)*(1-q)/q)*sd(k)/sqrt(n(k));
    end
end
end
