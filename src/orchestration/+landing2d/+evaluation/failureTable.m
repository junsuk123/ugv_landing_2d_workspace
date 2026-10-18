function [R,S] = failureTable(T,keys)
% FAILURETABLE  Outcome-class distribution per run and over training seeds.
%   [R,S] = landing2d.evaluation.failureTable(episodes,{'Cell'})
% T has one row per episode with FailureClass (landing2d.evaluation.episodeMetrics).
% R: one row per run (MethodId, TrainSeed), key group and class of
% landing2d.evaluation.failureClasses with Count, Episodes and Fraction.
% S: Fraction and Count over training seeds (landing2d.evaluation.seedSummary),
% so the failure mix of a method is read per run, like every other metric.
classes = landing2d.evaluation.failureClasses();
keys = cellstr(keys);
assert(all(ismember(T.FailureClass,classes)),'landing2d:FailureClass', ...
    'Unknown failure class in the episode table.');
[g,G] = findgroups(T(:,[keys,{'MethodId','Method','TrainSeed'}]));
nc = numel(classes);
rows = cell(height(G),1);
for i = 1:height(G)
    labels = T.FailureClass(g==i);
    count = arrayfun(@(k)sum(labels==classes(k)),1:nc)';
    block = repmat(G(i,:),nc,1);
    block.Class = classes(:); block.Count = count;
    block.Episodes = repmat(numel(labels),nc,1); block.Fraction = count/numel(labels);
    rows{i} = block;
end
R = vertcat(rows{:});
S = landing2d.evaluation.seedSummary(R,[keys,{'Class'}],{'Fraction','Count'});
end
