function R = runMeans(T,keys,metrics)
% RUNMEANS  One row per trained run (method x training seed) and key group.
%   R = landing2d.evaluation.runMeans(T,{'Cell'},{'Success','AimErrorRMS_m'})
% Each run is first summarized over its episodes (mean, NaN ignored), so that
% the training seed - not the episode - is the unit of the method comparison
% (landing2d.evaluation.seedSummary, methodContrasts). Episodes counts rows.
keys = cellstr(keys); metrics = cellstr(metrics);
groupVars = [keys,{'MethodId','Method','TrainSeed'}];
[g,G] = findgroups(T(:,groupVars));
R = G;
R.Episodes = splitapply(@numel,T.TrainSeed,g);
for k = 1:numel(metrics)
    R.(metrics{k}) = splitapply(@(x)meanFinite(x),double(T.(metrics{k})),g);
end
end

function m = meanFinite(x)
x = x(isfinite(x));
if isempty(x), m = NaN; else, m = mean(x); end
end
