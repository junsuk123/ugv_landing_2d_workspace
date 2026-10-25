function out = generalizationSummary(episodes)
% GENERALIZATIONSUMMARY Performance endpoints, never an "inductive bias score".
metrics = {'Success','Unsafe','AimErrorRMS_m','CommandRateRMS_mps3'};
keys = {'Factor','MethodId','Method','TrainSeed'};
% Refuse incomplete/duplicated pairings rather than silently average them.
assert(all(isfinite(episodes.Success)) && all(isfinite(episodes.Unsafe)));
assert(all(ismember(episodes.Factor,["motion","dropout","noise"])) ...
    && all(ismember(episodes.Shift,["ID","OOD"])));
[group,groups] = findgroups(episodes(:,keys));
for k = 1:height(groups)
    row = episodes(group==k,:);
    id = sort(row.EpisodeSeed(row.Shift=="ID"));
    ood = sort(row.EpisodeSeed(row.Shift=="OOD"));
    assert(~isempty(id) && isequal(id,ood) && numel(unique(id))==numel(id), ...
        'landing2d:GeneralizationPair','ID/OOD episodes must be complete unique pairs.');
end
R = landing2d.evaluation.runMeans(episodes,{'Factor','Shift'},metrics);
out.generalizationEpisodes = episodes;
out.generalizationBySeed = R;
out.generalizationSummary = landing2d.evaluation.seedSummary(R,{'Factor','Shift'},metrics);
out.generalizationContrasts = landing2d.evaluation.methodContrasts(R,{'Factor','Shift'},metrics);
gap = R(R.Shift=="OOD",[keys,{'Episodes'}]);
id = R(R.Shift=="ID",:); ood = R(R.Shift=="OOD",:);
% findgroups gives both shifts the same key order; join explicitly to avoid
% relying on that incidental table sort order.
for name = metrics
    key = name{1}; a = id(:,[keys,{key}]); b = ood(:,[keys,{key}]);
    a.Properties.VariableNames{end} = 'Reference'; b.Properties.VariableNames{end} = 'OOD';
    paired = join(gap(:,keys),join(a,b,'Keys',keys),'Keys',keys);
    gap.(['Reference',key]) = paired.Reference;
    gap.(['OOD',key]) = paired.OOD;
    gap.(['Change',key]) = paired.OOD-paired.Reference;
end
gap.SuccessDrop = -gap.ChangeSuccess; % positive means degradation
out.generalizationGapBySeed = gap;
out.generalizationGapSummary = landing2d.evaluation.seedSummary(gap,{'Factor'},{'SuccessDrop'});
[group,primary] = findgroups(gap(:,{'MethodId','Method','TrainSeed'}));
for k = 1:height(primary)
    assert(isequal(sort(gap.Factor(group==k)),sort(["motion";"dropout";"noise"])), ...
        'landing2d:GeneralizationCoverage','Every run must contain exactly three factors.');
    assert(numel(unique(gap.Episodes(group==k)))==1, ...
        'landing2d:GeneralizationCoverage','All factors must use the same episode budget.');
end
primary.OODEpisodes = splitapply(@sum,gap.Episodes,group);
primary.OODSuccess = splitapply(@mean,gap.OODSuccess,group);
primary.ReferenceSuccess = splitapply(@mean,gap.ReferenceSuccess,group);
primary.SuccessDrop = splitapply(@mean,gap.SuccessDrop,group);
primary.WorstSuccess = splitapply(@min,gap.OODSuccess,group);
primary.OODUnsafe = splitapply(@mean,gap.OODUnsafe,group);
primary.OODAimErrorRMS_m = splitapply(@mean,gap.OODAimErrorRMS_m,group);
primary.OODCommandRateRMS_mps3 = splitapply(@mean,gap.OODCommandRateRMS_mps3,group);
out.primaryBySeed = primary;
primaryMetrics = {'OODSuccess','ReferenceSuccess','SuccessDrop','WorstSuccess', ...
    'OODUnsafe','OODAimErrorRMS_m','OODCommandRateRMS_mps3'};
out.primarySummary = landing2d.evaluation.seedSummary(primary,{},primaryMetrics);
pairs = {'onto_rgat_ppo','shuffled_rgat_ppo';'onto_rgat_ppo','ppo'};
C = landing2d.evaluation.methodContrasts(primary,{},primaryMetrics,pairs);
% Two predeclared primary comparisons. Exact Student-t quantile via base
% MATLAB betaincinv: 97.5% individual intervals, >=95% Bonferroni family level.
C.PrimaryLower = nan(height(C),1); C.PrimaryUpper = C.PrimaryLower;
for k = 1:height(C)
    a = primary(primary.MethodId==C.MethodA(k),:);
    b = primary(primary.MethodId==C.MethodB(k),:);
    [~,ia,ib] = intersect(a.TrainSeed,b.TrainSeed);
    delta = a.OODSuccess(ia)-b.OODSuccess(ib); n = numel(delta);
    if n<2, continue; end
    df = n-1; q = betaincinv(0.05/size(pairs,1),df/2,0.5);
    half = sqrt(df*(1-q)/q)*std(delta)/sqrt(n);
    C.PrimaryLower(k) = mean(delta)-half; C.PrimaryUpper(k) = mean(delta)+half;
end
C.PrimaryIndividualCoverage = repmat(0.975,height(C),1);
out.primaryContrasts = C;
end
