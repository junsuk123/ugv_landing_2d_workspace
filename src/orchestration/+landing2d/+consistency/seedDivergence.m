function out = seedDivergence(actionSets,bank)
% SEEDDIVERGENCE  D_seed: command difference between independently trained seeds.
% ACTIONSETS is a cell array of landing2d.rl.probeActions results of one method
% (one graph seed for the relation-perturbed method), each from a different
% training seed, on the same probe bank. For every noise scale:
%   D_seed  mean over seed pairs of the mean over probes of
%           ||u01_i - u01_j|| / sqrt(action_dim); NaN with fewer than 2 seeds.
% Seed pairs share seeds, so the leave-one-seed-out jackknife (>= 3 seeds) gives
% the standard error instead of treating pairs as independent samples.
scales = bank.meta.scales(:)';
n = numel(actionSets);
limits = bank.meta.actionLimits(:);
A = numel(limits);
out = struct('scales',scales,'seedCount',n,'D_seed',NaN(1,numel(scales)), ...
    'jackknifeSE',NaN(1,numel(scales)),'pairwise',NaN(n,n,numel(scales)));
if n < 2, return; end
u = cellfun(@(a)(a.requestedAcceleration+limits)./(2*limits),actionSets, ...
    'UniformOutput',false);
for s = 1:numel(scales)
    D = NaN(n);
    for i = 1:n
        for j = i+1:n
            D(i,j) = mean(vecnorm(u{i}(:,:,s)-u{j}(:,:,s),2,1))/sqrt(A);
            D(j,i) = D(i,j);
        end
    end
    out.pairwise(:,:,s) = D;
    upper = triu(true(n),1);
    out.D_seed(s) = mean(D(upper));
    if n >= 3
        leave = NaN(1,n);
        for i = 1:n
            keep = setdiff(1:n,i);
            sub = D(keep,keep);
            leave(i) = mean(sub(triu(true(n-1),1)));
        end
        out.jackknifeSE(s) = sqrt((n-1)/n*sum((leave-mean(leave)).^2));
    end
end
end
