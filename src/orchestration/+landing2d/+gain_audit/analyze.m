function A = analyze(E,d)
% ANALYZE Paired k = 2 - k = 1 differences, seed-block intervals and the registered criteria.
% Episode pairs share the model, cell and environment seed. Per model the mean
% over environments of dS = 100 (S2 - S1) [%p], dU = 100 (U2 - U1) [%p] and
% dE = E2 - E1 [m] (E = AimErrorRMS_m); per training seed the equal-weight mean
% of the four methods (seed block, the independent unit); two-sided 95% t
% intervals over the five blocks (df = 4). Descriptive and exploratory.
% Criteria G / C / B and the verdict follow config.m; checks lists every component.
keyNames = {'MethodId','TrainSeed','Factor','Shift','EpisodeSeed'};
E.MethodId = string(E.MethodId); E.Factor = string(E.Factor); E.Shift = string(E.Shift);
one = E(E.Gain==1,:); two = E(E.Gain==2,:);
fields = {'Success','Unsafe','AimErrorRMS_m','Duration_s','AccelerationExposure_s', ...
    'ClippedFraction','SaturatedFraction','MeanAbsRequestedAx_mps2','CommandRateRMS_mps3'};
one = renamevars(one(:,[keyNames,fields]),fields,strcat(fields,'_k1'));
two = renamevars(two(:,[keyNames,fields]),fields,strcat(fields,'_k2'));
P = innerjoin(one,two,'Keys',keyNames);
assert(height(P)==height(one) && height(P)==height(two),'landing2d:GainAuditPairs', ...
    'Every k = 1 episode needs its k = 2 pair.');
P.dS = 100*(P.Success_k2-P.Success_k1);
P.dU = 100*(P.Unsafe_k2-P.Unsafe_k1);
P.dE = P.AimErrorRMS_m_k2-P.AimErrorRMS_m_k1;
assert(all(isfinite([P.dS;P.dU;P.dE])),'landing2d:GainAuditFinite','Non-finite paired difference.');

% Model level: mean over the environments of each cell.
modelKeys = {'MethodId','TrainSeed','Factor','Shift'};
means = setdiff(P.Properties.VariableNames,keyNames,'stable');
byModel = groupsummary(P,modelKeys,'mean',means);
byModel = renamevars(byModel,strcat('mean_',means),means);
byModel = renamevars(byModel,'GroupCount','Environments');
for v = {'Success_k1','Success_k2','Unsafe_k1','Unsafe_k2'}
    byModel.(v{1}) = 100*byModel.(v{1});        % rates in %
end

% Seed blocks: equal-weight mean of the four methods per training seed and cell.
metrics = {'dS','dU','dE'};
bySeed = groupsummary(byModel,{'TrainSeed','Factor','Shift'},'mean',metrics);
assert(all(bySeed.GroupCount==numel(d.methods)),'landing2d:GainAuditPairs', ...
    'Each seed block needs all four methods.');
bySeed = renamevars(removevars(bySeed,'GroupCount'),strcat('mean_',metrics),metrics);

cells = interval(bySeed,{'Factor','Shift'},metrics);
byMethod = interval(byModel,{'MethodId','Factor','Shift'},metrics);
levels = groupsummary(byModel,{'Factor','Shift'},'mean',{'Success_k1','Success_k2', ...
    'Unsafe_k1','Unsafe_k2','AimErrorRMS_m_k1','AimErrorRMS_m_k2','Duration_s_k1', ...
    'Duration_s_k2','AccelerationExposure_s_k1','AccelerationExposure_s_k2', ...
    'ClippedFraction_k2','SaturatedFraction_k1','SaturatedFraction_k2', ...
    'MeanAbsRequestedAx_mps2_k1','MeanAbsRequestedAx_mps2_k2','CommandRateRMS_mps3_k1', ...
    'CommandRateRMS_mps3_k2'});
levels = removevars(levels,'GroupCount');
levels.Properties.VariableNames = erase(levels.Properties.VariableNames,'mean_');

% Difference of differences (OOD - ID) per factor and seed block.
did = table();
for f = ["motion","dropout","noise"]
    o = sortrows(bySeed(bySeed.Factor==f & bySeed.Shift=="OOD",:),'TrainSeed');
    i = sortrows(bySeed(bySeed.Factor==f & bySeed.Shift=="ID",:),'TrainSeed');
    assert(isequal(o.TrainSeed,i.TrainSeed));
    did = [did;table(repmat(f,height(o),1),o.TrainSeed,o.dS-i.dS,o.dU-i.dU,o.dE-i.dE, ...
        'VariableNames',{'Factor','TrainSeed','dS','dU','dE'})]; %#ok<AGROW>
end
didSummary = interval(did,{'Factor'},metrics);

[checks,verdict,flags] = criteria(cells,byMethod,didSummary,d.criteria);
failures = groupsummary(E,{'Factor','Shift','Gain','FailureClass'});
failures = renamevars(failures,'GroupCount','Episodes');
A = struct('pairs',P,'byModel',byModel,'bySeed',bySeed,'cells',cells,'byMethod',byMethod, ...
    'levels',levels,'didBySeed',did,'did',didSummary,'failures',failures, ...
    'checks',checks,'verdict',verdict,'flags',flags);
end

function S = interval(T,groups,metrics)
% Mean, two-sided 95% t interval and positive count over the rows of each group.
[g,S] = findgroups(T(:,groups));
for m = metrics
    x = T.(m{1});
    S.([m{1},'_mean']) = splitapply(@mean,x,g);
    S.([m{1},'_n']) = splitapply(@numel,x,g);
    hw = splitapply(@(v)halfWidth(std(v),numel(v)),x,g);
    S.([m{1},'_low']) = S.([m{1},'_mean'])-hw;
    S.([m{1},'_high']) = S.([m{1},'_mean'])+hw;
    S.([m{1},'_positive']) = splitapply(@(v)sum(v>0),x,g);
end
end

function hw = halfWidth(sd,n)
q = betaincinv(0.05,(n-1)/2,0.5);                    % two-sided 95% t quantile
hw = sqrt((n-1)*(1-q)/q)*sd/sqrt(n);
end

function [checks,verdict,flags] = criteria(cells,byMethod,did,k)
rows = {};
    function out = stat(fac,sh,met,part)
        out = cells.([met,'_',part])(cells.Factor==fac & cells.Shift==sh);
        assert(isscalar(out));
    end
    function out = methodMeans(fac,sh,met)
        out = byMethod.([met,'_mean'])(byMethod.Factor==fac & byMethod.Shift==sh);
        assert(numel(out)==4);
    end
    function out = didStat(fac,met,part)
        out = did.([met,'_',part])(did.Factor==fac);
        assert(isscalar(out));
    end
    function ok = addCheck(criterion,component,value,rule,ok)
        rows{end+1} = table(string(criterion),string(component),value,string(rule),ok, ...
            'VariableNames',{'Criterion','Component','Value','Rule','Pass'});
    end
% G: gain improves the unknown-acceleration cell.
g = [addCheck('G','motion OOD dS mean [%p]',stat("motion","OOD",'dS','mean'),sprintf('>= %g',k.gainS),stat("motion","OOD",'dS','mean')>=k.gainS), ...
     addCheck('G','motion OOD dS low [%p]',stat("motion","OOD",'dS','low'),'> 0',stat("motion","OOD",'dS','low')>0), ...
     addCheck('G','motion OOD dE mean [m]',stat("motion","OOD",'dE','mean'),sprintf('<= %g',k.gainE),stat("motion","OOD",'dE','mean')<=k.gainE), ...
     addCheck('G','motion OOD dE high [m]',stat("motion","OOD",'dE','high'),'< 0',stat("motion","OOD",'dE','high')<0), ...
     addCheck('G','motion OOD dU high [%p]',stat("motion","OOD",'dU','high'),sprintf('<= %g',k.unsafeLimit),stat("motion","OOD",'dU','high')<=k.unsafeLimit), ...
     addCheck('G','motion OOD min method dS mean [%p]',min(methodMeans("motion","OOD",'dS')),'> 0 (every method)',all(methodMeans("motion","OOD",'dS')>0)), ...
     addCheck('G','motion OOD max method dE mean [m]',max(methodMeans("motion","OOD",'dE')),'< 0 (every method)',all(methodMeans("motion","OOD",'dE')<0))];
G = all(g);
% C: trade-off with dropout or noise robustness.
harm = false;
for f = ["dropout","noise"]
    s = [addCheck('C',f+" OOD dS mean [%p]",stat(f,"OOD",'dS','mean'),sprintf('<= -%g',k.harmS),stat(f,"OOD",'dS','mean')<=-k.harmS), ...
         addCheck('C',f+" OOD dS high [%p]",stat(f,"OOD",'dS','high'),'< 0',stat(f,"OOD",'dS','high')<0), ...
         addCheck('C',f+" dS OOD-ID mean [%p]",didStat(f,'dS','mean'),sprintf('<= -%g',k.didS),didStat(f,'dS','mean')<=-k.didS), ...
         addCheck('C',f+" dS OOD-ID high [%p]",didStat(f,'dS','high'),'< 0',didStat(f,'dS','high')<0), ...
         addCheck('C',f+" OOD max method dS mean [%p]",max(methodMeans(f,"OOD",'dS')),'< 0 (every method)',all(methodMeans(f,"OOD",'dS')<0))];
    u = [addCheck('C',f+" OOD dU mean [%p]",stat(f,"OOD",'dU','mean'),sprintf('>= %g',k.harmU),stat(f,"OOD",'dU','mean')>=k.harmU), ...
         addCheck('C',f+" OOD dU low [%p]",stat(f,"OOD",'dU','low'),'> 0',stat(f,"OOD",'dU','low')>0), ...
         addCheck('C',f+" dU OOD-ID mean [%p]",didStat(f,'dU','mean'),sprintf('>= %g',k.didU),didStat(f,'dU','mean')>=k.didU), ...
         addCheck('C',f+" dU OOD-ID low [%p]",didStat(f,'dU','low'),'> 0',didStat(f,'dU','low')>0), ...
         addCheck('C',f+" OOD min method dU mean [%p]",min(methodMeans(f,"OOD",'dU')),'> 0 (every method)',all(methodMeans(f,"OOD",'dU')>0))];
    harm = harm || all(s) || all(u);
end
C = G && harm;
% B: global low gain (motion ID also improves, no cell is harmed).
b = [addCheck('B','motion ID dE mean [m]',stat("motion","ID",'dE','mean'),sprintf('<= %g',k.gainE),stat("motion","ID",'dE','mean')<=k.gainE), ...
     addCheck('B','motion ID dE high [m]',stat("motion","ID",'dE','high'),'< 0',stat("motion","ID",'dE','high')<0), ...
     addCheck('B','motion ID max method dE mean [m]',max(methodMeans("motion","ID",'dE')),'< 0 (every method)',all(methodMeans("motion","ID",'dE')<0))];
for i = 1:height(cells)
    f = cells.Factor(i); s = cells.Shift(i);
    b(end+1) = addCheck('B',f+" "+s+" dS low [%p]",cells.dS_low(i),sprintf('>= -%g',k.tolS),cells.dS_low(i)>=-k.tolS); %#ok<AGROW>
    b(end+1) = addCheck('B',f+" "+s+" dU high [%p]",cells.dU_high(i),sprintf('<= %g',k.unsafeLimit),cells.dU_high(i)<=k.unsafeLimit); %#ok<AGROW>
end
B = G && all(b);
assert(~(B && C),'landing2d:GainAuditCriteria','B and C are exclusive by construction.');
mS = [stat("motion","OOD",'dS','low'),stat("motion","OOD",'dS','high')];
mE = [stat("motion","OOD",'dE','low'),stat("motion","OOD",'dE','high')];
if C, verdict = "trade_off_supported";
elseif B, verdict = "global_low_gain_supported";
elseif G, verdict = "acceleration_gain_bottleneck_only";
elseif mS(2)<0 || mE(1)>0, verdict = "worse";
elseif mS(1)>0 || mE(2)<0, verdict = "mixed";
else, verdict = "null_or_uncertain";
end
checks = vertcat(rows{:});
flags = struct('G',G,'C',C,'B',B);
end
