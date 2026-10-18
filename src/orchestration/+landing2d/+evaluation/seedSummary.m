function S = seedSummary(R,keys,metrics)
% SEEDSUMMARY  Mean and 95% t interval over training seeds, per method and key group.
%   S = landing2d.evaluation.seedSummary(R,{'Cell'},{'Success'})
% R from landing2d.evaluation.runMeans (one row per run). For every metric M
% the table holds M (mean over seeds), M_sd, M_ci (half width), M_n (seeds
% with a finite value) and M_median, M_q25, M_q75 (over the seeds, linear
% interpolation between order statistics). Episodes is the total number of
% episodes behind the run means when R has an Episodes column. With one seed
% the interval is NaN: a single run gives no between-run variation, so it
% supports no method claim.
keys = cellstr(keys); metrics = cellstr(metrics);
groupVars = [keys,{'MethodId','Method'}];
[g,S] = findgroups(R(:,groupVars));
S.Seeds = splitapply(@numel,R.TrainSeed,g);
if ismember('Episodes',R.Properties.VariableNames)
    S.Episodes = splitapply(@sum,R.Episodes,g);
end
for k = 1:numel(metrics)
    x = double(R.(metrics{k}));
    [mu,sd,half,n] = splitapply(@landing2d.evaluation.tInterval,x,g);
    [q25,med,q75] = splitapply(@quartiles,x,g);
    S.(metrics{k}) = mu; S.([metrics{k},'_sd']) = sd;
    S.([metrics{k},'_ci']) = half; S.([metrics{k},'_n']) = n;
    S.([metrics{k},'_median']) = med; S.([metrics{k},'_q25']) = q25;
    S.([metrics{k},'_q75']) = q75;
end
S = orderMethods(S);
end

function [q25,med,q75] = quartiles(x)
% Quartiles of the finite values (linear interpolation, numpy/R type 7).
x = sort(x(isfinite(x)));
q25 = NaN; med = NaN; q75 = NaN;
if isempty(x), return; end
q = @(p)interp1(1:numel(x),x,1+p*(numel(x)-1));
if isscalar(x), q25 = x; med = x; q75 = x; return; end
q25 = q(0.25); med = q(0.5); q75 = q(0.75);
end

function S = orderMethods(S)
registry = landing2d.config.methodRegistry();
[~,order] = ismember(string(S.MethodId),string({registry.methods.id}));
[~,index] = sortrows([order(:),(1:height(S))'],[1,2]);
S = S(index,:);
end
