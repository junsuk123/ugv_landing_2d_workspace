function out = summarize(episodes,d)
% SUMMARIZE Paired training-seed estimates; incomplete runs are errors.
metrics = {'Success','Unsafe','Timeout','AimErrorRMS_m','CommandRateRMS_mps3', ...
    'Duration_s','ExogenousDropout_s','ApproachViewLoss_s'};
factors = string(d.c.evaluation.generalization.conditions(:));
assert(all(ismember(episodes.Factor,factors)) && all(ismember(episodes.Shift,["ID","OOD"])));
assert(all(isfinite(episodes.Success)) && all(isfinite(episodes.Unsafe)) ...
    && all(isfinite(episodes.Timeout)) && all(isfinite(episodes.AimErrorRMS_m)), ...
    'landing2d:CurrentSemanticsMissing','Every episode must retain its terminal and tracking result.');
assert(isequal(sort(unique(episodes.MethodId)),sort(string(d.methods(:)))));
keys = {'Factor','MethodId','Method','TrainSeed'};
expectedEpisodes = sort(unique(episodes.EpisodeSeed));
expectedTraining = sort(unique(episodes.TrainSeed));
[group,groups] = findgroups(episodes(:,keys));
for k=1:height(groups)
    row = episodes(group==k,:);
    id = sort(row.EpisodeSeed(row.Shift=="ID"));
    ood = sort(row.EpisodeSeed(row.Shift=="OOD"));
    assert(isequal(id,ood) && isequal(id,expectedEpisodes), ...
        'landing2d:CurrentSemanticsPairs','ID/OOD and all methods must use the full, unique environment list.');
end
R = landing2d.evaluation.runMeans(episodes,{'Factor','Shift'},metrics);
for id = string(d.methods)
    for factor = factors'
        for shift = ["ID","OOD"]
            rows = R(R.MethodId==id & R.Factor==factor & R.Shift==shift,:);
            assert(isequal(sort(rows.TrainSeed),expectedTraining), ...
                'landing2d:CurrentSemanticsCoverage','A method, factor or training seed is missing.');
        end
    end
end
out.generalizationEpisodes = episodes;
out.generalizationBySeed = R;
out.generalizationSummary = landing2d.evaluation.seedSummary(R,{'Factor','Shift'},metrics);
pairs = [d.primaryPairs;d.secondaryPairs];
out.generalizationContrasts = landing2d.evaluation.methodContrasts(R,{'Factor','Shift'},metrics,pairs);
gap = R(R.Shift=="OOD",[keys,{'Episodes'}]);
id = R(R.Shift=="ID",:); ood = R(R.Shift=="OOD",:);
for name = metrics
    key = name{1}; a=id(:,[keys,{key}]); b=ood(:,[keys,{key}]);
    a.Properties.VariableNames{end}='Reference'; b.Properties.VariableNames{end}='OOD';
    joinedRows = join(gap(:,keys),join(a,b,'Keys',keys),'Keys',keys);
    gap.(['Reference',key])=joinedRows.Reference;
    gap.(['OOD',key])=joinedRows.OOD;
    gap.(['Change',key])=joinedRows.OOD-joinedRows.Reference;
end
gap.SuccessDrop = -gap.ChangeSuccess;
out.generalizationGapBySeed = gap;
out.generalizationGapSummary = landing2d.evaluation.seedSummary(gap,{'Factor'},{'SuccessDrop'});
[group,primary] = findgroups(gap(:,{'MethodId','Method','TrainSeed'}));
for k=1:height(primary)
    assert(isequal(sort(gap.Factor(group==k)),sort(factors)));
    assert(numel(unique(gap.Episodes(group==k)))==1);
end
primary.OODEpisodes = splitapply(@sum,gap.Episodes,group);
primary.OODSuccess = splitapply(@mean,gap.OODSuccess,group);
primary.ReferenceSuccess = splitapply(@mean,gap.ReferenceSuccess,group);
primary.SuccessDrop = splitapply(@mean,gap.SuccessDrop,group);
primary.WorstSuccess = splitapply(@min,gap.OODSuccess,group);
primary.OODUnsafe = splitapply(@mean,gap.OODUnsafe,group);
primary.OODTimeout = splitapply(@mean,gap.OODTimeout,group);
primary.OODAimErrorRMS_m = splitapply(@mean,gap.OODAimErrorRMS_m,group);
primary.OODCommandRateRMS_mps3 = splitapply(@mean,gap.OODCommandRateRMS_mps3,group);
primary.IDSuccess = zeros(height(primary),1);
primary.LegacyThreeFactorSuccess = primary.IDSuccess;
for k=1:height(primary)
    row = R(R.MethodId==primary.MethodId(k) & R.TrainSeed==primary.TrainSeed(k),:);
    nominal = row(row.Factor=="noise" & row.Shift=="ID",:);
    assert(height(nominal)==1);
    primary.IDSuccess(k)=nominal.Success;
    primary.LegacyThreeFactorSuccess(k)=mean(row.Success(row.Shift=="OOD" & row.Factor~="combined"));
end
out.primaryBySeed = primary;
primaryMetrics = {'OODSuccess','IDSuccess','OODUnsafe','OODTimeout','ReferenceSuccess', ...
    'SuccessDrop','WorstSuccess','OODAimErrorRMS_m','OODCommandRateRMS_mps3','LegacyThreeFactorSuccess'};
out.primarySummary = landing2d.evaluation.seedSummary(primary,{},primaryMetrics);
C = landing2d.evaluation.methodContrasts(primary,{},primaryMetrics,d.primaryPairs);
C.PrimaryLower = nan(height(C),1); C.PrimaryUpper=C.PrimaryLower;
for k=1:height(C)
    delta=paired(primary,C.MethodA(k),C.MethodB(k),'OODSuccess');
    [~,C.PrimaryLower(k),C.PrimaryUpper(k)]= ...
        landing2d.current_semantics.pairedInterval(delta,d.primaryCoverage);
end
C.PrimaryIndividualCoverage=repmat(d.primaryCoverage,height(C),1);
assert(height(C)==2 && all(C.Seeds==numel(expectedTraining)));
out.primaryContrasts=C;
P=landing2d.evaluation.methodContrasts(primary,{},primaryMetrics,d.secondaryPairs);
rawDelta=paired(primary,'onto_rgat_ppo','ppo','OODSuccess');
[~,P.PracticalLower,P.PracticalUpper]=landing2d.current_semantics.pairedInterval(rawDelta,d.practicalRule.coverage);
P.PracticalCoverage=d.practicalRule.coverage;
out.ppoContrasts=P;
guardRows = {};
for metric = {'IDSuccess','OODUnsafe'}
    delta=paired(primary,'onto_rgat_ppo','ppo',metric{1});
    [center,lower,upper,n]=landing2d.current_semantics.pairedInterval(delta,d.guard.coverage);
    guardRows{end+1}=struct('Metric',string(metric{1}),'Delta',center,'Lower',lower, ...
        'Upper',upper,'Seeds',n,'Coverage',d.guard.coverage); %#ok<AGROW>
end
out.guardContrasts=struct2table([guardRows{:}]);
[g,failure]=findgroups(episodes(:,{'Factor','Shift','MethodId','Method','TrainSeed','TerminalReason','FailureClass'}));
failure.Episodes=splitapply(@numel,episodes.EpisodeSeed,g);
out.failureCounts=failure;
end

function delta = paired(T,a,b,metric)
x=T(T.MethodId==string(a),:); y=T(T.MethodId==string(b),:);
x=sortrows(x,'TrainSeed'); y=sortrows(y,'TrainSeed');
assert(isequal(x.TrainSeed,y.TrainSeed));
delta=x.(metric)-y.(metric);
end
