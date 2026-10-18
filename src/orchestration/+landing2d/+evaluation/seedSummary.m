function S = seedSummary(R,keys,metrics)
% SEEDSUMMARY  Mean and 95% t interval over training seeds, per method and key group.
%   S = landing2d.evaluation.seedSummary(R,{'Cell'},{'Success'})
% R from landing2d.evaluation.runMeans (one row per run). For every metric M
% the table holds M (mean over seeds), M_sd, M_ci (half width) and M_n (seeds
% with a finite value). With one seed the interval is NaN: a single run gives
% no between-run variation, so it supports no method claim.
keys = cellstr(keys); metrics = cellstr(metrics);
groupVars = [keys,{'MethodId','Method'}];
[g,S] = findgroups(R(:,groupVars));
S.Seeds = splitapply(@numel,R.TrainSeed,g);
for k = 1:numel(metrics)
    x = double(R.(metrics{k}));
    [mu,sd,half,n] = splitapply(@landing2d.evaluation.tInterval,x,g);
    S.(metrics{k}) = mu; S.([metrics{k},'_sd']) = sd;
    S.([metrics{k},'_ci']) = half; S.([metrics{k},'_n']) = n;
end
S = orderMethods(S);
end

function S = orderMethods(S)
registry = landing2d.config.methodRegistry();
[~,order] = ismember(string(S.MethodId),string({registry.methods.id}));
[~,index] = sortrows([order(:),(1:height(S))'],[1,2]);
S = S(index,:);
end
