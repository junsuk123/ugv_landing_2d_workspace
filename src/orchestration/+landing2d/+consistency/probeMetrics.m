function [summary,contexts] = probeMetrics(bank,actions,validity,c)
% PROBEMETRICS  C_valid and D_obs of one policy on a fixed-probe bank, per noise scale.
%   C_valid  100 x mean(valid_reference AND valid_perturbed) over applicable
%            probes, computed per context and averaged with equal context
%            weights (contexts with >= c.consistency.validity.minimumContextSamples
%            applicable probes); higher is better.
%   D_obs    ||u01_reference - u01_perturbed|| / sqrt(action_dim) with
%            u01 = (a - a_min)/(a_max - a_min) of the requested command, over
%            probes whose observation confidence and safety decision context
%            equal the reference (bank.context.sameContext); mean and P95; lower
%            is better. A constant command has D_obs = 0, so D_obs is reported
%            only next to C_valid.
% The reference is the noise-free observation of the same state and history
% (bank.meta.referenceScale). Also reported: reference validity rate, applicable
% and excluded probes, contexts used, same-context probe count.
% SUMMARY has one row per scale; CONTEXTS one row per context x scale.
scales = bank.meta.scales(:)';
ref = find(scales == bank.meta.referenceScale,1);
limits = bank.meta.actionLimits(:);
u = (actions.requestedAcceleration+limits)./(2*limits);
A = numel(limits);
minSamples = c.consistency.validity.minimumContextSamples;
applicable = validity.applicable(:);
[names,~,group] = unique(validity.contextId(:));
nS = numel(scales); P = numel(applicable);
rows = cell(nS,1); contextRows = {};
for s = 1:nS
    both = validity.valid(:,ref) & validity.valid(:,s);
    perContext = NaN(numel(names),1); refContext = NaN(numel(names),1);
    counts = zeros(numel(names),1);
    for g = 1:numel(names)
        in = applicable & group == g;
        counts(g) = sum(in);
        if counts(g) > 0
            perContext(g) = 100*mean(both(in));
            refContext(g) = 100*mean(validity.valid(in,ref));
        end
        contextRows(end+1,:) = {scales(s),names{g},counts(g),perContext(g), ...
            refContext(g),counts(g) >= minSamples}; %#ok<AGROW>
    end
    used = counts >= minSamples;
    distance = reshape(vecnorm(u(:,:,ref)-u(:,:,s),2,1),[],1)/sqrt(A);
    same = bank.context.sameContext(:,s);
    rows{s} = {scales(s),mean(perContext(used)),mean(refContext(used)), ...
        100*mean(validity.valid(applicable,ref)),100*mean(both(applicable)), ...
        sum(applicable),100*(1-mean(applicable)),sum(used),numel(names), ...
        mean(distance(same)),prctile(distance(same),95),sum(same),P};
end
summary = cell2table(vertcat(rows{:}),'VariableNames',{'NoiseScale','C_valid', ...
    'ReferenceValidContext','ReferenceValidRaw','JointValidRaw','ApplicableProbes', ...
    'ExcludedPct','ContextsUsed','ContextsSeen','D_obs_mean','D_obs_P95', ...
    'SameContextProbes','Probes'});
contexts = cell2table(contextRows,'VariableNames',{'NoiseScale','Context', ...
    'ApplicableProbes','C_valid','ReferenceValid','UsedInAverage'});
end
